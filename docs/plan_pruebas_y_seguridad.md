# Plan de Pruebas, Seguridad y Checklist Pre-Entrega — SF Vibe Lab

> **Propósito:** Garantizar el cumplimiento de los criterios de aceptación (positivos y negativos), los mínimos de aprobación (**M1**, **M2**, **M3**) y la calidad de código (**C6**) antes de cada entrega o Pull Request.

## 1. Verificación de Mínimos Críticos (Zero Tolerance)

- [ ] **M1 (100% Modo Prueba y Datos Ficticios):**
  - [ ] Solo se usan tarjetas de prueba de Stripe (`4242...`) y correos controlados por el equipo.
  - [ ] Ningún RFC real de terceros ha sido ingresado en pruebas ni en datos semilla.
- [ ] **M2 (Mínimo Privilegio en Guest User Profile):**
  - [ ] El perfil del Guest User en Experience Cloud tiene `Read = false`, `Create = false`, `Edit = false`, `Delete = false` en `Donacion__c` y `Aviso_Pasarela__c`.
  - [ ] Ningún método `@AuraEnabled` devuelve instancias directas de `Donacion__c`; todos usan clases DTO/Wrapper que omiten `Correo__c` y `RFC__c`.
- [ ] **M3 (Cero Secretos en Código o Git):**
  - [ ] Ejecución limpia de auditoría en historial de Git: ningún archivo contiene prefijos de llaves de Stripe ni tokens reales.
  - [ ] `Stripe_Config__c` configurado manualmente en `Setup -> Custom Settings -> Stripe Config -> Manage`.

## 2. Matriz de Pruebas Funcionales y Casos Negativos

| ID Caso | Historia / RF | Escenario | Entrada | Resultado Esperado | Estado |
|---|---|---|---|---|---|
| TC-01 | `RF-D1a` | Campaña vencida por fecha | `Fecha_Fin__c = YESTERDAY()` | El portal muestra campaña cerrada y Apex rechaza nuevas donaciones. | Pendiente |
| TC-02 | `RF-D1a` | Campaña en 100% sin sobrecupo | `Monto_Recaudado__c >= Meta__c` y `Permitir_Sobrecupo__c = false` | No permite iniciar checkout; muestra mensaje de meta alcanzada. | Pendiente |
| TC-03 | `RF-D1a` | Campaña en 100% con sobrecupo | `Monto_Recaudado__c >= Meta__c` y `Permitir_Sobrecupo__c = true` | Permite donar normalmente mientras `Fecha_Fin__c >= TODAY()`. | Pendiente |
| TC-04 | `RF-D2` | Donación Anónima | `Modalidad = 'Anónima'`, Correo, Monto | Guarda `Nombre_Donante__c = null`; nunca aparece en muro público ni en recibo con nombre. | Pendiente |
| TC-05 | `RF-C1` | Donación Con Crédito | `Modalidad = 'Con crédito'`, Nombre, Correo, Monto | Mientras es `Pendiente` no suma ni aparece; al pasar a `Pagada` aparece Nombre y Monto en el muro. | Pendiente |
| TC-06 | `RF-F1` | Donación Con Factura (RFC válido) | `Modalidad = 'Con factura'`, Razón Social, RFC válido (`XAXX010101AAA`), Correo, Monto | Activa `Solicita_Factura__c = true`; al pagarse aparece solo Nombre y Monto en muro público (oculta RFC y Correo). | Pendiente |
| TC-07 | `RF-F1` | Donación Con Factura (RFC inválido) | RFC con formato erróneo (`ABC123`) | LWC y Apex bloquean el registro mostrando mensaje claro en español. | Pendiente |
| TC-08 | `RF-V3b` | Webhook con firma inválida | Header `Stripe-Signature` alterado o ausente | Crea `Aviso_Pasarela__c` con `Estado_Aviso__c = 'Rechazado'`, retorna HTTP `400`, no modifica `Donacion__c`. | Pendiente |
| TC-09 | `RF-V3b` | Webhook duplicado (Idempotencia) | Mismo `evt_...` enviado 2 veces | El segundo envío se registra como `'Duplicado Ignorado'`, retorna HTTP `200`, no duplica correo de recibo. | Pendiente |
