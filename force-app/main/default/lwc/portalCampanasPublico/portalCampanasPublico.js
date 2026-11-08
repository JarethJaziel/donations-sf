import { LightningElement, wire } from 'lwc';
import { loadStyle } from 'lightning/platformResourceLoader';
import FUENTES from '@salesforce/resourceUrl/md2026Fuentes';
import obtenerCampanasActivas from '@salesforce/apex/DonationPublicController.obtenerCampanasActivas';

const FORMATO_MXN = new Intl.NumberFormat('es-MX', { style: 'currency', currency: 'MXN' });
const FORMATO_MXN_CORTO = new Intl.NumberFormat('es-MX', { style: 'currency', currency: 'MXN', maximumFractionDigits: 0 });
const FORMATO_FECHA = new Intl.DateTimeFormat('es-MX', { day: 'numeric', month: 'long', year: 'numeric', timeZone: 'UTC' });
const FORMATO_MES = new Intl.DateTimeFormat('es-MX', { month: 'short', timeZone: 'UTC' });

// Mexico Dreamin 2026: Ciudad de México, 20 de noviembre de 2026
const EVENTO = new Date('2026-11-20T00:00:00-06:00');
const CARACTERES = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789 ';
const MENSAJES_TABLERO = [
    ['CDMX MEXICO DREAMIN', 'A TIEMPO'],
    ['20 NOV 2026', 'ABORDANDO'],
    ['SALE EN {d} DIAS', 'DONA YA']
];
const MENSAJES_CORTOS = {
    destinos: ['CDMX 20 NOV', 'MX DREAMIN 26'],
    cuenta: 'FALTAN {d} DIAS',
    estados: ['ABORDANDO', 'A TIEMPO', 'DONA YA']
};
const SEGUNDOS_POR_MENSAJE = 7;

function fechaLarga(isoFecha) {
    return isoFecha ? FORMATO_FECHA.format(new Date(`${isoFecha}T00:00:00Z`)) : '';
}

/** "17 NOV": fecha corta para las paletas del talón. */
function fechaCorta(isoFecha) {
    if (!isoFecha) {
        return '';
    }
    const fecha = new Date(`${isoFecha}T00:00:00Z`);
    const mes = FORMATO_MES.format(fecha).replace('.', '').toUpperCase().slice(0, 3);
    return `${fecha.getUTCDate()} ${mes}`;
}

function diasAlEvento() {
    return Math.max(0, Math.ceil((EVENTO.getTime() - Date.now()) / 86400000));
}

/** Convierte un texto en paletas (una por carácter) para pintarlas como tablero. */
function paletas(texto, prefijo) {
    return Array.from(texto).map((ch, i) => ({
        clave: `${prefijo}-${i}`,
        ch,
        clase: /[0-9A-ZÑ]/.test(ch) ? '' : 'sep'
    }));
}

function reducirMovimiento() {
    return window.matchMedia && window.matchMedia('(prefers-reduced-motion: reduce)').matches;
}

/**
 * Portal público de campañas (US-01, US-02, US-14).
 * Lista las campañas vigentes como boletos de salida bajo un tablero animado;
 * al elegir una muestra su detalle, el formulario y el muro.
 * Si solo hay una campaña vigente la abre directamente (US-01 AC8).
 */
export default class PortalCampanasPublico extends LightningElement {
    campanas = [];
    seleccionadaId;
    cargando = true;
    error;
    tableroAngosto = false;

    // Estado interno del tablero (DOM manual, no reactivo)
    filasNodo;
    celdasTablero = [];
    mensajeIndice = 0;
    temporizadores = new Set();
    intervaloTablero;
    anchoPrevio = 0;
    enfocarDetalle = false;
    alRedimensionar = () => {
        const ancho = window.innerWidth;
        if (Math.abs(ancho - this.anchoPrevio) > 40) {
            this.anchoPrevio = ancho;
            this.construirTablero(false);
        }
    };

    @wire(obtenerCampanasActivas)
    recibirCampanas({ data, error }) {
        if (data) {
            this.campanas = [...data]
                .sort(
                    (a, b) =>
                        Number(b.elegibleParaDonar) - Number(a.elegibleParaDonar) ||
                        (a.fechaFin || '').localeCompare(b.fechaFin || '') ||
                        (a.nombre || '').localeCompare(b.nombre || '')
                )
                .map((c, i) => this.decorar(c, i));
            this.error = undefined;
            this.cargando = false;
            if (this.campanas.length === 1) {
                this.seleccionadaId = this.campanas[0].id;
            }
        } else if (error) {
            this.campanas = [];
            this.error = 'Revisa tu conexión y recarga la página para intentarlo de nuevo.';
            this.cargando = false;
        }
    }

