import { LightningElement } from 'lightning-element';

export default class PaginaAgradecimiento extends LightningElement {
    handleBack() {
        // Redirige a la página de campañas (ruta raíz del portal)
        window.location.href = '/';
    }
}
