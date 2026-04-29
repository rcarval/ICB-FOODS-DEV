import { LightningElement, wire, track, api } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import fetchData from '@salesforce/apex/MaestraPreciosController.fetchPricebookEntries';
import getTotalNumberOfRows from '@salesforce/apex/MaestraPreciosController.getTotalNumberOfPricebookEntries';
import { calculateMargen, calculateKilo } from 'c/utils';

export default class LookupDatatable extends LightningElement {
    @track data = []; // Registros que trae el metodo fetchData
    @track selectedData = []; // Registros seleccionados por el usuario
    @track queryOffset = 0;
    @track queryLimit = 10;
    @track currentCount = 0;
    @track showSpinner = true;
    @api selectedAccountId;
    totalNumberOfRows = 0;
    disableLoadMore = false;
    searchTerm = '';
    columns;
    delayTimeout; // Usado para debouncing
    loadMoreStatus;
    timerId; // Temporizador de debounce
    shouldStoreSelectedData = false; // Flag para trackear el momento en que se deben guardar los datos seleccionados

    connectedCallback() {
        this.columns = this.setColumns();
        
        // Validar que selectedAccountId no sea null antes de hacer llamadas a Apex
        if (this.selectedAccountId == null || this.selectedAccountId === undefined) {
            console.error('No se puede cargar productos: selectedAccountId es null o undefined');
            this.showSpinner = false;
            this.showError('No se puede cargar productos: La cotización no tiene un cliente asociado. Por favor, asocia un cliente a la cotización primero.');
            return;
        }
        
        getTotalNumberOfRows({accountId: this.selectedAccountId, searchTerm: this.searchTerm})
        .then(result => {
            this.totalNumberOfRows = result;
            if (this.selectedAccountId != null) {
                this.fetchRecords()
                .then(() => {
                    this.showSpinner = false;
                    if (this.totalNumberOfRows > (this.currentCount + 10)) {
                        this.currentCount = this.currentCount + 10;
                    } else {
                        this.currentCount = this.totalRecordCount;
                    }
                });
            }
        })
        .catch(error => {
            console.error('Error en getTotalNumberOfRows:', error);
            this.showSpinner = false;
            this.showError(error.body?.message || 'Error al cargar el número total de productos');
        });
    }

    // Función para formatear números con punto para miles y coma para decimales
    formatNumber(value, decimals = 2) {
        if (value == null || value === '' || isNaN(value)) {
            return '';
        }
        const num = parseFloat(value);
        if (isNaN(num)) {
            return '';
        }
        // Separar parte entera y decimal
        const parts = num.toFixed(decimals).split('.');
        const integerPart = parts[0];
        const decimalPart = parts[1];
        
        // Agregar puntos como separadores de miles
        const formattedInteger = integerPart.replace(/\B(?=(\d{3})+(?!\d))/g, '.');
        
        // Retornar con coma como separador decimal
        return decimalPart ? `${formattedInteger},${decimalPart}` : formattedInteger;
    }

    setColumns() {
        return [
            { label: 'SKU', fieldName: 'sku', type: 'text' },
            { label: 'UMV', fieldName: 'umv', type: 'text' },
            { label: 'Descripción', fieldName: 'descripcion', type: 'text' },
            { label: 'Lista de Precio', fieldName: 'listaPrecioFormatted', type: 'text', cellAttributes: { alignment: 'right'} },
            { label: 'Descuento %', fieldName: 'descuentoFormatted', type: 'text', cellAttributes: { alignment: 'right'} },
            { label: 'Precio Cliente Neto', fieldName: 'precioClienteNetoFormatted', type: 'text', cellAttributes: { alignment: 'right'} },
            { label: 'Rappel', fieldName: 'rappelFormatted', type: 'text', cellAttributes: { alignment: 'right'} },
            { label: '%MG', fieldName: 'margenFormatted', type: 'text', cellAttributes: { alignment: 'right'} },
            { label: 'MG Contribución x Kilo', fieldName: 'margenContribucionKiloFormatted', type: 'text', cellAttributes: { alignment: 'right'} },
        ];
    }

    handleSearch(event) {
        this.searchTerm = event.target.value;

        // Resetear valores al inicio de la búsqueda
        this.showSpinner = true;
        this.data = [];
        this.queryOffset = 0;
        this.queryLimit = 10;
        this.currentCount = 0;
        this.totalNumberOfRows = 0;
        this.disableLoadMore = false;

        // Usar debounce para retrasar la búsqueda
        this.debounce(() => {
            getTotalNumberOfRows({
                accountId: this.selectedAccountId,
                searchTerm: this.searchTerm
            })
            .then(result => {
                this.totalNumberOfRows = result;

                if (this.selectedAccountId != null) {
                    this.fetchRecords()
                    .then(() => {
                        this.showSpinner = false;
                        if (this.totalNumberOfRows > (this.currentCount + this.queryLimit)) {
                            this.currentCount += this.queryLimit;
                        } else {
                            this.currentCount = this.totalNumberOfRows;
                        }
                    });
                }
            })
            .catch(error => {
                console.error('Error en getTotalNumberOfRows:', error);
            });
        }, 800); // Ajustar delay según sea necesario
    }

