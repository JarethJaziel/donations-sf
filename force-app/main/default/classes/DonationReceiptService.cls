/**
 * @description Servicio encargado de la generación y envío automatizado de comprobantes
 *              personalizados por modalidad de donación (US-08, RF-D5, RF-S3).
 */
public without sharing class DonationReceiptService {

    /**
     * @description Envía los comprobantes por correo electrónico para un conjunto de donaciones pagadas.
     *              Garantiza idempotencia validando Comprobante_Enviado__c = false.
     * @param donacionIds Conjunto de identificadores de Donacion__c a procesar.
     */
    public static void enviarComprobantes(Set<Id> donacionIds) {
        if (donacionIds == null || donacionIds.isEmpty()) {
            return;
        }

        List<Donacion__c> donaciones = [
            SELECT Id, Name, Monto__c, Modalidad__c, Estado__c, Nombre_Donante__c,
                   Correo__c, RFC__c, Solicita_Factura__c, Comprobante_Enviado__c,
                   Campana__r.Name
            FROM Donacion__c
            WHERE Id IN :donacionIds
              AND Estado__c = 'Pagada'
              AND Comprobante_Enviado__c = false
        ];

        if (donaciones.isEmpty()) {
            return;
        }

        List<Messaging.SingleEmailMessage> mensajes = new List<Messaging.SingleEmailMessage>();
        List<Donacion__c> donacionesParaActualizar = new List<Donacion__c>();

        for (Donacion__c donacion : donaciones) {
            if (String.isNotBlank(donacion.Correo__c)) {
                Messaging.SingleEmailMessage mail = new Messaging.SingleEmailMessage();
                mail.setToAddresses(new List<String>{ donacion.Correo__c.trim() });
                mail.setSubject(construirAsuntoCorreo(donacion));
                mail.setPlainTextBody(construirCuerpoCorreo(donacion));
                mail.setSaveAsActivity(false);
                mensajes.add(mail);

                donacionesParaActualizar.add(new Donacion__c(
                    Id = donacion.Id,
                    Comprobante_Enviado__c = true
                ));
            }
        }

        if (!mensajes.isEmpty()) {
            Messaging.sendEmail(mensajes, false);
        }

        if (!donacionesParaActualizar.isEmpty()) {
            update donacionesParaActualizar;
        }
    }

    /**
     * @description Construye el asunto estándar para el correo de comprobante.
     * @param donacion Registro de Donacion__c con información básica.
     * @return Asunto formateado del comprobante.
     */
    @TestVisible
    private static String construirAsuntoCorreo(Donacion__c donacion) {
        String folio = String.isNotBlank(donacion.Name) ? donacion.Name : 'Folio Pendiente';
        return 'Comprobante de Donación - ' + folio + ' | Mexico Dreamin 2026';
    }

    /**
     * @description Construye el cuerpo del comprobante en texto plano adaptado estrictamente
     *              a la modalidad de la donación (US-08 AC1, AC2, AC3, M2).
     * @param donacion Registro de Donacion__c con campos de campaña y donante.
     * @return Cuerpo del correo formateado.
     */
    @TestVisible
    private static String construirCuerpoCorreo(Donacion__c donacion) {
        String campanaNombre = (donacion.Campana__r != null && String.isNotBlank(donacion.Campana__r.Name))
            ? donacion.Campana__r.Name
            : 'Campaña Mexico Dreamin 2026';
        String fecha = Date.today().format();
        String montoFormateado = '$' + (donacion.Monto__c != null ? String.valueOf(donacion.Monto__c.setScale(2)) : '0.00') + ' MXN';
        String folio = donacion.Name != null ? donacion.Name : '';

        String cuerpo = '';

        if (donacion.Modalidad__c == 'Anónima') {
            // US-08 AC1 & M2: Prohibido exponer Nombre_Donante__c o RFC__c
            cuerpo = '¡Muchas gracias por tu generosidad!\n\n'
                   + 'Hemos recibido tu donación con éxito:\n'
                   + '- Folio de Donación: ' + folio + '\n'
                   + '- Campaña: ' + campanaNombre + '\n'
                   + '- Fecha de Confirmación: ' + fecha + '\n'
                   + '- Monto Aportado: ' + montoFormateado + '\n\n'
                   + 'Gracias por tu aportación anónima para apoyar a estudiantes en Mexico Dreamin 2026.\n'
                   + 'Tu donación impulsará el futuro de jóvenes talentos en el ecosistema Salesforce.';
        } else if (donacion.Modalidad__c == 'Con crédito') {
            // US-08 AC2: Nombre, Folio, Campaña, Fecha, Monto y confirmación en muro público
            String nombre = String.isNotBlank(donacion.Nombre_Donante__c) ? donacion.Nombre_Donante__c : 'Apreciable Donante';
            cuerpo = 'Estimado/a ' + nombre + ',\n\n'
                   + '¡Agradecemos enormemente tu valiosa contribución a la causa!\n\n'
                   + 'Detalle de tu donación confirmada:\n'
                   + '- Donante: ' + nombre + '\n'
                   + '- Folio de Donación: ' + folio + '\n'
                   + '- Campaña: ' + campanaNombre + '\n'
                   + '- Fecha de Confirmación: ' + fecha + '\n'
                   + '- Monto Aportado: ' + montoFormateado + '\n\n'
                   + 'Te confirmamos con orgullo que tu nombre y el monto de tu aportación formarán parte del muro público de reconocimiento de la campaña en nuestro portal oficial.\n\n'
                   + '¡Gracias por ser parte del sueño de Mexico Dreamin 2026!';
        } else if (donacion.Modalidad__c == 'Con factura') {
            // US-08 AC3: Razón Social, RFC, Folio, Campaña, Fecha, Monto y confirmación de trámite en Tesorería
            String razonSocial = String.isNotBlank(donacion.Nombre_Donante__c) ? donacion.Nombre_Donante__c : 'Apreciable Donante';
            String rfc = String.isNotBlank(donacion.RFC__c) ? donacion.RFC__c : 'Pendiente';
            cuerpo = 'Estimado/a ' + razonSocial + ',\n\n'
                   + 'Confirmamos la recepción exitosa de tu donación y los datos fiscales proporcionados:\n\n'
                   + 'Detalle de la Donación:\n'
                   + '- Nombre / Razón Social: ' + razonSocial + '\n'
                   + '- RFC: ' + rfc + '\n'
                   + '- Folio de Donación: ' + folio + '\n'
                   + '- Campaña: ' + campanaNombre + '\n'
                   + '- Fecha de Confirmación: ' + fecha + '\n'
                   + '- Monto Aportado: ' + montoFormateado + '\n\n'
                   + 'Tu solicitud de factura ha sido registrada exitosamente y se encuentra en proceso de revisión y timbrado con nuestro equipo de Tesorería.\n\n'
                   + 'Adicionalmente, te recordamos que tu nombre y monto aparecerán en el muro público de donantes de la campaña.\n\n'
                   + 'Agradecemos tu valioso apoyo para los estudiantes de Mexico Dreamin 2026.';
        } else {
            // Caso genérico preventivo
            cuerpo = 'Comprobante de Donación Confirmada\n\n'
                   + '- Folio: ' + folio + '\n'
                   + '- Campaña: ' + campanaNombre + '\n'
                   + '- Fecha: ' + fecha + '\n'
                   + '- Monto: ' + montoFormateado + '\n\n'
                   + '¡Gracias por apoyar a los estudiantes para Mexico Dreamin 2026!';
        }

        return cuerpo;
    }
}
