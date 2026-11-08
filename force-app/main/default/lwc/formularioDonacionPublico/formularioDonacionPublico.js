import { LightningElement, api } from 'lwc';
import iniciarDonacion from '@salesforce/apex/DonationPublicController.iniciarDonacion';

const MONTOS_SUGERIDOS = [100, 250, 500, 1000, 2000, 5000, 10000, 20000];
const MONTO_MINIMO = 10;
const MONTO_CONFIRMACION = 1000;
const PATRON_MONTO = /^\d+(\.\d{1,2})?$/;
const PATRON_CORREO = /^[^@\s]+@[^@\s]+\.[^@\s]+$/;
const PATRON_RFC = /^[A-Z&Ñ]{3,4}(\d{2})(\d{2})(\d{2})[A-Z0-9]{3}$/;
const FORMATO_MXN = new Intl.NumberFormat('es-MX', { style: 'currency', currency: 'MXN' });

function fechaExiste(anio, mes, dia) {
    if (mes < 1 || mes > 12 || dia < 1) {
        return false;
    }
    return dia <= new Date(anio, mes, 0).getDate();
}

/** Misma regla que RfcValidator en Apex: patrón del SAT y fecha AAMMDD existente. */
function rfcValido(valor) {
    const coincidencia = PATRON_RFC.exec(valor || '');
    if (!coincidencia) {
        return false;
    }
    const [anio, mes, dia] = coincidencia.slice(1).map(Number);
    return fechaExiste(1900 + anio, mes, dia) || fechaExiste(2000 + anio, mes, dia);
}

/**
 * Formulario de donación (US-02, US-03, US-04, US-05, US-06).
 * Valida en vivo, pide confirmación desde $1,000 y redirige a Stripe Checkout.
 * No guarda datos del donante en el navegador ni en la URL.
 */
export default class FormularioDonacionPublico extends LightningElement {
    @api campana;

    modalidad = 'Anónima';
    montoTexto = '';
    correo = '';
    nombre = '';
    nombrePublico = '';
    rfc = '';
    intentoEnviar = false;
    tocados = {};
    confirmando = false;
    enviando = false;
    errorServidor;
    dialogoEnfocado = false;

    opcionesModalidad = [
        { label: 'Anónima: mi nombre no aparece en ningún lado', value: 'Anónima' },
        { label: 'Con reconocimiento: mi nombre aparece en el muro', value: 'Con crédito' },
        { label: 'Con factura: necesito factura (también apareces en el muro)', value: 'Con factura' }
    ];

    // ---------- Estado derivado ----------

    get aceptaDonaciones() {
        return this.campana && this.campana.elegibleParaDonar;
    }

    get montos() {
        const actual = this.montoNumero;
        return MONTOS_SUGERIDOS.map((m) => ({
            valor: m,
            texto: FORMATO_MXN.format(m).replace('.00', ''),
            clase: m === actual ? 'monto seleccionado' : 'monto',
            presionado: m === actual ? 'true' : 'false'
        }));
    }

    get montoLimpio() {
        return (this.montoTexto || '').replace(/[\s,$]/g, '');
    }

    get montoNumero() {
        return PATRON_MONTO.test(this.montoLimpio) ? Number(this.montoLimpio) : null;
    }

    get montoFormateado() {
        return this.montoNumero === null ? '' : FORMATO_MXN.format(this.montoNumero);
    }

    get esAnonima() {
        return this.modalidad === 'Anónima';
    }

    get esFactura() {
        return this.modalidad === 'Con factura';
    }

    get etiquetaNombre() {
        return this.esFactura ? 'Nombre o razón social' : 'Nombre';
    }

    get etiquetaBoton() {
        if (this.enviando) {
            return 'Abriendo el pago seguro...';
        }
        return this.montoNumero === null ? 'Continuar al pago' : `Donar ${this.montoFormateado}`;
    }

    // ---------- Validación (mismas reglas que DonationPublicController) ----------

    get errorMonto() {
        if (!this.montoLimpio) {
            return 'Elige o escribe un monto.';
        }
        if (!PATRON_MONTO.test(this.montoLimpio)) {
            return 'Escribe solo números, con máximo dos decimales.';
        }
        if (this.montoNumero < MONTO_MINIMO) {
            return 'El monto mínimo es $10.00 MXN.';
        }
        return null;
    }

    get errorCorreo() {
        const valor = this.correo.trim();
        if (!valor) {
            return 'Escribe tu correo para enviarte el comprobante.';
        }
        return valor.length > 80 || !PATRON_CORREO.test(valor) ? 'Escribe un correo electrónico válido.' : null;
    }

