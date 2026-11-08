import { LightningElement, api, wire } from 'lwc';
import obtenerMuroDonantes from '@salesforce/apex/DonationPublicController.obtenerMuroDonantes';

const MINIMO_PARA_DESPLAZAR = 6;
const SEGUNDOS_POR_DONANTE = 2.5;

/**
 * Muro de reconocimiento público (US-04).
 * Muestra solo nombre público y monto de donaciones pagadas con crédito o factura.
 * Con muchos donantes se desplaza solo y se pausa al pasar el mouse (US-04 AC5).
 */
export default class MuroDonantesPublico extends LightningElement {
    @api campanaId;

    donantes = [];
    cargando = true;
    error;

    @wire(obtenerMuroDonantes, { campanaId: '$campanaId' })
    recibirDonantes({ data, error }) {
        if (data) {
            this.donantes = data.map((d, i) => ({ ...d, clave: `d-${i}`, claveCopia: `c-${i}` }));
            this.error = undefined;
            this.cargando = false;
        } else if (error) {
            this.donantes = [];
            this.error = 'No pudimos cargar el muro de donantes.';
            this.cargando = false;
        }
    }

    get hayDonantes() {
        return this.donantes.length > 0;
    }

    get sinDonantes() {
        return !this.cargando && !this.error && this.donantes.length === 0;
    }

    get desplazar() {
        return this.donantes.length >= MINIMO_PARA_DESPLAZAR;
    }

    get clasePista() {
        return this.desplazar ? 'pista animada' : 'pista';
    }

    get estiloPista() {
        return this.desplazar ? `animation-duration: ${this.donantes.length * SEGUNDOS_POR_DONANTE}s` : '';
    }

    get totalTexto() {
        return this.donantes.length === 1 ? '1 donante' : `${this.donantes.length} donantes`;
    }
}
