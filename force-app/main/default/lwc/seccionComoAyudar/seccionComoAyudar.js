import { LightningElement } from 'lwc';

/**
 * Sección "¿Cómo puedes ayudar?" del inicio del portal (US-23).
 * Explica el programa, qué cubre una donación y los pasos para donar, con ilustraciones
 * en SVG dentro del componente (no se cargan imágenes de terceros). No consulta datos.
 * Al pulsar el botón avisa al portal con el evento "vercampanas" para llevar al listado.
 */
export default class SeccionComoAyudar extends LightningElement {
    verCampanas() {
        this.dispatchEvent(new CustomEvent('vercampanas'));
    }
}
