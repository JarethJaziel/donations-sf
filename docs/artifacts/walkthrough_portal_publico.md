# Walkthrough: Portal Público y Stripe Checkout (Integrante 2)

**Fecha:** 2026-11-08
**Historias:** `US-01`, `US-02`, `US-03`, `US-04`, `US-05`, `US-06`, `US-14`
**Origen:** prompt de la sección 1 de [`guia_ejecucion_integrantes_2_3_4.md`](./guia_ejecucion_integrantes_2_3_4.md) y sección 6 de [`CLAUDE.md`](../../CLAUDE.md).
**Estado:** desplegado y publicado en la sandbox del equipo. Probado como visitante anónimo.

---

## 1. Sitio de Experience Cloud

| Elemento | Valor |
|---|---|
| Nombre | Portal Donaciones MD2026 |
| Plantilla | Build Your Own (LWR) |
| Ruta pública | `/md2026` (la ruta `/donaciones` pertenece a un sitio antiguo de la org) |
| Estado | Activo (Live), acceso público para invitados |
| Páginas | `/` (portal), `/agradecimiento`, `/pago-cancelado` |

- Las páginas `/agradecimiento` y `/pago-cancelado` tienen un **texto provisional** correcto (no afirma que el pago esté confirmado y aclara que no hubo cargo). El Integrante 3 lo sustituye por sus componentes `paginaAgradecimiento` y `paginaPagoCancelado`.
- El sitio está versionado en `digitalExperiences/` y `digitalExperienceConfigs/`. Los archivos `networks/` y `sites/` **no se suben al repositorio** (están en `.gitignore`) porque contienen el correo remitente y el usuario administrador; se despliegan solo desde una máquina local.
- Después de desplegar cambios a componentes o páginas hay que publicar: `sf community publish --name "Portal Donaciones MD2026"`.

## 2. Usuario invitado (M2)

- Perfil `Portal Donaciones MD2026 Perfil` (versionado en `profiles/`): **solo** acceso a la clase `DonationPublicController`.
- **Cero permisos de objeto y de campo** sobre `Donacion__c`, `Campana__c` y `Aviso_Pasarela__c` (verificado en la org).
- Los perfiles de invitado no aparecen en Configuración → Perfiles; se abren desde Experience Builder → Configuración → General → Perfil de usuario invitado.

**Hallazgo durante la implementación:** con el perfil en cero, la primera versión fallaba con `sObject type 'Campana__c' is not supported` y luego `No such column 'Descripcion__c'`. En el contexto del invitado, Salesforce aplica la visibilidad del usuario aun dentro del Apex. En vez de darle permisos de lectura al invitado (que expondrían el esquema de correo y RFC), el controlador usa `WITH SYSTEM_MODE` en sus consultas e `insert as system`. Se probó en vivo con el perfil en cero: las consultas se ejecutan sin errores (log del invitado: campañas `Rows:1`, muro `Rows:0`).

## 3. `DonationPublicController`

| Método | Qué hace | Historias |
|---|---|---|
| `obtenerCampanasActivas()` (cacheable) | Campañas con `Vigente__c = true`; DTO con nombre, descripción, propósito, imagen, meta, recaudado, porcentaje, fecha fin, si acepta donaciones y motivo de cierre | US-01 |
| `obtenerMuroDonantes(Id campanaId)` (cacheable) | Donaciones Pagadas, con crédito o factura y visibles; DTO con **solo** nombre público (o nombre) y monto. Un Id que no es de campaña devuelve vacío | US-04, US-15 AC5 |
| `iniciarDonacion(SolicitudDonacionDTO)` | Valida, crea la sesión de Stripe y después inserta la donación Pendiente; devuelve **solo** la URL de Checkout | US-02, US-03, US-05, US-06 |

Validaciones del servidor en `iniciarDonacion`:
- La campaña debe estar vigente y aceptar donaciones.
- El monto debe ser de al menos $10.00, con máximo 2 decimales; no hay máximo propio.
- El correo es obligatorio y debe ser válido.
- Modalidad:
  - **Anónima:** descarta nombre, nombre público y RFC.
  - **Con crédito:** exige nombre y descarta el RFC.
  - **Con factura:** exige nombre y un RFC válido con `RfcValidator`.

