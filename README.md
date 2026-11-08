# SF Vibe Lab — Portal de Donaciones Mexico Dreamin 2026

Solución 100% hospedada en Salesforce (Experience Cloud, LWC, Apex, Flows) integrada con **Stripe Checkout Sessions** y **Webhooks** en modo de prueba para gestionar campañas de patrocinio estudiantil rumbo a **Mexico Dreamin 2026**.

---

## Tablero de Gestión y Backlog (GitHub Projects)

El seguimiento de las 17 Historias de Usuario (US-01 a US-17), criterios de aceptación, asignaciones del equipo de 4 integrantes y evidencias de entrega se gestionan en:

👉 **[Tablero del Proyecto en GitHub Projects #7](https://github.com/users/JarethJaziel/projects/7)**

---

## Estructura del Proyecto

- [`GEMINI.md`](./GEMINI.md) y [`CLAUDE.md`](./CLAUDE.md): Reglas del sistema, contexto de negocio, mínimos críticos (`M1`, `M2`, `M3`) y estándares de codificación (`C6`).
- [`docs/bitacora_ia.md`](./docs/bitacora_ia.md): Registro cronológico obligatorio de interacciones con IA (**Criterio C3 — 20 pts**).
- [`docs/preguntas_y_reportes.md`](./docs/preguntas_y_reportes.md): Registro de discovery con el cliente y reportes técnicos (**Criterio C7 — 15 pts**).
- [`docs/arquitectura_y_decisiones.md`](./docs/arquitectura_y_decisiones.md): Diagrama de secuencia y ADRs (Checkout en una transacción con referencia opaca, Seguridad Guest User `M2` y Secretos Protegidos `M3`).
- [`docs/plan_pruebas_y_seguridad.md`](./docs/plan_pruebas_y_seguridad.md): Checklist de validación de mínimos y matriz de pruebas funcionales/negativas.
- [`force-app/main/default/objects/`](./force-app/main/default/objects/):
  - `Campana__c`: Campañas de patrocinio (`Meta__c`, `Monto_Recaudado__c` Roll-Up Summary filtrado por `Estado__c = 'Pagada'`, `Activa__c`, `Fecha_Fin__c`, `Permitir_Sobrecupo__c`).
  - `Donacion__c`: Registros de donación (`Modalidad__c`, `Estado__c`, `Monto__c`, `Correo__c`, `Nombre_Donante__c`, `RFC__c`, `Solicita_Factura__c`, `Stripe_Session_Id__c`, `Tipo_Confirmacion__c`, `Comprobante_Enviado__c`) y sus 4 reglas de validación.
  - `Aviso_Pasarela__c`: Bitácora de auditoría e idempotencia para Webhooks de Stripe (`Stripe_Event_Id__c`, `Estado_Aviso__c`, `Motivo_Rechazo__c`, `Fecha_Recepcion__c`, `Donacion__c`).
  - `Stripe_Config__c`: Hierarchy Custom Setting **Protected** para almacenar llaves y URLs en la Org sin exponerlas jamás en código ni Git (`M3`).
- [`force-app/main/default/remoteSiteSettings/Stripe_API.remoteSite-meta.xml`](./force-app/main/default/remoteSiteSettings/Stripe_API.remoteSite-meta.xml): Autorización de callouts hacia `https://api.stripe.com`.

---

## Guía Rápida de Autenticación y Despliegue a tu Org

### 1. Autenticar tu Org (Sandbox o Developer Edition)
Para Sandbox (como `uadyOrg` / `jareth.moo@vibelab.sandbox`):
```bash
sf org login web --instance-url https://test.salesforce.com --alias uadyOrg --set-default
```
*(Para Developer Edition u org de producción normal, omite `--instance-url` o usa `https://login.salesforce.com`).*

### 2. Desplegar el Modelo de Datos y Configuración Base
```bash
sf project deploy start --source-dir force-app
```

### 3. Configurar `Stripe_Config__c` manualmente en Salesforce Setup (Mínimo M3)
1. En tu Org, ve a **Setup** -> **Custom Settings**.
2. Haz clic en **Manage** junto a **Stripe Config**.
3. Haz clic en **New** (a nivel *Default Organization Level Value*) y llena los valores de prueba de tu cuenta de Stripe Sandbox (`Secret_Key__c`, `Webhook_Secret__c`, `Success_URL__c`, `Cancel_URL__c`).
   > **IMPORTANTE (M3):** Jamás guardes ni escribas llaves reales o de prueba en archivos del repositorio.
