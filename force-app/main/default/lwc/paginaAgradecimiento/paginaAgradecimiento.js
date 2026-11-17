import { LightningElement } from 'lwc';
import { loadStyle } from 'lightning/platformResourceLoader';
import FUENTES from '@salesforce/resourceUrl/md2026Fuentes';
import basePath from '@salesforce/community/basePath';

/**
 * Página de confirmación y agradecimiento de donación (US-07 AC1–AC4, RF-D4).
 * Informa que la donación fue recibida y que el comprobante se enviará cuando se confirme el pago,
 * y muestra en qué ayuda una aportación con montos de referencia.
 * No consume Apex ni lee parámetros de la URL para cumplir con menor privilegio (M2).
 */
/**
 * Ejemplos de en qué se usa una aportación. Son montos de referencia fijos (prototipo):
 * la página no consulta la donación del visitante para no leer datos personales (M2).
 */
const USOS_APORTACION = [
    { clave: 'comidas', monto: '$250', texto: 'cubren las comidas de un estudiante durante un día del evento.', icono: 'comida' },
    { clave: 'transporte-local', monto: '$500', texto: 'pagan el transporte local en la Ciudad de México durante el evento.', icono: 'metro' },
    { clave: 'hospedaje', monto: '$1,500', texto: 'cubren una noche de hospedaje compartido cerca de la sede.', icono: 'cama' },
    { clave: 'viaje', monto: '$3,000', texto: 'pagan el boleto de autobús de ida y vuelta a la Ciudad de México.', icono: 'autobus' }
];

export default class PaginaAgradecimiento extends LightningElement {
    usos = USOS_APORTACION.map((u) => ({
        ...u,
        esComida: u.icono === 'comida',
        esMetro: u.icono === 'metro',
        esCama: u.icono === 'cama',
        esAutobus: u.icono === 'autobus'
    }));

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