    debounce(fn, delay) {
        clearTimeout(this.timerId);
        this.timerId = setTimeout(fn, delay);
    }

    handleOnLoadMore(event) {
        if (this.disableLoadMore) {
            return;
        }
        const { target } = event
        target.isLoading = true;

        
        if (this.totalNumberOfRows > this.queryOffset) {
            this.queryOffset = this.queryOffset + 10;
            this.fetchRecords()
                .then(() => {
                    target.isLoading = false;
                    if (this.totalNumberOfRows > (this.currentCount + 10)) {
                        this.currentCount = this.currentCount + 10;
                    } else {
                        this.currentCount = this.totalRecordCount;
                    }
                });
        } else {
            this.disableLoadMore = true;
            target.isLoading = false;
            //this.disableLoadMore = true;
            //this.loadMoreStatus = 'No more to load.';
            //this.showToast('Success', 'Success', 'All Account Records are Loaded!', 'success', 'dismissible');
            console.log('all records loaded');
        }

        console.log('Called from Infinite Table Handle More ' + this.queryOffset);
    }

    fetchRecords() {
        return fetchData({
            accountId: this.selectedAccountId,
            queryLimit: this.queryLimit,
            queryOffset: this.queryOffset,
            searchTerm: this.searchTerm
        })
        .then(result => {
            let newRecords = [...this.data, ...result];  
            //this.data = newRecords;  

            this.data = newRecords.map(item => ({ ...item })); // Esta es la lista que vamos a mutar
            this.data.forEach(item => {
                item.descuento = 0;
                item.precioClienteNeto = item.listaPrecio;
                item.margen = calculateMargen(item);
                item.margenContribucionKilo = calculateKilo(item);
                
                // Aplicar formato a los números
                item.listaPrecioFormatted = this.formatNumber(item.listaPrecio, 2);
                item.descuentoFormatted = this.formatNumber(item.descuento, 2);
                item.precioClienteNetoFormatted = this.formatNumber(item.precioClienteNeto, 2);
                if (item.rappel != null) {
                    item.rappelFormatted = this.formatNumber(item.rappel, 2);
                } else {
                    item.rappelFormatted = '';
                }
                // Formatear margen (puede ser número o "SIN COSTO")
                if (item.margen && item.margen !== 'SIN COSTO') {
                    item.margenFormatted = this.formatNumber(item.margen, 2);
                } else {
                    item.margenFormatted = item.margen || '';
                }
                item.margenContribucionKiloFormatted = this.formatNumber(item.margenContribucionKilo, 0);
            });
        })
        .catch(error => {  
            console.log(error);
            //this.showToast('Error', 'Error', 'Error getting records from Server', 'error', 'sticky');
        });
    }

    handleSelectedRow(event) {
        // event.detail.selectedRows contiene TODAS las filas actualmente seleccionadas
        // No solo las nuevas, sino todas las que están seleccionadas en este momento
        // Por lo tanto, debemos reemplazar selectedData, no agregar a él
        const selectedRows = event.detail.selectedRows || [];
        
        // Convertir a objetos planos para evitar problemas con Proxies
        const plainSelectedData = selectedRows.map(item => {
            const plainItem = {};
            for (const key in item) {
                if (item.hasOwnProperty && item.hasOwnProperty(key)) {
                    plainItem[key] = item[key];
                } else {
                    // Si no tiene hasOwnProperty, intentar acceder directamente
                    try {
                        plainItem[key] = item[key];
                    } catch (e) {
                        // Ignorar propiedades que no se pueden acceder
                    }
                }
            }
            return plainItem;
        });

        // Reemplazar selectedData con la nueva selección (no acumular)
        this.selectedData = plainSelectedData;

        // Disparar evento custom para avisar al padre que se actualizaron los datos
        const recordUpdateEvent = new CustomEvent('recorddatachange', {
            detail: { recordData: this.selectedData.map(item => ({ ...item })) }
        });
        this.dispatchEvent(recordUpdateEvent);
    }

    showError(message) {
        const event = new ShowToastEvent({
            title: 'Error',
            message: message,
            variant: 'error',
            mode: 'sticky'
        });
        this.dispatchEvent(event);
    }
}