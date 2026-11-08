import { LightningElement, wire } from 'lwc';
import obtenerCampanasActivas from '@salesforce/apex/DonationPublicController.obtenerCampanasActivas';

const NBSP = String.fromCharCode(160); // espacio que el compilador de plantillas no elimina
const FORMATO_MXN = new Intl.NumberFormat('es-MX', { style: 'currency', currency: 'MXN' });
const FORMATO_FECHA = new Intl.DateTimeFormat('es-MX', { day: 'numeric', month: 'long', year: 'numeric', timeZone: 'UTC' });

function fechaLarga(isoFecha) {
    return isoFecha ? FORMATO_FECHA.format(new Date(`${isoFecha}T00:00:00Z`)) : '';
}

/**
 * Portal público de campañas (US-01, US-02, US-14).
 * Lista las campañas vigentes; al elegir una muestra su detalle, el formulario y el muro.
 * Si solo hay una campaña vigente la abre directamente (US-01 AC8).
 */
export default class PortalCampanasPublico extends LightningElement {
    campanas = [];
    seleccionadaId;
    cargando = true;
    error;

    @wire(obtenerCampanasActivas)
    recibirCampanas({ data, error }) {
        if (data) {
            this.campanas = data.map((c) => this.decorar(c));
            this.error = undefined;
            this.cargando = false;
            if (this.campanas.length === 1) {
                this.seleccionadaId = this.campanas[0].id;
            }
        } else if (error) {
            this.campanas = [];
            this.error = 'No pudimos cargar las campañas. Recarga la página para intentarlo de nuevo.';
            this.cargando = false;
        }
    }

    decorar(c) {
        const porcentaje = Number(c.porcentaje) || 0;
        return {
            ...c,
            barraEstilo: `width: ${Math.min(porcentaje, 100)}%`,
            porcentajeTexto: `${porcentaje}%`,
            recaudadoTexto: FORMATO_MXN.format(Number(c.recaudado) || 0),
            restoCifras: `${NBSP}de ${FORMATO_MXN.format(Number(c.meta) || 0)} · ${porcentaje}%`,
            restoCifrasDetalle: `${NBSP}recaudados de ${FORMATO_MXN.format(Number(c.meta) || 0)} · ${porcentaje}%`,
            cierraTexto: `Cierra el ${fechaLarga(c.fechaFin)}`,
            fechaLimiteTexto: `Fecha límite: ${fechaLarga(c.fechaFin)}`,
            cerrada: !c.elegibleParaDonar,
            textoBoton: c.elegibleParaDonar ? 'Donar' : 'Ver campaña',
            etiquetaBoton: `${c.elegibleParaDonar ? 'Donar a' : 'Ver'} ${c.nombre}`
        };
    }

    get seleccionada() {
        return this.campanas.find((c) => c.id === this.seleccionadaId);
    }

    get mostrarVacio() {
        return !this.cargando && !this.error && this.campanas.length === 0;
    }

    get mostrarLista() {
        return !this.cargando && !this.error && this.campanas.length > 0 && !this.seleccionada;
    }

    get puedeVolver() {
        return this.campanas.length > 1;
    }

    elegir(event) {
        this.seleccionadaId = event.currentTarget.dataset.id;
        this.subir();
    }

    volver() {
        this.seleccionadaId = undefined;
        this.subir();
    }

    subir() {
        // eslint-disable-next-line @lwc/lwc/no-async-operation
        requestAnimationFrame(() => window.scrollTo({ top: 0, behavior: 'smooth' }));
    }
}
