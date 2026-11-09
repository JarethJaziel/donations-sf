# Arquitectura y Verificación de Seguridad: Usuario Invitado y Pasarela (US-15, M2, M3)

Este documento describe la arquitectura de seguridad, la clasificación de datos y los procedimientos reproducibles de verificación para garantizar el cumplimiento de los mínimos críticos **M2** (menor privilegio para el usuario invitado en Experience Cloud) y **M3** (resguardo estricto de secretos y llaves de pasarela).

---

## 1. Pasos Reproducibles de Verificación del Usuario Invitado (US-15)

Cualquier evaluador externo o auditor de seguridad puede reproducir estas pruebas sin autenticación en Salesforce:

### Prueba 1.1: Navegación Pública en Ventana de Incógnito
1. Abrir una ventana de incógnito en el navegador (sin sesión activa de Salesforce).
2. Navegar a la URL pública del portal: `https://<dominio-sandbox>.sandbox.my.site.com/md2026/`.
3. **Resultado esperado:**
   - La página carga sin solicitar inicio de sesión (`US-14`).
   - Se visualizan las campañas activas y vigentes.
   - En el Muro de Reconocimiento se muestran únicamente el nombre público (o nombre) y el monto de donaciones pagadas. No aparece ninguna fecha, correo ni RFC.

### Prueba 1.2: Inspección de Respuestas de Red en DevTools
1. Abrir las herramientas de desarrollador del navegador (F12) e ir a la pestaña **Network (Red)**.
2. Filtrar por `DonationPublicController` o `obtenerMuroDonantes`.
3. Recargar la página o seleccionar una campaña para cargar el muro.
4. Inspeccionar el payload JSON de la respuesta devuelta por Apex.
5. **Resultado esperado:**
   - El arreglo de objetos contiene únicamente las propiedades `nombrePublico` y `monto`.
   - No contiene campos como `Id`, `Correo__c`, `RFC__c`, `Nombre_Donante__c`, `CreatedDate` ni `Fecha_Pago__c`.

### Prueba 1.3: Intento de Acceso Directo por REST API Estándar sin Sesión
1. Ejecutar una solicitud `curl` contra el endpoint REST estándar de Salesforce para el objeto `Donacion__c`:
   ```bash
   curl -i -X GET "https://<dominio-sandbox>.sandbox.my.site.com/services/data/v60.0/sobjects/Donacion__c"
   ```
2. **Resultado esperado:**
   - Código de respuesta **`401 Unauthorized`** o **`404 Not Found`**.
   - El usuario invitado carece de token OAuth y el objeto no está expuesto a la API pública estándar.

### Prueba 1.4: Intento de Manipulación de Parámetros en Métodos Públicos (Aura/Apex)
1. Intentar llamar al método `obtenerMuroDonantes` pasando como argumento el ID de una donación o un ID arbitrario de otro objeto:
   - El método valida en servidor `campanaId.getSobjectType() == Campana__c.SObjectType`.
   - Si se envía un ID de `Donacion__c`, devuelve una lista vacía de inmediato (`US-15 AC5`).
2. Intentar llamar a `iniciarDonacion`:
   - Ningún parámetro acepta el ID de un registro de donación. El servidor genera un UUID nuevo e inmutable en cada solicitud (`Referencia_Publica__c`).

---

## 2. Matriz de Permisos del Perfil del Usuario Invitado (`Portal Donaciones MD2026 Perfil`)

| Recurso / Objeto | Permiso Concedido | Justificación de Seguridad (M2) |
|---|---|---|
| `Donacion__c` | **Ninguno** (Read=false, Create=false, Edit=false, Delete=false) | Impide que cualquier atacante consulte o modifique donaciones ajenas a través de APIs de Salesforce. |
| `Campana__c` | **Ninguno** (Read=false, Create=false, Edit=false, Delete=false) | Las campañas se exponen únicamente mediante DTOs filtrados en `obtenerCampanasActivas()`. |
| `Aviso_Pasarela__c` | **Ninguno** (Read=false, Create=false, Edit=false, Delete=false) | La auditoría del webhook es interna; un visitante público no debe ver avisos ni reintentos. |
| Apex: `DonationPublicController` | **Habilitado** | Expone los 3 métodos públicos seguros que operan exclusivamente con DTOs. |
| Apex: `StripeWebhookService` | **Habilitado** | Permite recibir los webhooks firmados de Stripe en el endpoint público del sitio. |
| Resto de clases Apex | **Deshabilitadas** | Menor privilegio absoluto; controladores administrativos y de utilidades inaccesibles para el invitado. |

> **Implementación técnica de acceso:** Debido a que el perfil invitado tiene cero permisos sobre el esquema de datos, los controladores públicos utilizan internamente `WITH SYSTEM_MODE` e `insert as system` / `update as system`. Toda la lógica de autorización y filtrado se ejecuta de forma centralizada en el código Apex.

---

## 3. Resguardo de Secretos y Llaves de Pasarela (M3)

