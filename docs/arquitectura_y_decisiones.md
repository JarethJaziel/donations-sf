# Arquitectura Técnica y Decisiones de Diseño (ADR) — SF Vibe Lab

> **Propósito:** Documentar la arquitectura del sistema, el modelo de datos, el flujo de integración con Stripe y el cumplimiento estricto de los mínimos **M1**, **M2** y **M3**.
> **Versión 2 (2026-11-08):** el flujo de pago cambió a una sola transacción con referencia opaca (ADR-01 y ADR-04), y el webhook ahora revisa tipo de evento, monto y antigüedad de la firma. Detalle de campos y reglas en [`CLAUDE.md`](../CLAUDE.md), sección 4.

## 1. Diagrama de Flujo de Integración (Una Transacción + Webhook)

```mermaid
sequenceDiagram
    autonumber
    actor Donante as Visitante Público (Guest User)
    participant LWC as LWC Portal Donaciones
    participant Apex as DonationPublicController (DTOs)
    participant DB as Salesforce DB (Donacion__c / Campana__c)
    participant Stripe as Stripe API (Test Mode)
    participant WH as StripeWebhookService (@RestResource)

    Donante->>LWC: Completa formulario (Modalidad, Monto, Correo, [Nombre, Nombre público, RFC])
    LWC->>LWC: Valida mínimo $10, 2 decimales, RFC; confirma si el monto es de $1,000 o más
    LWC->>Apex: iniciarDonacion(SolicitudDonacionDTO)
    Apex->>Apex: Valida campaña vigente y elegible, monto, correo, modalidad y RFC (RfcValidator)
    Apex->>Apex: Genera referencia = UUID
    Apex->>DB: Lee Stripe_Config__c.getOrgDefaults() (Protected Custom Setting)
    Apex->>Stripe: POST /v1/checkout/sessions (client_reference_id = referencia, metadata[referencia], expires_at = +1 h)
    alt Stripe responde con error
        Stripe-->>Apex: Error
        Apex-->>LWC: AuraHandledException (mensaje genérico); no se inserta nada
    else Sesión creada
        Stripe-->>Apex: session.id (cs_test_...) y session.url
        Apex->>DB: INSERT Donacion__c (Pendiente, Referencia_Publica__c, Stripe_Session_Id__c)
        Apex-->>LWC: Solo la URL de Checkout
        LWC->>Donante: Redirige (window.location.href) a Stripe Checkout
    end

    alt Donante paga
        Donante->>Stripe: Paga con tarjeta de prueba
        Stripe->>Donante: Redirige a /agradecimiento
        Stripe->>WH: checkout.session.completed (Header: Stripe-Signature)
    else Donante cancela
        Stripe->>Donante: Redirige a /pago-cancelado (no hubo cargo)
    else Nadie paga en 1 hora
        Stripe->>WH: checkout.session.expired
    end

    WH->>WH: Verifica HMAC-SHA256 y que la firma tenga menos de 5 minutos
    alt Firma inválida, ausente o antigua
        WH->>DB: INSERT Aviso_Pasarela__c (Rechazado)
        WH-->>Stripe: HTTP 400
    else Evento ya Procesado o Ignorado
        WH->>DB: INSERT Aviso_Pasarela__c (Duplicado Ignorado)
        WH-->>Stripe: HTTP 200
    else Pago con monto y moneda correctos
        WH->>DB: UPDATE Donacion__c (Pagada, Automática, Fecha_Pago__c) buscada por Referencia_Publica__c
        DB->>Donante: DonationReceiptService envía comprobante según Modalidad__c
        WH->>DB: INSERT Aviso_Pasarela__c (Procesado)
        WH-->>Stripe: HTTP 200
    else Monto o moneda distintos
        WH->>DB: INSERT Aviso_Pasarela__c (Rechazado); la donación sigue Pendiente
        WH-->>Stripe: HTTP 200
    else Sesión expirada
        WH->>DB: UPDATE Donacion__c (Expirada) + Aviso Procesado
        WH-->>Stripe: HTTP 200
    else Error inesperado
        WH->>DB: Rollback + INSERT Aviso_Pasarela__c (Error)
        WH-->>Stripe: HTTP 500 (Stripe reintenta)
    end
```