    decorar(c, indice) {
        const porcentaje = Number(c.porcentaje) || 0;
        const avance = Math.min(Math.max(porcentaje, 0), 100);
        const ajusteAutobus = avance < 6 ? 15 : avance > 94 ? -15 : 0;
        const meta = FORMATO_MXN.format(Number(c.meta) || 0);
        const recaudado = Number(c.recaudado) || 0;
        const cerrada = !c.elegibleParaDonar;
        return {
            ...c,
            cerrada,
            claseBoleto: cerrada ? 'boleto boleto--cerrado' : 'boleto',
            claseImagen: `boleto__imagen tono-${indice % 3}`,
            claseImagenPase: `pase__imagen tono-${indice % 3}`,
            porcentajeTexto: `${porcentaje}%`,
            avanceRedondeado: Math.round(avance),
            etiquetaRuta: `Avance ${porcentaje}%`,
            avanceEstilo: `width: ${avance}%`,
            autobusEstilo: `left: calc(${avance}% + ${ajusteAutobus}px)`,
            digitosRecaudado: paletas(FORMATO_MXN_CORTO.format(recaudado), `r-${c.id}`),
            restoCifras: `de ${meta} · ${porcentaje}%`,
            restoCifrasDetalle: `recaudados de ${meta} · ${porcentaje}%`,
            lectorCifras: `${FORMATO_MXN.format(recaudado)} recaudados de ${meta}`,
            digitosCierre: paletas(fechaCorta(c.fechaFin), `f-${c.id}`),
            cierreLargo: fechaLarga(c.fechaFin),
            fechaLimiteTexto: `Fecha límite: ${fechaLarga(c.fechaFin)}`,
            selloTexto: c.motivoCierre === 'Meta alcanzada' ? 'Cupo lleno' : 'Cerrada',
            claseBoton: cerrada ? 'boton boton--secundario' : 'boton boton--primario',
            textoBoton: cerrada ? 'Ver campaña' : 'Donar',
            etiquetaBoton: `${cerrada ? 'Ver campaña' : 'Donar'}: ${c.nombre}`
        };
    }

    // ---------- Estado derivado ----------

    get seleccionada() {
        return this.campanas.find((c) => c.id === this.seleccionadaId);
    }

    get vistaInicio() {
        return !this.seleccionada;
    }

    get mostrarVacio() {
        return !this.cargando && !this.error && this.campanas.length === 0;
    }

    get mostrarLista() {
        return !this.cargando && !this.error && this.campanas.length > 0;
    }

    get puedeVolver() {
        return this.campanas.length > 1;
    }

    get diasTexto() {
        return String(diasAlEvento());
    }

    get totalTexto() {
        if (this.cargando || this.error) {
            return '—';
        }
        return FORMATO_MXN.format(this.campanas.reduce((suma, c) => suma + (Number(c.recaudado) || 0), 0));
    }

    get claseCabezaEstado() {
        return this.tableroAngosto ? 'tablero__estado oculto' : 'tablero__estado';
    }

    // ---------- Ciclo de vida ----------

    connectedCallback() {
        loadStyle(this, `${FUENTES}/fonts.css`).catch(() => {
            // Sin las fuentes el portal usa las de respaldo; no es un error para el donante.
        });
        this.anchoPrevio = window.innerWidth;
        window.addEventListener('resize', this.alRedimensionar);
        // eslint-disable-next-line @lwc/lwc/no-async-operation
        this.intervaloTablero = setInterval(() => {
            if (!this.filasNodo || reducirMovimiento() || document.hidden) {
                return;
            }
            this.mensajeIndice = (this.mensajeIndice + 1) % MENSAJES_TABLERO.length;
            this.escribirTablero(false);
        }, SEGUNDOS_POR_MENSAJE * 1000);
    }

    disconnectedCallback() {
        window.removeEventListener('resize', this.alRedimensionar);
        clearInterval(this.intervaloTablero);
        this.cancelarVolteos();
        this.filasNodo = undefined;
    }

    renderedCallback() {
        const filas = this.template.querySelector('.tablero__filas');
        if (filas !== this.filasNodo) {
            this.filasNodo = filas || undefined;
            this.cancelarVolteos();
            if (filas) {
                this.construirTablero(true);
            }
        }
        if (this.enfocarDetalle) {
            const titulo = this.template.querySelector('.pase__nombre');
            if (titulo) {
                titulo.focus({ preventScroll: true });
                this.enfocarDetalle = false;
            }
        }
    }

    // ---------- Tablero de salidas (paletas que voltean) ----------

    medirTablero() {
        const interior = this.template.querySelector('.tablero__interior');
        const ancho = interior ? interior.clientWidth - 32 : 900;
        const tam = ancho > 900 ? 34 : ancho > 600 ? 28 : 22;
        const celda = tam * 0.78 + 3;
        return { total: Math.max(12, Math.floor(ancho / celda)), tam };
    }

