import { LightningElement, api, track, wire } from 'lwc';
import { helper } from './panelSeteoQuoteHelper';
import obtenerQuoteLineItems from '@salesforce/apex/MaestraPreciosController.obtenerQuoteLineItems';
import actualizarQuoteLineItems from '@salesforce/apex/MaestraPreciosController.actualizarQuoteLineItems';
import obtenerInfoQuote from '@salesforce/apex/MaestraPreciosController.obtenerInfoQuote';

console.log('🚀 panelSeteoQuote.js - ARCHIVO CARGADO');

export default class PanelSeteoQuote extends LightningElement {
    _recordId;
    @track productData = [];
    @track productDataDraft = [];
    @track draftValues = [];
    @track selectedProducts = [];
    showSpinner = true;
    showModal = false;
    columns = [];
    encabezado = '';
    quoteName = '';
    accountName = '';
    accountId = '';
    isDataLoaded = false;

    // Getter para el contador de items
    get itemCount() {
        return this.productDataDraft ? this.productDataDraft.length : 0;
    }

    // Este método se llama cuando el recordId cambia (importante para Quick Actions)
    @api
    get recordId() {
        return this._recordId;
    }
    
    set recordId(value) {
        console.log('🟢 recordId setter llamado con valor:', value);
        this._recordId = value;
        
        // Si el recordId llega después del connectedCallback y no hemos cargado datos
        if (value && !this.isDataLoaded && this.columns.length > 0) {
            console.log('✅ recordId disponible en setter, cargando datos...');
            setTimeout(() => {
                this.cargarDatosQuote();
            }, 100);
        }
    }

    connectedCallback() {
        console.log('🔵 panelSeteoQuote - connectedCallback INICIO');
        console.log('🔵 recordId en connectedCallback:', this.recordId);
        console.log('🔵 Tipo de recordId:', typeof this.recordId);
        console.log('🔵 recordId es null?', this.recordId === null);
        console.log('🔵 recordId es undefined?', this.recordId === undefined);
        
        this.encabezado = helper.generarEncabezado();
        this.columns = helper.initializeColumns();
        console.log('🔵 Columnas inicializadas:', this.columns.length);
        
        if (this.recordId) {
            console.log('✅ recordId disponible, cargando datos...');
            this.cargarDatosQuote();
        } else {
            console.warn('⚠️ recordId NO disponible en connectedCallback');
            console.warn('⚠️ Esperando a que el recordId llegue vía setter...');
            // El recordId puede llegar después en Quick Actions
            this.showSpinner = true;
        }
        console.log('🔵 connectedCallback FIN');
    }

    renderedCallback() {
        console.log('🟣 renderedCallback ejecutado');
        console.log('🟣 recordId actual:', this.recordId);
        console.log('🟣 isDataLoaded:', this.isDataLoaded);
        console.log('🟣 showSpinner:', this.showSpinner);
    }

    cargarDatosQuote() {
        console.log('🔵 cargarDatosQuote INICIO');
        console.log('🔵 recordId a usar:', this.recordId);
        
        if (!this.recordId) {
            console.error('❌ ERROR: No hay recordId disponible para cargar datos');
            this.showSpinner = false;
            helper.showToast('error', 'No se pudo obtener el ID de la Quote', 'Error');
            return;
        }
        
        this.showSpinner = true;
        
        // Primero obtener información de la Quote
        console.log('🔵 Llamando a obtenerInfoQuote con quoteId:', this.recordId);
        obtenerInfoQuote({ quoteId: this.recordId })
            .then((result) => {
                console.log('✅ obtenerInfoQuote exitoso:', result);
                this.quoteName = result.quoteName;
                this.accountName = result.accountName;
                this.accountId = result.accountId;
                
                // Luego obtener los QuoteLineItems
                console.log('🔵 Llamando a obtenerQuoteLineItems con quoteId:', this.recordId);
                return obtenerQuoteLineItems({ quoteId: this.recordId });
            })
            .then((result) => {
                console.log('✅ obtenerQuoteLineItems exitoso. Items recibidos:', result ? result.length : 0);
                console.log('📦 Datos de items:', result);
                
                this.productData = result;
                if (this.productData) {
                    this.productDataDraft = this.productData.map(item => ({ ...item }));
                    console.log('🔵 Procesando items...');
                    this.productDataDraft.forEach(item => {
                        if (item.descuento == null || item.descuento == undefined) {
                            item.descuento = 0;
                            item.precioClienteNeto = item.listaPrecio;
                            item.margen = helper.calculateMargen(item);
                            item.margenContribucionKilo = helper.calculateKilo(item);
                        }
                    });
                    console.log('✅ Items procesados:', this.productDataDraft.length);
                }
                
                this.isDataLoaded = true;
                this.showSpinner = false;
                console.log('✅ cargarDatosQuote COMPLETADO');
            })
            .catch((error) => {
                console.error('❌ ERROR en cargarDatosQuote:', error);
                console.error('❌ Error completo:', JSON.stringify(error));
                console.error('❌ Error body:', error.body);
                console.error('❌ Error message:', error.body?.message);
                console.error('❌ Error stackTrace:', error.body?.stackTrace);
                
                const errorMessage = error.body && error.body.message 
                    ? error.body.message 
                    : 'Error desconocido al cargar datos de Quote. Revisa la consola para más detalles.';
                
                helper.showToast('error', errorMessage, 'Error al cargar Quote');
                this.showSpinner = false;
                this.isDataLoaded = false;
            });
    }

