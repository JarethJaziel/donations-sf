# Guía de Evidencias Funcionales: Agradecimiento, Pago Cancelado y Vistas de Lista (US-07, US-10, US-11)

Este documento detalla las pruebas funcionales, criterios de aceptación y capturas requeridas para validar las páginas de respuesta del portal público y las vistas de lista de la aplicación de gestión.

---

## 1. Páginas de Respuesta del Portal Público (US-07)

### 1.1 Página de Agradecimiento (`/md2026/agradecimiento`)
- **Objetivo:** Informar al donante que la donación fue recibida y que el comprobante se enviará por correo cuando el pago sea confirmado, sin afirmar prematuramente que ya fue confirmado ni que el comprobante ya salió (`US-07 AC1/AC2`).
- **Seguridad (M2):** No consume Apex, no ejecuta SOQL ni lee parámetros de la URL (`session_id`, correos ni folios).
- **Criterios a validar:**
  - Mensaje principal claro: *"Recibimos tu donación. Te enviaremos tu comprobante por correo cuando se confirme el pago."*
  - Resumen del impacto de Mexico Dreamin 2026 en apoyo a estudiantes.
  - Enlace funcional *"Volver a las campañas"* (`./`) que regresa a `/md2026/` sin romper la ruta de la comunidad.
  - Diseño responsivo adaptable a pantallas de escritorio (1440 px) y móviles (390 px).

### 1.2 Página de Pago Cancelado (`/md2026/pago-cancelado`)
- **Objetivo:** Brindar retroalimentación inmediata cuando el donante cancela la sesión en Stripe Checkout (`US-07 AC5`).
- **Criterios a validar:**
  - Aclaración explícita: *"No se realizó ningún cargo y tu donación no se registró como pagada."*
  - Orientación para reintentar la donación.
  - Enlace funcional *"Volver a las campañas"* (`./`).

---

## 2. Vistas de Lista de Staff en Gestión de Donaciones (US-10, US-11)

### 2.1 Vista: Todas las Donaciones (`Todas_las_Donaciones` — US-10)
- **Ruta en Salesforce:** App Launcher → **Gestión de Donaciones MD2026** → Pestaña **Donaciones** → Lista **Todas las Donaciones**.
- **Criterios a validar:**
  - Visualización completa de todos los registros (`Pagada`, `Pendiente`, `Expirada`).
  - Columnas visibles: Folio (`Name`), Campaña (`Campana__c`), Monto (`Monto__c`), Modalidad (`Modalidad__c`), Estado (`Estado__c`), Tipo de Confirmación (`Tipo_Confirmacion__c`), Fecha de Pago (`Fecha_Pago__c`), Comprobante Enviado (`Comprobante_Enviado__c`).
  - Posibilidad de ordenar por fecha de creación o folio y filtrar por estado.

### 2.2 Vista: Solicitudes de Factura (`Solicitudes_de_Factura` — US-11)
- **Ruta en Salesforce:** App Launcher → **Gestión de Donaciones MD2026** → Pestaña **Donaciones** → Lista **Solicitudes de Factura**.
- **Criterios a validar:**
  - Filtro automático: solo muestra donaciones con `Solicita_Factura__c = true` (es decir, en modalidad `Con factura`).
  - Columnas visibles: Folio, Donante / Razón Social (`Nombre_Donante__c`), RFC (`RFC__c`), Tipo de Persona (`Tipo_Persona__c`: Moral o Física), Monto, Estado, Fecha de Pago y Correo.
  - Verificación de que las donaciones en modalidad `Anónima` o `Con crédito` no aparecen en esta vista.

---

## 3. Checklist de Capturas de Pantalla para Entrega

1. **Agradecimiento (`US-07`):**
   - Captura de `/md2026/agradecimiento` en escritorio y móvil.
2. **Pago Cancelado (`US-07`):**
   - Captura de `/md2026/pago-cancelado` en escritorio y móvil.
3. **List View Todas las Donaciones (`US-10`):**
   - Captura de la vista mostrando registros en estados `Pagada` y `Pendiente`.
4. **List View Solicitudes de Factura (`US-11`):**
   - Captura de la vista con registros con RFC de 12 (Moral) y 13 (Física) caracteres.
