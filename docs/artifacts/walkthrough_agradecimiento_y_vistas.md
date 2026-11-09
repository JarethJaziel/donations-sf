# Guía de Evidencias: Páginas de Agradecimiento, Pago Cancelado y Vistas de Lista

Este documento detalla las pruebas funcionales y capturas de pantalla necesarias para validar las historias de usuario asignadas al Integrante 3.

## 1. Páginas de Respuesta de Pago (US-07)

### 1.1 Pagina Agradecimiento (`/agradecimiento`)
**Objetivo:** Verificar que el usuario recibe una confirmación clara pero no definitiva del pago.
- **Prueba:** Realizar una donación exitosa (usando Stripe Test Mode) y verificar la redirección a `/agradecimiento`.
- **Criterios a validar (AC1-AC4):**
  - El texto debe decir exactamente: "Recibimos tu donación; te enviaremos tu comprobante por correo cuando se confirme el pago".
  - No debe mencionar que el pago "ya fue confirmado" ni que el comprobante "ya fue enviado".
  - Debe incluir el resumen del impacto de Mexico Dreamin 2026.
  - Debe incluir un botón "Volver a las campañas" que redirija a `/`.
  - El diseño debe ser responsivo.

### 1.2 Pagina Pago Cancelado (`/pago-cancelado`)
**Objetivo:** Verificar que el usuario sepa que no hubo cargos tras una cancelación o fallo.
- **Prueba:** Simular una cancelación de pago en Stripe y verificar la redirección a `/pago-cancelado`.
- **Criterios a validar (AC5):**
  - El texto debe indicar claramente que **no se realizó ningún cargo**.
  - Debe indicar que la donación no se registró como pagada.
  - Debe incluir instrucciones para intentar nuevamente.
  - Debe incluir un botón "Volver a las campañas" que redirija a `/`.
  - El diseño debe ser responsivo.

---

## 2. Vistas de Lista y QA (US-10, US-11)

### 2.1 Todas las Donaciones (`US-10`)
**Objetivo:** Validar que la vista de lista muestra correctamente todas las donaciones procesadas.
- **Prueba:** Acceder a la vista "Todas las Donaciones" desde la aplicación de gestión.
- **Criterios a validar:**
  - Se visualizan correctamente los registros de donación.
  - Se pueden filtrar por estado (Pagada, Pendiente, Expirada).
  - La columna de "Monto" refleja el valor correcto de la donación.
  - El diseño es consistente con el resto de la aplicación de gestión.

### 2.2 Solicitudes de Factura (`US-11`)
**Objetivo:** Validar que la vista de lista permite la identificación de donantes que solicitaron factura.
- **Prueba:** Acceder a la vista "Solicitudes de Factura" desde la aplicación de gestión.
- **Criterios a validar:**
  - Se visualizan solo las donaciones con `Solicita_Factura__c = true`.
  - Se muestran correctamente los campos: `Nombre_Donante__c`, `RFC__c`, `Correo__c`, `Monto__c`, `Fecha_Pago__c`.
  - Se puede identificar rápidamente si la donación fue confirmada para emitir el comprobante.
- **Capturas requeridas:**
  - Captura de la vista en escritorio.
  - Captura de la vista en dispositivo móvil (simulado).
  - Captura de una fila con datos de donante con factura (verificar RFC y Nombre).
  - Captura de una fila con donación sin factura (verificar que no aparezca en esta vista).