## 2. Decisiones Arquitectónicas Clave (ADRs)

### ADR-01: Stripe Checkout Sessions (Server-Side) en una sola transacción
- **Contexto:** Lightning Web Security (LWS) y Content Security Policy (CSP) en Experience Cloud restringen iframes de terceros, y el mínimo **M3** prohíbe llaves en código o repositorio. Además, Apex no permite hacer un callout después de un DML en la misma transacción (`You have uncommitted work pending`).
- **Decisión:** Usar `POST https://api.stripe.com/v1/checkout/sessions` desde Apex en **una sola transacción: primero el callout y después el DML** (`iniciarDonacion`). Si Stripe falla, no se inserta nada; si responde bien, se inserta la donación `Pendiente` antes de regresar la URL, con lo que se cumple `RF-D3` CA1.
- **Decisión anterior (reemplazada):** patrón de dos transacciones `crearDonacionPendiente` + `crearSesionStripe(Id)`. Se descartó porque el segundo método, llamable por el invitado, aceptaba cualquier Id de donación (riesgo **M2** detectado en la auditoría).
- **Consecuencia:** cero llaves en el cliente, ningún método público recibe Ids, y una sesión de Stripe huérfana (si fallara el insert) simplemente expira sin cobrar.

### ADR-02: Aislamiento de Seguridad para Guest User (Mínimo M2)
- **Contexto:** Los visitantes públicos no autenticados necesitan ver el progreso de las campañas y el muro de reconocimiento sin acceso directo a `Donacion__c`.
- **Decisión:** El perfil Guest User no tiene permisos sobre `Donacion__c` ni `Aviso_Pasarela__c`; solo accede a la clase `DonationPublicController`, que expone DTOs. El muro devuelve únicamente **nombre público** (o el nombre si no hay nombre público) y **monto**, de donaciones `Pagada`, con crédito o con factura y visibles (`Visible_En_Reconocimiento__c`). Nunca correo, RFC, nombre legal, fecha ni Id.
- **Consecuencia:** Imposibilidad de extraer correos, RFCs o registros de otros donantes desde la consola del navegador o APIs estándar.

### ADR-03: Almacenamiento Protegido de Secretos (Mínimo M3)
- **Contexto:** El repositorio de GitHub es público y cualquier llave en código o historial de Git causa pérdida directa de puntos.
- **Decisión:** Crear `Stripe_Config__c` como **Hierarchy Custom Setting** con visibilidad `Protected`. Los valores se cargan manualmente en la org y se leen vía `Stripe_Config__c.getOrgDefaults()`.

### ADR-04: Referencia pública opaca en lugar del Id del registro
- **Contexto:** El Id de Salesforce identifica directamente el registro; si llega al navegador o a Stripe, puede usarse para intentar leer o modificar otra donación.
- **Decisión:** Cada donación tiene `Referencia_Publica__c` (UUID, único e inmutable, generado por el trigger si no viene). Es lo único que se envía a Stripe (`client_reference_id`, `metadata[referencia]`) y lo que usa el webhook para encontrar la donación.
- **Consecuencia:** Cumple `US-06` AC5 y `US-15` AC5.

### ADR-05: Comprobante propio de Salesforce para todas las modalidades
- **Contexto:** El cliente dijo que basta el correo de la pasarela, pero Stripe no envía recibos en modo de prueba y la confirmación manual no genera correo de Stripe (`RF-D5`, `RF-S3`).
- **Decisión:** `DonationReceiptService` envía el comprobante al pasar a `Pagada`, una sola vez. Solo marca `Comprobante_Enviado__c` si el envío fue exitoso; si falla, registra el motivo en `Error_Comprobante__c` sin revertir el pago. Pendiente de confirmar con el cliente (P4).

### ADR-06: El registro Pendiente es una intención de pago
- **Contexto:** `RF-D3` CA1 exige un registro Pendiente antes de abrir la pasarela, pero el cliente pidió crear el registro solo después de un pago exitoso.
- **Decisión:** Se conserva el registro Pendiente porque es un criterio mínimo de la guía, pero nunca cuenta en el avance, nunca aparece en público y nunca envía comprobante. Expira a la hora con el evento `checkout.session.expired`. Pendiente de confirmar con el cliente (P1).