    construirTablero(animar) {
        const filas = this.filasNodo;
        if (!filas) {
            return;
        }
        this.cancelarVolteos();
        filas.textContent = '';
        filas.classList.remove('tam-g', 'tam-m', 'tam-c');
        const { total, tam } = this.medirTablero();
        filas.classList.add(tam === 34 ? 'tam-g' : tam === 28 ? 'tam-m' : 'tam-c');
        const estadoAncho = total > 26 ? 10 : 0;
        this.tableroAngosto = !estadoAncho;
        this.celdasTablero = [];
        for (let f = 0; f < 3; f++) {
            const fila = document.createElement('div');
            fila.className = 'tablero__fila';
            const celdas = [];
            for (let i = 0; i < total; i++) {
                const paleta = document.createElement('span');
                const esEstado = estadoAncho ? i >= total - estadoAncho : f === 2;
                paleta.className = esEstado ? 'paleta paleta--estado' : 'paleta';
                paleta.textContent = ' ';
                fila.appendChild(paleta);
                celdas.push(paleta);
            }
            filas.appendChild(fila);
            this.celdasTablero.push({ celdas, estadoAncho });
        }
        if (animar && !reducirMovimiento()) {
            this.escribirTablero(true);
            return;
        }
        this.celdasTablero.forEach((fila, f) => {
            const texto = this.textoFila(f, fila.celdas.length, fila.estadoAncho);
            fila.celdas.forEach((celda, i) => {
                celda.textContent = texto[i] || ' ';
            });
        });
    }

    textoFila(f, total, estadoAncho) {
        const dias = String(diasAlEvento());
        if (!estadoAncho) {
            // Tablero angosto: destino/fecha, cuenta regresiva y estado, una fila cada uno
            const texto =
                f === 0
                    ? MENSAJES_CORTOS.destinos[this.mensajeIndice % MENSAJES_CORTOS.destinos.length]
                    : f === 1
                      ? MENSAJES_CORTOS.cuenta.replace('{d}', dias)
                      : MENSAJES_CORTOS.estados[this.mensajeIndice % MENSAJES_CORTOS.estados.length];
            return (f === 2 ? texto.padStart(total) : texto.padEnd(total)).slice(0, total);
        }
        const linea = MENSAJES_TABLERO[(f + this.mensajeIndice) % MENSAJES_TABLERO.length];
        const principal = linea[0].replace('{d}', dias);
        const izquierda = principal.padEnd(total - estadoAncho).slice(0, total - estadoAncho);
        return izquierda + linea[1].padStart(estadoAncho).slice(-estadoAncho);
    }

    escribirTablero(inicial) {
        this.celdasTablero.forEach((fila, f) => {
            const texto = this.textoFila(f, fila.celdas.length, fila.estadoAncho);
            fila.celdas.forEach((celda, i) => this.voltear(celda, texto[i] || ' ', (inicial ? i * 16 : i * 14) + f * 110));
        });
    }

    esperar(fn, ms) {
        // eslint-disable-next-line @lwc/lwc/no-async-operation
        const id = setTimeout(() => {
            this.temporizadores.delete(id);
            fn();
        }, ms);
        this.temporizadores.add(id);
    }

    cancelarVolteos() {
        this.temporizadores.forEach((id) => clearTimeout(id));
        this.temporizadores.clear();
    }

    voltear(celda, destino, retraso) {
        if (celda.textContent === destino) {
            return;
        }
        let pasos = 2 + Math.floor(Math.random() * 4);
        const paso = () => {
            celda.classList.remove('volteando');
            // Fuerza el reinicio de la animación antes de volver a aplicarla
            // eslint-disable-next-line no-unused-expressions
            celda.offsetWidth;
            celda.classList.add('volteando');
            this.esperar(() => {
                celda.textContent = pasos > 0 ? CARACTERES[Math.floor(Math.random() * (CARACTERES.length - 1))] : destino;
                pasos -= 1;
                if (pasos >= 0) {
                    this.esperar(paso, 80);
                }
            }, 70);
        };
        this.esperar(paso, retraso);
    }

    // ---------- Navegación ----------

    elegir(event) {
        this.seleccionadaId = event.currentTarget.dataset.id;
        this.enfocarDetalle = true;
        this.subir();
    }

    volver() {
        this.seleccionadaId = undefined;
        this.subir();
    }

    subir() {
        // eslint-disable-next-line @lwc/lwc/no-async-operation
        requestAnimationFrame(() => window.scrollTo({ top: 0, behavior: reducirMovimiento() ? 'auto' : 'smooth' }));
    }
}
