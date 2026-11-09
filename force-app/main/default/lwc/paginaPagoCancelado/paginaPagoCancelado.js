import { LightningElement } from 'lwc';
import { loadStyle } from 'lightning/platformResourceLoader';
import FUENTES from '@salesforce/resourceUrl/md2026Fuentes';
import basePath from '@salesforce/community/basePath';

/**
 * Página informativa de pago cancelado (US-07 AC5).
 * Aclara que no hubo cargos, que la donación no quedó pagada e indica cómo reintentar.
 * No consume Apex ni lee parámetros de la URL para cumplir con menor privilegio (M2).
 */
export default class PaginaPagoCancelado extends LightningElement {
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
