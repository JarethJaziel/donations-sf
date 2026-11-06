import { LightningElement, api, wire, track } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { CloseActionScreenEvent } from 'lightning/actions';
import { notifyRecordUpdateAvailable } from 'lightning/uiRecordApi';
import obtenerResumenDonacion from '@salesforce/apex/DonationAdminController.obtenerResumenDonacion';
import confirmarPagoManual from '@salesforce/apex/DonationAdminController.confirmarPagoManual';

export default class ConfirmarPagoAction extends LightningElement {
    @api recordId;
    @track donacion;
    @track cargando = true;
    @track procesando = false;
    @track error;

    @wire(obtenerResumenDonacion, { donacionId: '$recordId' })
    wiredDonacion({ error, data }) {
        this.cargando = false;
        if (data) {
            this.donacion = data;
            this.error = undefined;
        } else if (error) {
            this.error = this.extraerMensajeError(error);
            this.donacion = undefined;
        }
    }

    get yaPagada() {
        return this.donacion && this.donacion.estado === 'Pagada';
    }

    get botonConfirmarDeshabilitado() {
        return this.cargando || this.procesando || this.yaPagada || !this.donacion;
    }

    get nombreDonanteMostrado() {
        if (!this.donacion) {
            return '';
        }
        if (this.donacion.modalidad === 'Anónima') {
            return '(Donante Anónimo)';
        }
        return this.donacion.nombreDonante || '(Sin nombre)';
    }

    cerrarModal() {
        this.dispatchEvent(new CloseActionScreenEvent());
    }

    async ejecutarConfirmacion() {
        if (!this.recordId || this.yaPagada) {
            return;
        }

        this.procesando = true;
        this.cargando = true;

        try {
            const resultado = await confirmarPagoManual({ donacionId: this.recordId });

            this.dispatchEvent(
                new ShowToastEvent({
                    title: 'Pago Confirmado',
                    message: resultado.mensaje || 'La donación fue confirmada y el comprobante ha sido enviado.',
                    variant: 'success'
                })
            );

            await notifyRecordUpdateAvailable([{ recordId: this.recordId }]);
            this.cerrarModal();
        } catch (err) {
            const msg = this.extraerMensajeError(err);
            this.error = msg;
            this.dispatchEvent(
                new ShowToastEvent({
                    title: 'Error al confirmar pago',
                    message: msg,
                    variant: 'error',
                    mode: 'sticky'
                })
            );
        } finally {
            this.procesando = false;
            this.cargando = false;
        }
    }

    extraerMensajeError(err) {
        if (!err) {
            return 'Ha ocurrido un error inesperado.';
        }
        if (err.body && err.body.message) {
            return err.body.message;
        }
        if (err.message) {
            return err.message;
        }
        return JSON.stringify(err);
    }
}
