import { LightningElement } from 'lwc';
import { loadStyle } from 'lightning/platformResourceLoader';
import FUENTES from '@salesforce/resourceUrl/md2026Fuentes';
import basePath from '@salesforce/community/basePath';

/**
 * Página de confirmación y agradecimiento de donación (US-07 AC1–AC4, RF-D4).
 * Informa que la donación fue recibida y que el comprobante se enviará cuando se confirme el pago.
 * No consume Apex ni lee parámetros de la URL para cumplir con menor privilegio (M2).
 */
export default class PaginaAgradecimiento extends LightningElement {
    get urlInicio() {
        return basePath ? `${basePath}/` : './';
    }

    connectedCallback() {
        loadStyle(this, `${FUENTES}/fonts.css`).catch(() => {
            // Si la fuente externa no carga, el tema provee fuentes del sistema de respaldo
        });
    }

    handleBack(event) {
        event.preventDefault();
        window.location.href = this.urlInicio;
    }
}