    get errorNombre() {
        if (this.esAnonima) {
            return null;
        }
        return this.nombre.trim() ? null : `Escribe tu ${this.esFactura ? 'nombre o razón social' : 'nombre'}.`;
    }

    get errorRfc() {
        if (!this.esFactura) {
            return null;
        }
        const valor = this.rfc.trim().toUpperCase();
        if (!valor) {
            return 'Escribe tu RFC.';
        }
        return rfcValido(valor) ? null : 'RFC inválido: deben ser 12 o 13 caracteres con una fecha que exista.';
    }

    mostrar(campo, error) {
        return (this.intentoEnviar || this.tocados[campo]) && error ? error : null;
    }

    get mensajeMonto() {
        return this.mostrar('monto', this.errorMonto);
    }

    get mensajeCorreo() {
        return this.mostrar('correo', this.errorCorreo);
    }

    get mensajeNombre() {
        return this.mostrar('nombre', this.errorNombre);
    }

    get mensajeRfc() {
        return this.mostrar('rfc', this.errorRfc);
    }

    get invalidoMonto() {
        return this.mensajeMonto ? 'true' : null;
    }

    get invalidoCorreo() {
        return this.mensajeCorreo ? 'true' : null;
    }

    get invalidoNombre() {
        return this.mensajeNombre ? 'true' : null;
    }

    get invalidoRfc() {
        return this.mensajeRfc ? 'true' : null;
    }

    get formularioValido() {
        return !this.errorMonto && !this.errorCorreo && !this.errorNombre && !this.errorRfc;
    }

    // ---------- Eventos ----------

    elegirMonto(event) {
        this.montoTexto = event.currentTarget.dataset.valor;
        this.tocados = { ...this.tocados, monto: true };
    }

    cambiarCampo(event) {
        const campo = event.target.dataset.campo;
        this[campo] = event.target.value || '';
        if (campo === 'rfc') {
            this.rfc = this.rfc.toUpperCase();
        }
        this.errorServidor = undefined;
    }

    salirCampo(event) {
        this.tocados = { ...this.tocados, [event.target.dataset.campo === 'montoTexto' ? 'monto' : event.target.dataset.campo]: true };
    }

    cambiarModalidad(event) {
        this.modalidad = event.detail.value;
        if (this.esAnonima) {
            // US-03 AC5: al cambiar a anónima se descartan los datos de identidad
            this.nombre = '';
            this.nombrePublico = '';
            this.rfc = '';
        } else if (!this.esFactura) {
            this.rfc = '';
        }
    }

    continuar(event) {
        event.preventDefault();
        this.intentoEnviar = true;
        this.errorServidor = undefined;
        if (!this.formularioValido || this.enviando) {
            const primerError = this.template.querySelector('.error');
            if (primerError) {
                primerError.scrollIntoView({ behavior: 'smooth', block: 'center' });
            }
            return;
        }
        if (this.montoNumero >= MONTO_CONFIRMACION) {
            // US-02 AC4: confirmación con el monto exacto
            this.confirmando = true;
            return;
        }
        this.enviar();
    }

    corregirMonto() {
        this.confirmando = false;
        const campo = this.template.querySelector('[data-campo="montoTexto"]');
        if (campo) {
            campo.focus();
        }
    }

    confirmarMonto() {
        this.confirmando = false;
        this.enviar();
    }

    manejarTeclaDialogo(event) {
        if (event.key === 'Escape') {
            this.corregirMonto();
        }
    }

    async enviar() {
        this.enviando = true;
        try {
            const url = await iniciarDonacion({
                solicitud: {
                    campanaId: this.campana.id,
                    modalidad: this.modalidad,
                    monto: this.montoNumero,
                    correo: this.correo.trim(),
                    nombre: this.esAnonima ? null : this.nombre.trim(),
                    nombrePublico: this.esAnonima ? null : this.nombrePublico.trim() || null,
                    rfc: this.esFactura ? this.rfc.trim().toUpperCase() : null
                }
            });
            window.location.assign(url);
        } catch (e) {
            this.enviando = false;
            this.errorServidor =
                (e && e.body && e.body.message) || 'No pudimos iniciar tu donación. Intenta de nuevo en unos minutos.';
        }
    }

    renderedCallback() {
        if (this.confirmando) {
            const boton = this.template.querySelector('.dialogo .boton-primario');
            if (boton && this.template.activeElement !== boton && !this.dialogoEnfocado) {
                boton.focus();
                this.dialogoEnfocado = true;
            }
        } else {
            this.dialogoEnfocado = false;
        }
    }
}
