/**
 * @description Servicio encargado de la generación y envío automatizado de comprobantes
 *              personalizados por modalidad de donación (US-05 AC4, US-08, RF-D5, RF-S3).
 *              Solo marca Comprobante_Enviado__c cuando el correo se envió con éxito; si falla,
 *              registra el motivo en Error_Comprobante__c sin revertir el pago (US-08 AC5).
 */
@SuppressWarnings('PMD.ApexCRUDViolation, PMD.CyclomaticComplexity')
public without sharing class DonationReceiptService {

    /**
     * @description Solo en pruebas: 'exito' simula un envío correcto y 'fallo' un envío fallido,
     *              para no depender de la configuración de entregabilidad de la org. En producción se ignora.
     */
    @TestVisible
    private static String simulacionEnvio = null;

    private static final String ZONA_HORARIA = 'America/Mexico_City';
    private static final Integer MAX_ERROR = 255;

    private class EnvioComprobanteException extends Exception {}

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
            SELECT Id, Name, Monto__c, Modalidad__c, Estado__c, Nombre_Donante__c, Nombre_Publico__c,
                   Correo__c, RFC__c, Solicita_Factura__c, Comprobante_Enviado__c, Fecha_Pago__c,
                   Campana__r.Name
            FROM Donacion__c
            WHERE Id IN :donacionIds
              AND Estado__c = 'Pagada'
              AND Comprobante_Enviado__c = false
            WITH SYSTEM_MODE
        ];

        if (donaciones.isEmpty()) {
            return;
        }

        List<Messaging.SingleEmailMessage> mensajes = new List<Messaging.SingleEmailMessage>();
        List<Donacion__c> conCorreo = new List<Donacion__c>();
        List<Donacion__c> actualizaciones = new List<Donacion__c>();

        for (Donacion__c donacion : donaciones) {
            if (String.isBlank(donacion.Correo__c)) {
                actualizaciones.add(resultado(donacion.Id, false, 'La donación no tiene correo electrónico.'));
                continue;
            }
            Messaging.SingleEmailMessage mail = new Messaging.SingleEmailMessage();
            mail.setToAddresses(new List<String>{ donacion.Correo__c.trim() });
            mail.setSubject(construirAsuntoCorreo(donacion));
            mail.setPlainTextBody(construirCuerpoCorreo(donacion));
            mail.setSaveAsActivity(false);
            mensajes.add(mail);
            conCorreo.add(donacion);
        }

        if (!mensajes.isEmpty()) {
            actualizaciones.addAll(enviar(mensajes, conCorreo));
        }

        if (!actualizaciones.isEmpty()) {
            update as system actualizaciones;
        }
    }

    /**
     * @description Envía los mensajes y traduce cada resultado en la actualización de la donación.
     *              Una excepción (por ejemplo, límite diario de correos o entregabilidad desactivada)
     *              se registra como error en todas las donaciones del lote, sin propagarse.
     */
    private static List<Donacion__c> enviar(List<Messaging.SingleEmailMessage> mensajes, List<Donacion__c> donaciones) {
        List<Donacion__c> actualizaciones = new List<Donacion__c>();
        try {
            if (Test.isRunningTest() && simulacionEnvio == 'fallo') {
                throw new EnvioComprobanteException('Fallo de envío simulado en prueba.');
            }
            if (Test.isRunningTest() && simulacionEnvio == 'exito') {
                for (Donacion__c donacion : donaciones) {
                    actualizaciones.add(resultado(donacion.Id, true, null));
                }
                return actualizaciones;
            }
            List<Messaging.SendEmailResult> resultados = Messaging.sendEmail(mensajes, false);
            for (Integer i = 0; i < donaciones.size(); i++) {
                Messaging.SendEmailResult res = resultados[i];
                String error = null;
                if (!res.isSuccess() && !res.getErrors().isEmpty()) {
                    error = res.getErrors()[0].getMessage();
                }
                actualizaciones.add(resultado(donaciones[i].Id, res.isSuccess(), error));
            }
        } catch (Exception ex) {
            for (Donacion__c donacion : donaciones) {
                actualizaciones.add(resultado(donacion.Id, false, ex.getMessage()));
            }
        }
        return actualizaciones;
    }

    private static Donacion__c resultado(Id donacionId, Boolean exito, String error) {
        String motivo = exito ? null : (String.isBlank(error) ? 'No se pudo enviar el comprobante.' : error);
        return new Donacion__c(
            Id = donacionId,
            Comprobante_Enviado__c = exito,
            Error_Comprobante__c = motivo == null ? null : motivo.abbreviate(MAX_ERROR)
        );
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
     * @description Construye el cuerpo del comprobante en español, adaptado estrictamente
     *              a la modalidad de la donación (US-08 AC2/AC3, US-05 AC4, M2).
     * @param donacion Registro de Donacion__c con campos de campaña y donante.
     * @return Cuerpo del correo formateado.
     */
    @TestVisible
    private static String construirCuerpoCorreo(Donacion__c donacion) {
        String campanaNombre = (donacion.Campana__r != null && String.isNotBlank(donacion.Campana__r.Name))
            ? donacion.Campana__r.Name
            : 'Campaña Mexico Dreamin 2026';
        String fecha = donacion.Fecha_Pago__c != null
            ? donacion.Fecha_Pago__c.format('dd/MM/yyyy', ZONA_HORARIA)
            : System.now().format('dd/MM/yyyy', ZONA_HORARIA);
        String montoFormateado = '$' + (donacion.Monto__c != null ? String.valueOf(donacion.Monto__c.setScale(2)) : '0.00') + ' MXN';
        String folio = donacion.Name != null ? donacion.Name : '';
        String nombrePublico = String.isNotBlank(donacion.Nombre_Publico__c)
            ? donacion.Nombre_Publico__c
            : donacion.Nombre_Donante__c;

        String cuerpo = '';

        if (donacion.Modalidad__c == 'Anónima') {
            // US-03 AC2 y M2: prohibido exponer nombre, nombre público o RFC
            cuerpo = '¡Muchas gracias por tu generosidad!\n\n'
                   + 'Hemos recibido tu donación con éxito:\n'
                   + '- Folio de Donación: ' + folio + '\n'
                   + '- Campaña: ' + campanaNombre + '\n'
                   + '- Fecha de Pago: ' + fecha + '\n'
                   + '- Monto Aportado: ' + montoFormateado + '\n\n'
                   + 'Gracias por tu aportación anónima para apoyar a estudiantes en Mexico Dreamin 2026.\n'
                   + 'Tu donación impulsará el futuro de jóvenes talentos en el ecosistema Salesforce.';
        } else if (donacion.Modalidad__c == 'Con crédito') {
            String nombre = String.isNotBlank(donacion.Nombre_Donante__c) ? donacion.Nombre_Donante__c : 'Apreciable Donante';
            cuerpo = 'Estimado/a ' + nombre + ',\n\n'
                   + '¡Agradecemos enormemente tu valiosa contribución a la causa!\n\n'
                   + 'Detalle de tu donación confirmada:\n'
                   + '- Donante: ' + nombre + '\n'
                   + '- Folio de Donación: ' + folio + '\n'
                   + '- Campaña: ' + campanaNombre + '\n'
                   + '- Fecha de Pago: ' + fecha + '\n'
                   + '- Monto Aportado: ' + montoFormateado + '\n\n'
                   + 'Tu nombre público (' + nombrePublico + ') y el monto de tu aportación aparecerán en el muro público de reconocimiento de la campaña.\n\n'
                   + '¡Gracias por ser parte del sueño de Mexico Dreamin 2026!';
        } else if (donacion.Modalidad__c == 'Con factura') {
            // US-05 AC4 y US-08 AC3: datos fiscales y aviso explícito de que no es un CFDI
            String razonSocial = String.isNotBlank(donacion.Nombre_Donante__c) ? donacion.Nombre_Donante__c : 'Apreciable Donante';
            String rfc = String.isNotBlank(donacion.RFC__c) ? donacion.RFC__c : 'Pendiente';
            cuerpo = 'Estimado/a ' + razonSocial + ',\n\n'
                   + 'Confirmamos la recepción de tu donación y los datos fiscales que proporcionaste:\n\n'
                   + 'Detalle de la Donación:\n'
                   + '- Nombre / Razón Social: ' + razonSocial + '\n'
                   + '- RFC: ' + rfc + '\n'
                   + '- Folio de Donación: ' + folio + '\n'
                   + '- Campaña: ' + campanaNombre + '\n'
                   + '- Fecha de Pago: ' + fecha + '\n'
                   + '- Monto Aportado: ' + montoFormateado + '\n\n'
                   + 'Tu solicitud de factura quedó registrada con nuestro equipo de Tesorería.\n'
                   + 'Este comprobante no es un CFDI y no tiene validez fiscal.\n\n'
                   + 'Tu nombre público (' + nombrePublico + ') y el monto aparecerán en el muro público de donantes de la campaña.\n\n'
                   + 'Agradecemos tu valioso apoyo para los estudiantes de Mexico Dreamin 2026.';
        } else {
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