Parámetros enviados a Stripe:
- `client_reference_id` y `metadata[referencia]` con el UUID (nunca el Id).
- `expires_at` = 1 hora.
- `submit_type=donate`, `locale=es`, `currency=mxn` y el monto en centavos.
- `success_url` y `cancel_url` desde `Stripe_Config__c`.
- Encabezado `Idempotency-Key` con la referencia.

Si Stripe falla, no se inserta nada y el donante ve un mensaje genérico.

**Pruebas:** `DonationPublicControllerTest`, 14 pruebas, 100% de cobertura. Cubren:
- campañas vigentes, futuras, inactivas y llenas;
- un muro sin correo, RFC ni fecha;
- que el body enviado a Stripe no contiene el Id del registro;
- montos inválidos, datos del donante inválidos y RFC con fecha inexistente;
- el Id de una donación usado como campaña;
- Stripe con error y con respuesta incompleta;
- sin configuración y error al insertar.

## 4. Componentes LWC

| Componente | Expuesto | Contenido |
|---|---|---|
| `portalCampanasPublico` | Sí (se arrastra a la página) | Lista de campañas con imagen, descripción, barra de progreso y fecha; abre directo si solo hay una (US-01 AC8); detalle con propósito; contiene el formulario y el muro |
| `formularioDonacionPublico` | No (hijo) | 8 montos sugeridos + monto libre; validación en vivo de monto, correo, nombre y RFC (misma regla que `RfcValidator`); al cambiar a Anónima limpia nombre, nombre público y RFC; diálogo de confirmación desde $1,000; redirige a Stripe |
| `muroDonantesPublico` | No (hijo) | Solo nombre público y monto; desplazamiento automático desde 6 donantes, se pausa al pasar el mouse o con el foco, y respeta "reducir movimiento" |

Los textos están en español y el diseño es responsivo. Los componentes no guardan datos del donante en el navegador ni en la URL.

## 5. Configuración en la org (no está en el repositorio)

- `Stripe_Config__c`:
  - `Success_URL__c` = `<sitio>/md2026/agradecimiento`
  - `Cancel_URL__c` = `<sitio>/md2026/pago-cancelado`
- **Pendiente:** la **llave secreta de prueba de Stripe** (`Secret_Key__c`). Mientras no exista, el formulario muestra "El pago en línea no está disponible en este momento". Debe cargarla alguien del equipo en Configuración → Configuración personalizada → Stripe Config → Administrar. Nunca debe escribirse en el repositorio ni en un chat.
- La campaña existente ya tiene fecha de inicio y propósito, por eso aparece en el portal.

## 6. Cómo probar

1. Abre `https://<dominio-del-sitio>/md2026` en una **ventana de incógnito** (con la sesión de Salesforce abierta se entra como administrador, no como invitado).
2. Verifica la campaña, el avance y el muro.
3. Elige $2,000: debe aparecer el diálogo de confirmación.
4. Prueba un monto de $9.99, un correo inválido y un RFC con fecha 30 de febrero: el formulario debe bloquearlos.
5. Con la llave de Stripe cargada:
   - paga con la tarjeta de prueba `4242 4242 4242 4242`: debes volver a `/agradecimiento` y en Salesforce la donación aparece **Pendiente** con su referencia pública;
   - cancela en Stripe: debes volver a `/pago-cancelado`.
   La confirmación automática (paso a Pagada) llega con el webhook en Entrega 2.

## 7. Pendientes

- Cargar la llave de prueba de Stripe en la org.
- Integrante 3: componentes de agradecimiento y pago cancelado.
- Integrante 4: pruebas de seguridad del invitado (US-15) y datos semilla.
- Correr `sf code-analyzer run` en un equipo con Java 11+.
- Revisar el flujo completo de pago en cuanto haya llave (el insert del invitado con `insert as system` solo se ha probado en pruebas unitarias).
