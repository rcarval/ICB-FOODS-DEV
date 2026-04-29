import { LightningElement, api, wire, track } from 'lwc';
import { getRecord, updateRecord, getFieldValue } from 'lightning/uiRecordApi';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { refreshApex } from '@salesforce/apex';
import ESTADO_FIELD from '@salesforce/schema/Negocio_Gastronomico__c.Estado__c';
import ID_FIELD from '@salesforce/schema/Negocio_Gastronomico__c.Id';

const FIELDS = [ESTADO_FIELD, ID_FIELD];

export default class ConfirmarEstadoCongelado extends LightningElement {
    @api recordId;
    @track estadoAnterior;
    @track estadoActual;
    @track mostrarModal = false;
    @track isLoading = false;
    @track cambioDetectado = false;

    // Wire para observar cambios en el registro
    wiredRecordResult;

    @wire(getRecord, { recordId: '$recordId', fields: FIELDS })
    wiredRecord({ error, data }) {
        this.wiredRecordResult = { error, data };
        if (data) {
            const nuevoEstado = getFieldValue(data, ESTADO_FIELD);
            
            // Primera carga: inicializar valores
            if (this.estadoActual === undefined) {
                this.estadoActual = nuevoEstado;
                this.estadoAnterior = nuevoEstado;
                return;
            }
            
            // Solo procesar si hay un cambio real y no estamos mostrando el modal
            if (this.estadoActual !== nuevoEstado && !this.mostrarModal) {
                // Si el nuevo estado es "Congelado", mostrar modal de confirmación
                if (nuevoEstado === 'Congelado') {
                    // Guardar el estado anterior antes de mostrar el modal
                    // El estado anterior es el estado actual antes del cambio
                    this.estadoAnterior = this.estadoActual;
                    this.estadoActual = nuevoEstado;
                    this.cambioDetectado = true;
                    this.mostrarModal = true;
                } else {
                    // Si el estado cambió a algo diferente a "Congelado", actualizar valores normalmente
                    this.estadoAnterior = this.estadoActual;
                    this.estadoActual = nuevoEstado;
                    this.cambioDetectado = false;
                }
            }
        } else if (error) {
            console.error('Error al obtener el registro:', error);
            this.showToast('Error', 'Error al obtener información del registro', 'error');
        }
    }

    // Método para confirmar el cambio a "Congelado"
    handleConfirmar() {
        this.mostrarModal = false;
        this.cambioDetectado = false;
        
        // Actualizar estadoAnterior a "Congelado" para que cuando cambie a otro estado,
        // el wire pueda detectar correctamente los cambios futuros
        this.estadoAnterior = this.estadoActual;
        
        this.showToast(
            'Estado Actualizado', 
            'El estado ha sido cambiado a "Congelado". Este cambio no se puede revertir si la cuenta ya fue creada.', 
            'warning'
        );
        
        // Refrescar el registro para sincronizar y permitir detección de cambios futuros
        refreshApex(this.wiredRecordResult);
    }

    // Método para cancelar y revertir el estado
    handleCancelar() {
        this.isLoading = true;
        this.mostrarModal = false;

        // Revertir el estado al valor anterior
        const fields = {};
        fields[ID_FIELD.fieldApiName] = this.recordId;
        fields[ESTADO_FIELD.fieldApiName] = this.estadoAnterior;

        const recordInput = { fields };

        updateRecord(recordInput)
            .then(() => {
                this.estadoActual = this.estadoAnterior;
                this.cambioDetectado = false;
                this.isLoading = false;
                
                this.showToast(
                    'Cambio Cancelado', 
                    'El estado se ha revertido a "' + this.estadoAnterior + '".', 
                    'success'
                );

                // Refrescar el registro para sincronizar la UI
                return refreshApex(this.wiredRecordResult);
            })
            .catch((error) => {
                console.error('Error al revertir el estado:', error);
                this.isLoading = false;
                this.showToast(
                    'Error', 
                    'Error al revertir el estado: ' + (error.body?.message || error.message), 
                    'error'
                );
            });
    }

    // Método para cerrar el modal si se hace clic fuera
    handleCloseModal() {
        // Si se cierra sin confirmar, tratarlo como cancelación
        this.handleCancelar();
    }

    // Método helper para mostrar toasts
    showToast(title, message, variant) {
        const evt = new ShowToastEvent({
            title: title,
            message: message,
            variant: variant,
        });
        this.dispatchEvent(evt);
    }
}