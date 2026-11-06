# Arquitectura Técnica y Decisiones de Diseño (ADR) — SF Vibe Lab

> **Propósito:** Documentar la arquitectura del sistema, el modelo de datos, el flujo de integración con Stripe y el cumplimiento estricto de los mínimos **M1**, **M2** y **M3**.

## 1. Diagrama de Flujo de Integración (Patrón de Dos Transacciones + Webhook)

```mermaid
sequenceDiagram
    autonumber
    actor Donante as Visitante Público (Guest User)
    participant LWC as LWC Portal Donaciones
    participant Apex as DonationController (with/without sharing DTOs)
    participant DB as Salesforce DB (Donacion__c / Campana__c)
    participant Stripe as Stripe API (Test Mode)
    participant WH as StripeWebhookService (@RestResource)

    Donante->>LWC: Completa formulario (Modalidad, Monto, Correo, [Nombre/RFC])
    LWC->>Apex: Transacción 1: crearDonacionPendiente(requestDTO)
    Apex->>Apex: Valida elegibilidad de Campana__c, monto > 0 y Regex RFC (si aplica)
    Apex->>DB: INSERT Donacion__c (Estado__c = 'Pendiente')
    DB-->>Apex: Retorna Record Id
    Apex-->>LWC: Retorna donacionId (Id)

    LWC->>Apex: Transacción 2: crearSesionStripe(donacionId)
    Apex->>DB: Lee Stripe_Config__c.getOrgDefaults() (Protected Custom Setting)
    Apex->>Stripe: POST /v1/checkout/sessions (client_reference_id, metadata[donacion_id])
    Stripe-->>Apex: Retorna session.id (cs_test_...) y session.url
    Apex->>DB: UPDATE Donacion__c (Stripe_Session_Id__c = session.id)
    Apex-->>LWC: Retorna Checkout URL
    LWC->>Donante: Redirige (window.location.href) a Stripe Checkout

    Donante->>Stripe: Completa pago con tarjeta de prueba
    Stripe->>WH: POST /services/apexrest/stripe/webhook (Header: Stripe-Signature)
    WH->>WH: Verifica HMAC-SHA256 (Crypto.generateMac) e Idempotencia (Stripe_Event_Id__c)
    alt Firma Inválida
        WH->>DB: INSERT Aviso_Pasarela__c (Estado = 'Rechazado')
        WH-->>Stripe: HTTP 400 Bad Request
    else Evento Duplicado
        WH->>DB: INSERT Aviso_Pasarela__c (Estado = 'Duplicado Ignorado')
        WH-->>Stripe: HTTP 200 OK
    else Evento Válido y Nuevo
        WH->>DB: UPDATE Donacion__c (Estado__c = 'Pagada', Tipo_Confirmacion__c = 'Automática')
        WH->>DB: INSERT Aviso_Pasarela__c (Estado = 'Procesado')
        DB->>Donante: Flow / Servicio de Correo envía comprobante adaptado por Modalidad__c
        WH-->>Stripe: HTTP 200 OK
    end
```

## 2. Decisiones Arquitectónicas Clave (ADRs)

### ADR-01: Stripe Checkout Sessions (Server-Side) en lugar de Stripe Elements
- **Contexto:** Lightning Web Security (LWS) y Content Security Policy (CSP) en Experience Cloud restringen iframes de terceros. Además, el mínimo **M3** prohíbe llaves en código o repositorio.
- **Decisión:** Utilizar `POST https://api.stripe.com/v1/checkout/sessions` desde Apex mediante el patrón de dos transacciones (`crearDonacionPendiente` seguido de `crearSesionStripe`).
- **Consecuencia:** Cero exposición de llaves en el cliente, cumplimiento total de M3 y prevención del error `System.CalloutException: You have uncommitted work pending`.

### ADR-02: Aislamiento de Seguridad para Guest User (Mínimo M2)
- **Contexto:** Los visitantes públicos no autenticados necesitan ver el progreso de las campañas y el muro de reconocimiento de donantes sin tener acceso directo de lectura al objeto `Donacion__c`.
- **Decisión:** El perfil Guest User no tiene permisos CRUD sobre `Donacion__c`. El controlador Apex expone únicamente clases Wrapper/DTO (`@AuraEnabled`) con los campos estrictamente públicos (`Nombre_Donante__c` y `Monto__c` solo cuando `Estado__c == 'Pagada'` y `Modalidad__c != 'Anónima'`).
- **Consecuencia:** Imposibilidad de extraer correos electrónicos, RFCs o registros de otros donantes desde la consola del navegador o APIs estándar.

### ADR-03: Almacenamiento Protegido de Secretos (Mínimo M3)
- **Contexto:** El repositorio de GitHub es público y cualquier llave en código o historial de Git causa pérdida directa de puntos.
- **Decisión:** Crear `Stripe_Config__c` como **Hierarchy Custom Setting** con visibilidad `Protected`. Los valores se cargan manualmente en Setup UI de la Org y se leen vía `Stripe_Config__c.getOrgDefaults()`.
