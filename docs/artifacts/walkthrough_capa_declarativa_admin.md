# Walkthrough: Capa Declarativa de Administración (`US-09`, `US-10`, `US-11`, `US-13`)

**Proyecto:** Portal de Donaciones Mexico Dreamin 2026 — SF Vibe Lab  
**Fecha:** 2026-11-06  
**Autor:** Integrante 3 (Frontend & Declarative Specialist)  
**Alcance:** Custom Tabs, Page Layouts, Lightning Application, List Views y Permission Set administrativo.

---

## 1. Resumen de Artefactos Declarativos Creados

### 1.1 Custom Tabs (`force-app/main/default/tabs/`)
| Archivo de Pestaña | Objeto Asociado | Motivo / Icono | Propósito |
|---|---|---|---|
| `Campana__c.tab-meta.xml` | `Campana__c` | `Custom41: Stack of Cash` | Acceso y gestión de campañas de patrocinio estudiantil. |
| `Donacion__c.tab-meta.xml` | `Donacion__c` | `Custom17: Sack` | Visualización, seguimiento y conciliación de donaciones. |
| `Aviso_Pasarela__c.tab-meta.xml` | `Aviso_Pasarela__c` | `Custom67: Gears` | Auditoría de webhooks y notificaciones recibidas de Stripe. |

---

### 1.2 Lightning Application (`force-app/main/default/applications/`)
- **`Gestion_Donaciones_MD2026.app-meta.xml`:**
  - **Label:** `Gestión de Donaciones MD2026`
  - **Tipo de Navegación:** Estándar Lightning (`Standard`)
  - **Pestañas incluidas en barra de navegación:**
    1. Inicio (`standard-home`)
    2. Campañas (`Campana__c`)
    3. Donaciones (`Donacion__c`)
    4. Avisos de Pasarela (`Aviso_Pasarela__c`)
    5. Informes (`standard-report`)
    6. Paneles de control (`standard-Dashboard`)

---

### 1.3 Page Layouts (`force-app/main/default/layouts/`)
1. **`Campana__c-Campaña Layout.layout-meta.xml` (`US-09`):**
   - **Campos Principales:** `Name`, `Activa__c`, `Meta__c`, `Monto_Recaudado__c` (solo lectura), `Fecha_Fin__c`, `Permitir_Sobrecupo__c`, `OwnerId`.
   - **Sección de Detalle:** `Descripcion__c` (área de texto enriquecido/largo).
   - **Auditoría:** `CreatedById`, `LastModifiedById`.
   - **Lista Relacionada:** `Donacion__c.Campana__c` con columnas de Folio, Monto, Modalidad, Estado, Nombre del Donante, Tipo de Confirmación y Fecha de Creación.
2. **`Donacion__c-Donación Layout.layout-meta.xml` (`US-10`):**
   - **Sección Información General:** `Name`, `Campana__c`, `Monto__c`, `Modalidad__c`, `Estado__c`, `Tipo_Confirmacion__c`.
   - **Sección Donante y Facturación:** `Nombre_Donante__c`, `Correo__c`, `RFC__c`, `Solicita_Factura__c`.
   - **Sección Control de Pasarela:** `Stripe_Session_Id__c`, `Comprobante_Enviado__c`.
   - **Acciones Rápidas en Cabecera:** Quick Action `Donacion__c.Confirmar_Pago_Manual` para que Tesorería confirme pagos manuales directamente.
   - **Lista Relacionada:** `Aviso_Pasarela__c.Donacion__c` para auditar intentos de notificación de Stripe asociados.
3. **`Aviso_Pasarela__c-Aviso de Pasarela Layout.layout-meta.xml` (`US-13`):**
   - **Campos:** `Name`, `Stripe_Event_Id__c`, `Estado_Aviso__c`, `Motivo_Rechazo__c`, `Fecha_Recepcion__c`, `Donacion__c`.

---

### 1.4 List Views (`objects/<Object>/listViews/`)
| Objeto | Nombre de Vista | Filtros Aplicados | Columnas Desplegadas | Historia de Usuario |
|---|---|---|---|---|
| `Campana__c` | `Campanas_Activas` | `Activa__c = 1` | Name, Meta, Monto Recaudado, Fecha Fin, Permitir Sobrecupo, Activa | `US-09 AC1` |
| `Campana__c` | `Todas_las_Campanas` | Todos los registros | Name, Meta, Monto Recaudado, Fecha Fin, Permitir Sobrecupo, Activa | `US-09 AC2` |
| `Donacion__c` | `Todas_las_Donaciones` | Todos los registros | Name, Campaña, Monto, Modalidad, Estado, Tipo Confirmación, Solicita Factura, Fecha Creación | `US-10 AC1` |
| `Donacion__c` | `Solicitudes_de_Factura` | `Solicita_Factura__c = 1` | Name, Campaña, Nombre Donante, RFC, Correo, Monto, Estado, Tipo Confirmación, Fecha Creación | `US-11 AC1` |
| `Donacion__c` | `Donaciones_Pendientes` | `Estado__c = 'Pendiente'` | Name, Campaña, Monto, Modalidad, Nombre Donante, Correo, Fecha Creación | `US-12 AC1` |
| `Aviso_Pasarela__c` | `Avisos_Rechazados` | `Estado_Aviso__c = 'Rechazado'` | Name, Stripe Event Id, Estado Aviso, Motivo Rechazo, Fecha Recepción, Donación | `US-13 AC1` |
| `Aviso_Pasarela__c` | `Todos_los_Avisos` | Todos los registros | Name, Stripe Event Id, Estado Aviso, Motivo Rechazo, Fecha Recepción, Donación | `US-13 AC2` |

---

### 1.5 Permission Set (`force-app/main/default/permissionsets/`)
- **`Coordinacion_Tesoreria_Admin.permissionset-meta.xml`:**
  - Otorga control CRUD completo (`allowCreate`, `allowRead`, `allowEdit`, `allowDelete`, `viewAllRecords`, `modifyAllRecords`) sobre `Campana__c`, `Donacion__c` y `Aviso_Pasarela__c`.
  - Permisos a nivel de campo (FLS) en lectura y edición para todos los campos operables de negocio, y de solo lectura para campos calculados (`Campana__c.Monto_Recaudado__c` y `Donacion__c.Solicita_Factura__c`).
  - Visibilidad explícita de las tres Custom Tabs y de la aplicación `Gestion_Donaciones_MD2026`.
