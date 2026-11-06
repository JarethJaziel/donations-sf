# Walkthrough: Confirmación Manual de Pagos y Motor de Recibos Personalizados (`US-08`, `US-12`)

**Proyecto:** Portal de Donaciones Mexico Dreamin 2026 — SF Vibe Lab  
**Fecha:** 2026-11-06  
**Autor:** Integrante 2 (Backend & Automation Developer)  
**Alcance:** `DonationReceiptService`, `DonacionTriggerHandler`, `DonacionTrigger`, `DonationAdminController`, LWC `confirmarPagoAction`, Quick Action y Record Page.

---

## 1. Arquitectura del Motor de Comprobantes (`DonationReceiptService.cls` — `US-08`)

El servicio `DonationReceiptService` centraliza la emisión de correos de confirmación una vez que una donación adquiere el estado `'Pagada'`.

### 1.1 Reglas Estrictas de Privacidad y Personalización por Modalidad
- **Modalidad `'Anónima'` (`US-08 AC1`, `RF-D5`, M2):**
  - Muestra: Folio de la Donación (`Name`), Nombre de la Campaña (`Campana__r.Name`), Fecha de Confirmación y Monto aportado.
  - Mensaje de Agradecimiento: Mensaje general de agradecimiento a los estudiantes sin revelar información personal.
  - **REGLA CRÍTICA DE SEGURIDAD (M2):** Bajo ninguna circunstancia se imprime `Nombre_Donante__c` o `RFC__c` en el cuerpo del correo o en el asunto, garantizando el anonimato absoluto.
- **Modalidad `'Con crédito'` (`US-08 AC2`):**
  - Muestra: Nombre del Donante (`Nombre_Donante__c`), Folio, Campaña, Fecha y Monto aportado.
  - Mensaje: Confirmación explícita de que su nombre y monto donado aparecerán en el muro público de donantes de la campaña.
- **Modalidad `'Con factura'` (`US-08 AC3`):**
  - Muestra: Nombre / Razón Social (`Nombre_Donante__c`), RFC (`RFC__c`), Folio, Campaña, Fecha y Monto aportado.
  - Mensaje: Confirmación expresa de que la solicitud fiscal ha sido registrada y turnada a revisión del equipo de Tesorería.

### 1.2 Idempotencia y Prevención de Envíos Duplicados
- La query de donaciones filtra rigurosamente `Comprobante_Enviado__c = false`.
- Tras la invocación fuera del loop a `Messaging.sendEmail(mensajes, false)`, se actualiza en lote el campo `Comprobante_Enviado__c = true` en las donaciones procesadas.

---

## 2. Trigger y Handler Automatizado (`DonacionTrigger` y `DonacionTriggerHandler`)

- **Evento:** `after update` en `Donacion__c`.
- **Detección de Transición:** Comprueba que `oldDonacion.Estado__c != 'Pagada' && newDonacion.Estado__c == 'Pagada' && !newDonacion.Comprobante_Enviado__c`.
- **Control de Transacción:** Mantiene una memoria estática `procesadosEnTransaccion` para prevenir recursiones o re-entradas durante la misma transacción Apex.
- **Recálculo de Campañas:** Dispara `recalcularMontoRecaudadoCampanas` ante transiciones de estado hacia o desde `'Pagada'`, o ante cambios en monto o reasignación de campaña, validando dinámicamente si el campo `Monto_Recaudado__c` requiere agregación manual (ej. tipo Currency) o delegación a Summary nativo.

---

## 3. Confirmación Manual de Tesorería (`US-12`)

### 3.1 Controlador Apex (`DonationAdminController.cls`)
- `obtenerResumenDonacion(Id donacionId)`: Retorna un DTO limpio (`ResumenConfirmacionDTO`) con los campos esenciales para la interfaz administrativa.
- `confirmarPagoManual(Id donacionId)`:
  - Ejecuta `SELECT ... FOR UPDATE` para evitar condiciones de carrera (*race conditions*).
  - **Validación AC4:** Si el estado actual es `'Pagada'`, arroja `AuraHandledException` con el mensaje:
    `"Esta donación ya fue confirmada como Pagada previamente. No se permiten confirmaciones ni comprobantes duplicados."`
  - Si el estado es distinto de `'Pendiente'`, rechaza la acción con `AuraHandledException`.
  - Actualiza `Estado__c = 'Pagada'` y `Tipo_Confirmacion__c = 'Manual'`, disparando en cascada el trigger para la emisión del comprobante y el recálculo de recaudación.

### 3.2 Interfaz LWC (`confirmarPagoAction`)
- Modal implementado con `lightning-quick-action-panel`.
- Muestra el resumen del donante, campaña, monto y estado actual.
- Si el registro ya está en `'Pagada'`, despliega un aviso amarillo informativo y desactiva el botón de confirmación.
- Al confirmar con éxito, emite un `ShowToastEvent` de variante `success`, refresca la caché de registro con `notifyRecordUpdateAvailable` y cierra el modal automáticamente con `CloseActionScreenEvent`.
