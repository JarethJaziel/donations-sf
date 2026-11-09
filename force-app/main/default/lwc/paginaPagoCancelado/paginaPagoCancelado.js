import { LightningElement } from 'lightning-element';

export default class PaginaPagoCancelado extends LightningElement {
    handleBack() {
        window.location.href = '/';
    }
}
