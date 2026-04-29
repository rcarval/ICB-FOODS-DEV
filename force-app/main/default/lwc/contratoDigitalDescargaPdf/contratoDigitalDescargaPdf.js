import { LightningElement, api } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import getUrlDescargaPdf from '@salesforce/apex/ICB_ContratoDigitalDescargaController.getUrlDescargaPdf';

/**
 * Quick Action que obtiene la URL prefirmada del PDF firmado y la abre en nueva pestaña.
 * Experiencia nativa del navegador (visor PDF o descarga según configuración).
 */
export default class ContratoDigitalDescargaPdf extends LightningElement {
    @api recordId;

    isLoading = false;

    /**
     * Invocado por la plataforma cuando el usuario selecciona la Quick Action.
     * No ejecutar en connectedCallback para evitar que corra al cargar la página.
     */
    @api
    invoke() {
        this.isLoading = true;
        this.ejecutarDescarga();
    }

    ejecutarDescarga() {
        if (!this.recordId) {
            this.mostrarError('No hay registro asociado.');
            this.cerrar();
            return;
        }

        if (this._yaIniciado) return;
        this._yaIniciado = true;

        getUrlDescargaPdf({ recordId: this.recordId })
            .then((result) => {
                if (result.error) {
                    this.mostrarError(result.error);
                } else if (result.url) {
                    window.open(result.url, '_blank', 'noopener,noreferrer');
                    this.mostrarExito();
                } else {
                    this.mostrarError('No se obtuvo URL de descarga.');
                }
            })
            .catch((error) => {
                const msg = error.body?.message || error.message || 'Error desconocido';
                this.mostrarError(msg);
            })
            .finally(() => {
                this.isLoading = false;
                this.cerrar();
            });
    }

    mostrarError(mensaje) {
        this.dispatchEvent(
            new ShowToastEvent({
                title: 'Error al obtener PDF',
                message: mensaje,
                variant: 'error',
            })
        );
    }

    mostrarExito() {
        this.dispatchEvent(
            new ShowToastEvent({
                title: 'PDF abierto',
                message: 'El documento se abrió en una nueva pestaña.',
                variant: 'success',
            })
        );
    }

    cerrar() {
        this.dispatchEvent(new CustomEvent('close'));
    }
}