    handleAtras() {
        // Navegar de vuelta a la Quote
        helper.redirectToQuote(this.recordId);
    }

    handleGuardar() {
        this.handleActualizarQuoteLineItems();
    }

    handleAddProduct() {
        this.showModal = true;
    }

    handleCloseModal() {
        this.showModal = false;
    }

    handleModalContinue() {
        this.addSelectedProducts();
        this.showModal = false;
    }

    addSelectedProducts() {
        const currentlySelectedData = [...this.selectedProducts.recordData, ...this.productDataDraft];

        // Remover duplicados basados en el atributo 'id'
        const uniqueData = [];
        const idSet = new Set();

        currentlySelectedData.forEach(item => {
            if (!idSet.has(item.id)) {
                // Inicializar valores por defecto para nuevos productos
                item.descuento = item.descuento || 0;
                item.precioClienteNeto = item.precioClienteNeto || item.listaPrecio;
                item.rappel = item.rappel || null;
                
                // Calcular precioFinal (campo crítico requerido por Apex)
                item.precioFinal = parseFloat(helper.calculatePrecioSolicitado(item));
                
                // Calcular margen y contribución por kilo
                item.margen = helper.calculateMargen(item);
                item.margenContribucionKilo = parseFloat(helper.calculateKilo(item));
                
                // Asegurar que tieneCosto esté definido
                item.tieneCosto = item.costo != null && item.costo > 0;
                
                uniqueData.push(item);
                idSet.add(item.id);
            }
        });

        this.productDataDraft = uniqueData;
    }

    handleActualizarQuoteLineItems() {
        // Formatear items antes de enviar a Apex
        this.productDataDraft = this.productDataDraft.map((item) => {
            let parsedMargin = parseFloat(item.margen);
            if (isNaN(parsedMargin)) {
                parsedMargin = 0;
            }
            return {
                ...item,
                margen: parsedMargin,
            };
        });

        const registrosUnificadosJSON = JSON.parse(JSON.stringify(this.productDataDraft));
        this.showSpinner = true;
        
        helper.showToast('info', 'Guardando cambios...', 'Actualizando Quote');
        
        actualizarQuoteLineItems({ 
            quoteId: this.recordId,
            registrosUnificados: registrosUnificadosJSON 
        })
            .then((result) => {
                helper.showToast('success', result, 'Quote actualizada!');
                this.showSpinner = false;
                // Recargar los datos para mostrar los cambios guardados
                this.cargarDatosQuote();
            })
            .catch((error) => {
                const errorMessage = error.body && error.body.message ? error.body.message : 'Error desconocido al actualizar Quote. Comuníquese con su administrador';
                helper.showToast('error', errorMessage, 'Error al actualizar Quote');
                console.error('Error al actualizar Quote:', error);
                this.showSpinner = false;
            });
    }

    handleSelectProducts(event) {
        this.selectedProducts = event.detail;
    }

    handleCellChange(event) {
        const currentItem = event.detail.draftValues[0];
        
        const shouldCalculatePrecio = currentItem.descuento != null ? true : false;
        const shouldCalculateDescuento = currentItem.precioClienteNeto != null ? true : false;
        const shouldCalculateDate = currentItem.fechaVencimientoDescuento != null ? true : false;

        // Ajustar el item actualizado en productDataDraft
        const auxProductDraft = [...this.productDataDraft];
        const product = auxProductDraft.find(item => item.id === currentItem.id);

        if (product) {
            try {
                if (shouldCalculatePrecio) {
                    product.descuento = currentItem.descuento;
                    product.precioClienteNeto = helper.calculatePrecioSolicitado(product);
                } else if (shouldCalculateDescuento) {
                    product.precioClienteNeto = currentItem.precioClienteNeto;
                    product.descuento = helper.calculateDescuento(product);
                } else if (shouldCalculateDate) {
                    product.fechaVencimientoDescuento = helper.checkDate(product.fechaMaximaOriginal, currentItem.fechaVencimientoDescuento);
                }
                product.margen = helper.calculateMargen(product);
                product.margenContribucionKilo = helper.calculateKilo(product);

                this.productDataDraft = auxProductDraft;
                this.draftValues = [];
                
                if (product.descuento < 0) {
                    helper.showToast('error', 'El descuento no puede ser menor a 0.', 'Error en el descuento');
                }
            } catch (error) {
                console.log('error: ', error);
            }
        }
    }
}