- **Ubicación:** Las credenciales de Stripe (`Secret_Key__c` y `Webhook_Secret__c`) se almacenan de manera exclusiva dentro del Custom Setting de tipo Jerarquía Protegida **`Stripe_Config__c`** en la Org de Salesforce.
- **Cero secretos en código o control de versiones:** Ningún archivo del repositorio Git (`.cls`, `.js`, `.xml`, `.json`, `.md`) contiene prefijos de llaves reales ni de prueba (`sk_test_...`, `whsec_...`).
- **Lectura en servidor:** Las llaves son leídas únicamente en transacciones Apex del lado del servidor mediante `Stripe_Config__c.getOrgDefaults()`.

### Protocolo de Respuesta ante Filtración Accidental de Llaves
1. **Invalidación Inmediata en Stripe:**
   - Acceder de inmediato al Dashboard de Stripe (Developers → API Keys / Webhooks) y revocar la clave comprometida.
2. **Generación de Nueva Clave:**
   - Generar un nuevo Secret Key o Signing Secret en Stripe.
3. **Actualización en Salesforce:**
   - Ir a **Setup → Custom Settings → Stripe Config → Manage** y actualizar el campo correspondiente con el nuevo valor.
4. **Auditoría del Historial:**
   - Revisar con `git log -S` y herramientas de escaneo que la clave no haya sido confirmada en ramas locales ni remotas.

---

## 4. Clasificación y Tratamiento de Datos Personales

| Dato | Clasificación | Almacenamiento | Exposición Pública |
|---|---|---|---|
| **Número de tarjeta, CVC, fecha exp.** | Crítico / PCI-DSS | **Solo en Stripe** (Salesforce jamás recibe ni almacena datos de tarjeta) | Ninguna |
| **Correo electrónico (`Correo__c`)** | Personal Confidencial | `Donacion__c.Correo__c` (privado) | **Nunca.** Usado únicamente para el envío del comprobante digital. |
| **Nombre o Razón Social (`Nombre_Donante__c`)** | Personal Confidencial | `Donacion__c.Nombre_Donante__c` (privado) | Oculto si existe un nombre público alternativo o si la donación es anónima. |
| **RFC (`RFC__c`)** | Fiscal Confidencial | `Donacion__c.RFC__c` (privado) | **Nunca.** Solo visible para Tesorería en la vista interna de facturación. |
| **Nombre para el Muro (`Nombre_Publico__c`)** | Público Consentido | `Donacion__c.Nombre_Publico__c` | Visible en el muro si el donante eligió modalidad con crédito o factura. |
| **Monto aportado (`Monto__c`)** | Financiero Consentido | `Donacion__c.Monto__c` | Visible en el muro y acumulado en la meta de la campaña. |

---

## 5. Matriz de Riesgos Conocidos y Mitigaciones

| Riesgo Identificado | Impacto | Mitigación Implementada |
|---|---|---|
| **Manipulación de montos en frontend** | Alto | El servidor (`DonationPublicController`) valida nuevamente que el monto sea ≥ $10.00 MXN, ≤ $999,999.99 MXN y tenga máximo 2 decimales. Stripe Checkout cobra el `unit_amount` verificado por Apex. |
| **Alteración de monto en Webhook** | Alto | `StripeWebhookService` compara `amount_total == Monto__c * 100` y `currency == 'mxn'`. Si difieren, la donación no se marca como Pagada y se genera un aviso `Rechazado`. |
| **Ataque de repetición (Replay Attack)** | Medio | Verificación del header `Stripe-Signature`: se rechazan firmas con más de 300 segundos (5 minutos) de diferencia respecto al reloj del servidor. |
| **Eventos duplicados de Stripe** | Bajo | Control de idempotencia en `Aviso_Pasarela__c` por `Stripe_Event_Id__c`: retornos automáticos HTTP 200 sin duplicar cobros ni correos. |
| **Fallo en servicio de correos** | Bajo | `DonationReceiptService` captura errores de `Messaging.sendEmail()` en `Error_Comprobante__c` sin hacer rollback del pago ni bloquear la transacción. |

---

## 6. Seguridad del Endpoint Webhook de Stripe

- **URL Oficial en LWR:** `https://<dominio-sandbox>.sandbox.my.site.com/md2026vforcesite/services/apexrest/stripe/webhook`
- **Autenticación Criptográfica:** HMAC-SHA256 utilizando la firma `v1` calculada sobre `timestamp.rawBody` con el secreto `Webhook_Secret__c`.
- **Búsqueda por Referencia Opaca:** La donación se localiza exclusivamente mediante `Referencia_Publica__c` (UUID) o `Stripe_Session_Id__c`, bloqueando la fila con `FOR UPDATE`. Nunca se acepta ni consulta por el ID interno de Salesforce.
- **Auditoría:** Cada solicitud procesada, rechazada o duplicada genera un registro de auditoría en `Aviso_Pasarela__c`.
