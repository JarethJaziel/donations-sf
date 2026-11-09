# Plan de Pruebas, Seguridad y Checklist Pre-Entrega — SF Vibe Lab

> **Propósito:** Garantizar el cumplimiento de los criterios de aceptación (positivos y negativos), los mínimos de aprobación (**M1**, **M2**, **M3**) y la calidad de código (**C6**) antes de cada entrega o Pull Request.

## 1. Verificación de Mínimos Críticos (Zero Tolerance)

- [x] **M1 (100% Modo Prueba y Datos Ficticios):**
  - [x] Solo se usan tarjetas de prueba de Stripe (`4242...`) y correos con dominio reservado `@example.com`.
  - [x] Ningún RFC real de terceros ha sido ingresado en pruebas ni en base de datos.
- [x] **M2 (Mínimo Privilegio en Guest User Profile):**
  - [x] El perfil del Guest User en Experience Cloud (`Portal Donaciones MD2026 Perfil`) tiene `Read = false`, `Create = false`, `Edit = false`, `Delete = false` en `Donacion__c`, `Campana__c` y `Aviso_Pasarela__c`.
  - [x] Ningún método `@AuraEnabled` devuelve instancias directas de `Donacion__c`; todos usan DTOs que omiten `Correo__c` y `RFC__c`.
  - [x] Ningún método público recibe ni devuelve el Id de una donación; solo se utiliza `Referencia_Publica__c` (UUID opaco).
- [x] **M3 (Cero Secretos en Código o Git):**
  - [x] Auditoría limpia en historial de Git: ningún archivo contiene prefijos de llaves reales (`sk_test_...`, `whsec_...`).
  - [x] `Stripe_Config__c` (Custom Setting protegido) configurado manualmente en la Org.

---

## 2. Matriz de Pruebas Funcionales y Casos Negativos

| ID Caso | Historia / RF | Escenario | Entrada | Resultado Esperado | Estado |
|---|---|---|---|---|---|
| TC-01 | `RF-D1a` | Campaña vencida por fecha | `Fecha_Fin__c < TODAY()` | El portal muestra campaña cerrada y Apex rechaza nuevas donaciones. | ✅ Pasando |
| TC-02 | `RF-D1a` | Campaña en 100% sin sobrecupo | `Monto_Recaudado__c >= Meta__c` y `Permitir_Sobrecupo__c = false` | No permite iniciar checkout; muestra mensaje "Meta alcanzada". | ✅ Pasando |
| TC-03 | `RF-D1a` | Campaña en 100% con sobrecupo | `Monto_Recaudado__c >= Meta__c` y `Permitir_Sobrecupo__c = true` | Permite donar normalmente mientras `Vigente__c = true`. | ✅ Pasando |
| TC-04 | `RF-D2` | Donación Anónima | `Modalidad = 'Anónima'`, Correo, Monto | Guarda `Nombre_Donante__c = null`; nunca aparece en muro público ni en recibo con nombre. | ✅ Pasando |
| TC-05 | `RF-C1` | Donación Con Crédito | `Modalidad = 'Con crédito'`, Nombre, Correo, Monto | Mientras es `Pendiente` no suma ni aparece; al pasar a `Pagada` aparece Nombre Público y Monto en el muro. | ✅ Pasando |
| TC-06 | `RF-F1` | Donación Con Factura (RFC válido) | `Modalidad = 'Con factura'`, Razón Social, RFC válido (`EKU9003173C9`), Correo, Monto | Activa `Solicita_Factura__c = true`; al pagarse aparece en muro público (oculta RFC y Correo). | ✅ Pasando |
| TC-07 | `RF-F1` | Donación Con Factura (RFC inválido/fecha inexistente) | RFC con 30 de febrero (`GODE560230GR8`) | LWC y Apex bloquean el registro indicando que la fecha no existe. | ✅ Pasando |
| TC-08 | `US-02` | Monto menor al mínimo de Stripe ($10.00 MXN) | Monto $9.99 MXN | LWC y Apex bloquean el checkout ("El monto mínimo es $10.00 MXN"). | ✅ Pasando |
| TC-09 | `US-02` | Monto mayor al límite de Stripe ($999,999.99 MXN) | Monto $1,000,000.00 MXN | LWC y Apex bloquean el checkout ("El monto máximo por transacción en Stripe es $999,999.99 MXN"). | ✅ Pasando |
| TC-10 | `US-02` | Confirmación en montos altos | Monto $1,000.00 MXN o superior | Se despliega diálogo modal con el monto exacto antes de redirigir a Stripe. | ✅ Pasando |
| TC-11 | `US-06` | Generación de referencia pública opaca | Inicio de checkout | Se genera UUID único; Stripe recibe `metadata[referencia]` y nunca el Id del registro. | ✅ Pasando |
| TC-12 | `US-07` | Cancelación de pago en pasarela | Usuario pulsa "Volver" o cancelar en Stripe | Redirección a `/md2026/pago-cancelado`; aclara que no hubo cargos. | ✅ Pasando |
| TC-13 | `US-08` | Fallo de entregabilidad de correo en Salesforce | Envío de correo rechazado por configuración | Se registra el motivo en `Error_Comprobante__c` sin revertir el estado de la donación pagada. | ✅ Pasando |
| TC-14 | `US-12` | Confirmación Manual por Tesorería | Donación en estado Pendiente | Pasa a `Pagada` con `Tipo_Confirmacion__c = 'Manual'`, inmutable ante ediciones posteriores. | ✅ Pasando |
| TC-15 | `US-16` | Webhook de pago confirmado | Evento `checkout.session.completed` firmado | Pasa a `Pagada` con `Tipo_Confirmacion__c = 'Automática'`, fecha de pago actual y aviso `Procesado`. | ✅ Pasando |
| TC-16 | `US-16` | Webhook con monto o moneda alterada | `amount_total` o `currency` no coinciden | Donación permanece en `Pendiente`; genera aviso con estado `Rechazado`. | ✅ Pasando |
| TC-17 | `US-16` | Webhook de sesión expirada | Evento `checkout.session.expired` | Donación `Pendiente` pasa a `Expirada`; aviso `Procesado`. | ✅ Pasando |
| TC-18 | `US-17` | Webhook con firma inválida o ausente | Firma HMAC incorrecta o header ausente | Retorna HTTP 400 y genera aviso `Rechazado`. | ✅ Pasando |
| TC-19 | `US-17` | Webhook con timestamp expirado (> 5 min) | Firma antigua (posible replay attack) | Retorna HTTP 400 y genera aviso `Rechazado`. | ✅ Pasando |
| TC-20 | `US-17` | Webhook duplicado (Idempotencia) | Mismo `evt_...` enviado por segunda vez | Retorna HTTP 200 y registra aviso `Duplicado Ignorado` sin duplicar comprobantes. | ✅ Pasando |
