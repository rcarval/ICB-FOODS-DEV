import { LightningElement, api, track, wire } from 'lwc';
import { helper } from './panelSeteoHelper';
import crearQuote from '@salesforce/apex/MaestraPreciosController.crearQuote';
import getSugerencias from '@salesforce/apex/MaestraPreciosController.getSugerencias';
import updateNoVolverASugerir from '@salesforce/apex/MaestraPreciosController.updateNoVolverASugerir';
import { getRecord } from 'lightning/uiRecordApi';
import { getObjectInfo } from 'lightning/uiObjectInfoApi';
import { getPicklistValues } from 'lightning/uiObjectInfoApi';
import ACCOUNT_NAME_FIELD from '@salesforce/schema/Account.Name';
import FUGADO_OBJECT from '@salesforce/schema/Fugado__c';
import MOTIVO_FIELD from '@salesforce/schema/Fugado__c.Motivo__c';

export default class PanelSeteo extends LightningElement {
    @api accountIdValue;
    @api accountName;
    @api initialProductData; // Datos que llegan desde el padre
    @api shouldFilter = false;
    @api shouldHideButton = false;
    @track productData = []; // Copia los datos del padre para hacerlos reactivos
    @track productDataDraft = []; // Items de la lista que han sido modificados
    @track draftValues = []; // Items de la lista que han sido modificados
    @track selectedProducts = []; // Items que se seleccionen del modal de buscar productos
    @track allProductData = []; // Todos los productos sin filtrar
    @track filteredData = []; // Productos filtrados
    @track paginatedData = []; // Productos paginados
    @track sortedBy = '';
    @track sortedDirection = 'asc';
    @track searchTerm = '';
    @track noResultsFound = false;
    @track showAdvancedFilters = false;
    @track precioMin = '';
    @track precioMax = '';
    @track descuentoMin = '';
    @track descuentoMax = '';
    @track fechaDesde = '';
    @track fechaHasta = '';
    @track filtroFugados = 'all';
    @track currentPage = 1;
    @track pageSize = 50;
    @track totalPages = 1;
    @track accountNameFromRecord = '';
    @track activeFilterSection = '';
    showSpinner = true;
    showModal = false;
    showModalSugerencias = false;
    @track sugerenciasList = [];
    @track sugerenciasTableData = [];
    @track sugerenciasSelectedIds = [];
    @track selectedProductIds = [];
    sugerenciasColumns = [
        { label: 'SKU', fieldName: 'sku', type: 'text', initialWidth: 100 },
        { label: 'Descripción', fieldName: 'descripcion', type: 'text', initialWidth: 300 },
        { label: 'No volver a sugerir', fieldName: 'noVolverASugerir', type: 'boolean', editable: true, initialWidth: 150 }
    ];
    @track draftValuesSugerencias = [];
    @track columns = [];
    @track motivoPicklistOptions = [];
    fugadoRecordTypeId;
    encabezado = '';

    // Wire para obtener el nombre de la cuenta directamente desde Salesforce
    @wire(getRecord, { recordId: '$accountIdValue', fields: [ACCOUNT_NAME_FIELD] })
    wiredAccount({ error, data }) {
        if (data) {
            this.accountNameFromRecord = data.fields.Name.value;
        } else if (error) {
            console.error('Error al recuperar el nombre de la cuenta:', error);
            this.accountNameFromRecord = this.accountName || '';
        }
    }

    @wire(getObjectInfo, { objectApiName: FUGADO_OBJECT })
    wiredFugadoObject({ data, error }) {
        if (data && data.defaultRecordTypeId) {
            this.fugadoRecordTypeId = data.defaultRecordTypeId;
        }
    }

    @wire(getPicklistValues, { recordTypeId: '$fugadoRecordTypeId', fieldApiName: MOTIVO_FIELD })
    wiredMotivoPicklist({ data, error }) {
        if (data && data.values && data.values.length > 0) {
            this.motivoPicklistOptions = data.values.map((v) => ({ label: v.label, value: v.value }));
            this.columns = helper.initializeColumns(this.motivoPicklistOptions);
        }
    }

    connectedCallback() {
        this.encabezado = helper.generarEncabezado();
        const motivoOpts = this.motivoPicklistOptions && this.motivoPicklistOptions.length > 0
            ? this.motivoPicklistOptions
            : helper.getMotivoPicklistDefault();
        this.columns = helper.initializeColumns(motivoOpts);
        if (this.accountIdValue) {
            // Convertir initialProductData a objetos planos para evitar problemas con Proxies
            let plainProductData = [];
            try {
                const jsonString = JSON.stringify(this.initialProductData);
                plainProductData = JSON.parse(jsonString);
            } catch (e) {
                // Si falla JSON, crear copias manualmente
                plainProductData = this.initialProductData.map(item => ({ ...item }));
            }
            
            this.productData = this.shouldFilter ? helper.filtrarProductos(plainProductData) : plainProductData;
            if (this.productData) {
                // Filtrar registros vacíos o inválidos y crear copias planas
                this.allProductData = this.productData
                    .filter(product => {
                        return product && product.sku && product.sku.toString().trim() !== '';
                    })
                    .map(product => {
                        // Crear una copia plana del objeto
                        const plainProduct = { ...product };
                        plainProduct.selectedForQuote = plainProduct.selectedForQuote !== false;
                        // Inicializar valores si no existen
                        if (plainProduct.descuento == null || plainProduct.descuento == undefined) {
                            plainProduct.descuento = 0;
                            plainProduct.precioClienteNeto = plainProduct.listaPrecio;
                            plainProduct.margen = helper.calculateMargen(plainProduct);
                            plainProduct.margenContribucionKilo = helper.calculateKilo(plainProduct);
                        }
                        // Aplicar formato a los números para mostrar
                        this.formatProductNumbers(plainProduct);
                        return plainProduct;
                    });
                
                this.productDataDraft = this.allProductData.map(item => ({ ...item }));
                this.filteredData = [...this.allProductData];
                this.selectedProductIds = this.allProductData.map((p) => p.id);
                this.updateMotivoComentarioEditable();
                this.sortData('sku', 'asc');
                this.updatePagination();
                this.showSpinner = false;
            }
            getSugerencias({ accountId: this.accountIdValue })
                .then((result) => {
                    this.sugerenciasList = result || [];
                })
                .catch(() => { this.sugerenciasList = []; });
        }
    }

    get hasSugerencias() {
        return this.sugerenciasList && this.sugerenciasList.length > 0;
    }

    get noSugerencias() {
        return !this.hasSugerencias;
    }

    get sugerenciasCount() {
        return this.sugerenciasList && this.sugerenciasList.length > 0 ? this.sugerenciasList.length : 0;
    }

    get sugerenciasCountAria() {
        const n = this.sugerenciasCount;
        return n === 1 ? '1 sugerencia disponible' : `${n} sugerencias disponibles`;
    }

    get sugerenciasButtonTitle() {
        return this.hasSugerencias ? 'Ver sugerencias de productos' : 'No hay sugerencias para este cliente';
    }
    
    renderedCallback() {
        const selectElement = this.template.querySelector('.page-size-select');
        if (selectElement && selectElement.value !== this.pageSizeString) {
            selectElement.value = this.pageSizeString;
        }
    }

    handleSort(event) {
        const { fieldName: sortedBy, sortDirection } = event.detail;
        this.sortedDirection = sortDirection;
        this.sortedBy = sortedBy;
        this.sortData(sortedBy, sortDirection);
    }

    handlePanelRowSelection(event) {
        const currentPageIds = new Set((this.paginatedData || []).map((r) => r.id));
        const selectedFromEvent = (event.detail.selectedRows || []).map((r) => r.id);
        this.selectedProductIds = [
            ...(this.selectedProductIds || []).filter((id) => !currentPageIds.has(id)),
            ...selectedFromEvent
        ];
        this.updateMotivoComentarioEditable();
    }

    /**
     * Actualiza motivoComentarioEditable en cada fila: true solo si Fugado Sí y no está seleccionado.
     */
    updateMotivoComentarioEditable() {
        const selectedSet = new Set(this.selectedProductIds || []);
        const list = this.allProductData || [];
        for (const row of list) {
            row.motivoComentarioEditable = row.fugado === true && !selectedSet.has(row.id);
        }
    }

    sortData(columnName, direction) {
        const reverse = direction === 'desc' ? 1 : -1;
        const data = [...this.filteredData];
        
        // Mapear campos formateados a campos numéricos originales para ordenamiento
        const fieldMap = {
            'listaPrecioFormatted': 'listaPrecio',
            'descuentoFormatted': 'descuento',
            'precioClienteNetoFormatted': 'precioClienteNeto',
            'rappelFormatted': 'rappel',
            'margenFormatted': 'margen',
            'margenContribucionKiloFormatted': 'margenContribucionKilo',
            'descuentoAutonomoFormatted': 'descuentoAutonomo'
        };
        
        const actualFieldName = fieldMap[columnName] || columnName;
        
        data.sort((a, b) => {
            let valueA = a[actualFieldName];
            let valueB = b[actualFieldName];
            
            if (valueA == null) valueA = '';
            if (valueB == null) valueB = '';
            
            if (typeof valueA === 'number' && typeof valueB === 'number') {
                return reverse * (valueA - valueB);
            }
            
            if (valueA instanceof Date && valueB instanceof Date) {
                return reverse * (valueA - valueB);
            }
            
            if (typeof valueA === 'string' && typeof valueB === 'string') {
                return reverse * valueA.localeCompare(valueB, undefined, { sensitivity: 'base' });
            }
            
            return reverse * String(valueA).localeCompare(String(valueB), undefined, { sensitivity: 'base' });
        });
        
        this.filteredData = data;
        this.updatePagination();
    }

    handleSearch(event) {
        this.searchTerm = event.target.value.toUpperCase();
        this.filterData();
    }

    filterData() {
        let filtered = [...this.allProductData];
        
        // Filtro de búsqueda rápida (SKU o descripción)
        if (this.searchTerm) {
            filtered = filtered.filter(product => 
                (product.sku && product.sku.toUpperCase().includes(this.searchTerm)) ||
                (product.descripcion && product.descripcion.toUpperCase().includes(this.searchTerm))
            );
        }
        
        // Filtros avanzados
        if (this.precioMin || this.precioMax) {
            const min = this.precioMin ? parseFloat(this.precioMin) : 0;
            const max = this.precioMax ? parseFloat(this.precioMax) : Number.MAX_SAFE_INTEGER;
            filtered = filtered.filter(product => {
                const precio = product.precioClienteNeto ? parseFloat(product.precioClienteNeto) : 0;
                return precio >= min && precio <= max;
            });
        }
        
        if (this.descuentoMin || this.descuentoMax) {
            const min = this.descuentoMin ? parseFloat(this.descuentoMin) : 0;
            const max = this.descuentoMax ? parseFloat(this.descuentoMax) : 100;
            filtered = filtered.filter(product => {
                const descuento = product.descuento ? parseFloat(product.descuento) : 0;
                return descuento >= min && descuento <= max;
            });
        }
        
        if (this.fechaDesde || this.fechaHasta) {
            filtered = filtered.filter(product => {
                if (!product.fechaVencimientoDescuento && !product.fechaMaximaOriginal) return false;
                const fecha = new Date(product.fechaVencimientoDescuento || product.fechaMaximaOriginal);
                const desde = this.fechaDesde ? new Date(this.fechaDesde) : new Date(0);
                const hasta = this.fechaHasta ? new Date(this.fechaHasta) : new Date(9999, 11, 31);
                return fecha >= desde && fecha <= hasta;
            });
        }

        if (this.filtroFugados === 'yes') {
            filtered = filtered.filter(product => product.fugado === true);
        } else if (this.filtroFugados === 'no') {
            filtered = filtered.filter(product => !product.fugado);
        }
        
        // Aplicar formato a los productos filtrados
        filtered.forEach(item => {
            this.formatProductNumbers(item);
        });
        
        this.filteredData = filtered;
        this.noResultsFound = this.filteredData.length === 0;
        this.currentPage = 1;
        
        if (this.sortedBy) {
            this.sortData(this.sortedBy, this.sortedDirection);
        } else {
            this.updatePagination();
        }
        
        // Actualizar productDataDraft con los datos filtrados
        this.productDataDraft = this.filteredData.map(item => ({ ...item }));
    }

    clearSearch() {
        this.searchTerm = '';
        this.filteredData = [...this.allProductData];
        this.noResultsFound = false;
        this.currentPage = 1;
        
        const searchInput = this.template.querySelector('#search-input');
        if (searchInput) {
            searchInput.focus();
        }
        
        if (this.sortedBy) {
            this.sortData(this.sortedBy, this.sortedDirection);
        } else {
            this.updatePagination();
        }
        
        this.productDataDraft = this.filteredData.map(item => ({ ...item }));
    }
    
    handlePrecioMinChange(event) {
        this.precioMin = event.target.value;
        this.filterData();
    }
    
    handlePrecioMaxChange(event) {
        this.precioMax = event.target.value;
        this.filterData();
    }
    
    handleDescuentoMinChange(event) {
        this.descuentoMin = event.target.value;
        this.filterData();
    }
    
    handleDescuentoMaxChange(event) {
        this.descuentoMax = event.target.value;
        this.filterData();
    }
    
    handleFechaDesdeChange(event) {
        this.fechaDesde = event.target.value;
        this.filterData();
    }
    
    handleFechaHastaChange(event) {
        this.fechaHasta = event.target.value;
        this.filterData();
    }
    
    toggleAdvancedFilters() {
        this.showAdvancedFilters = !this.showAdvancedFilters;
        this.activeFilterSection = this.showAdvancedFilters ? 'advancedFilters' : '';
    }
    
    handleAccordionSectionToggle(event) {
        const openSections = event.detail.openSections;
        this.showAdvancedFilters = openSections.includes('advancedFilters');
        this.activeFilterSection = this.showAdvancedFilters ? 'advancedFilters' : '';
    }
    
    clearAdvancedFilters() {
        this.precioMin = '';
        this.precioMax = '';
        this.descuentoMin = '';
        this.descuentoMax = '';
        this.fechaDesde = '';
        this.fechaHasta = '';
        this.filtroFugados = 'all';
        this.filterData();
    }

    handleFiltroFugadosChange(event) {
        this.filtroFugados = event.target.value;
        this.filterData();
    }
    
    updatePagination() {
        this.totalPages = Math.ceil(this.filteredData.length / this.pageSize);
        if (this.currentPage > this.totalPages && this.totalPages > 0) {
            this.currentPage = this.totalPages;
        }
        if (this.totalPages === 0) {
            this.currentPage = 1;
        }
        
        const start = (this.currentPage - 1) * this.pageSize;
        const end = start + this.pageSize;
        this.paginatedData = this.filteredData.slice(start, end);
        this.productDataDraft = this.paginatedData.map(item => ({ ...item }));
    }
    
    handlePageSizeChange(event) {
        this.pageSize = parseInt(event.target.value, 10);
        this.currentPage = 1;
        this.updatePagination();
    }
    
    previousPage() {
        if (this.currentPage > 1) {
            this.currentPage--;
            this.updatePagination();
        }
    }
    
    nextPage() {
        if (this.currentPage < this.totalPages) {
            this.currentPage++;
            this.updatePagination();
        }
    }
    
    handlePageClick(event) {
        const page = parseInt(event.currentTarget.dataset.page, 10);
        if (page >= 1 && page <= this.totalPages) {
            this.currentPage = page;
            this.updatePagination();
        }
    }
    
    get pageNumbers() {
        const pages = [];
        const maxPagesToShow = 5;
        let startPage = Math.max(1, this.currentPage - Math.floor(maxPagesToShow / 2));
        let endPage = Math.min(this.totalPages, startPage + maxPagesToShow - 1);
        
        if (endPage - startPage < maxPagesToShow - 1) {
            startPage = Math.max(1, endPage - maxPagesToShow + 1);
        }
        
        for (let i = startPage; i <= endPage; i++) {
            pages.push({
                number: i,
                variant: i === this.currentPage ? 'brand' : 'neutral'
            });
        }
        return pages;
    }
    
    get hasAdvancedFilters() {
        return this.precioMin || this.precioMax || this.descuentoMin || 
               this.descuentoMax || this.fechaDesde || this.fechaHasta ||
               (this.filtroFugados && this.filtroFugados !== 'all');
    }
    
    get paginationInfo() {
        if (!this.hasData) {
            return 'No hay productos disponibles';
        }
        if (this.filteredData.length === 0) {
            return 'No hay productos que coincidan con los filtros';
        }
        const start = (this.currentPage - 1) * this.pageSize + 1;
        const end = Math.min(this.currentPage * this.pageSize, this.filteredData.length);
        return `Mostrando ${start} - ${end} de ${this.filteredData.length}`;
    }
    
    get isFirstPage() {
        return this.currentPage === 1;
    }
    
    get isLastPage() {
        return this.currentPage === this.totalPages;
    }
    
    get hasData() {
        return this.allProductData && this.allProductData.length > 0;
    }
    
    get isDataDisabled() {
        return !this.hasData;
    }
    
    get pageSizeString() {
        return String(this.pageSize);
    }
    
    get displayAccountName() {
        if (this.accountNameFromRecord) {
            return this.accountNameFromRecord;
        }
        return this.accountName || '';
    }

    // Función para formatear números en un producto
    formatProductNumbers(product) {
        if (!product) return;
        if (product.fugado == null || product.fugado === undefined) product.fugado = false;
        product.fugadoDisplay = product.fugado ? 'Sí' : 'No';
        product.fugadoDisplayClass = product.fugado ? 'slds-text-color_error' : 'slds-text-color_success';
        if (product.motivoFuga == null) product.motivoFuga = '';
        if (product.comentarioFuga == null) product.comentarioFuga = '';
        // Formatear todos los campos numéricos
        product.descuentoAutonomoFormatted = helper.formatNumber(product.descuentoAutonomo, 2);
        // Lista de Precio: no mostrar ,00 si no hay decimales
        product.listaPrecioFormatted = helper.formatNumber(product.listaPrecio, 2, false);
        product.descuentoFormatted = helper.formatNumber(product.descuento, 2);
        // Precio Cliente Neto: no mostrar ,00 si no hay decimales
        product.precioClienteNetoFormatted = helper.formatNumber(product.precioClienteNeto, 2, false);
        if (product.rappel != null) {
            product.rappelFormatted = helper.formatNumber(product.rappel, 2);
        }
        
        // Formatear margen (puede ser número o "SIN COSTO")
        if (product.margen && product.margen !== 'SIN COSTO') {
            product.margenFormatted = helper.formatNumber(product.margen, 2);
        } else {
            product.margenFormatted = product.margen || '';
        }
        
        product.margenContribucionKiloFormatted = helper.formatNumber(product.margenContribucionKilo, 0);
    }

    // Función helper para convertir string formateado a número
    parseFormattedNumber(value) {
        if (value == null || value === '') {
            return null;
        }
        // Si ya es un número, retornarlo
        if (typeof value === 'number') {
            return value;
        }
        // Convertir string formateado (ej: "10,00" o "1.234,56" o "10") a número
        // Remover puntos (separadores de miles) y reemplazar coma por punto
        const cleaned = String(value).replace(/\./g, '').replace(',', '.');
        const parsed = parseFloat(cleaned);
        return isNaN(parsed) ? null : parsed;
    }


    handleAtras() {
        const event = new CustomEvent('atrasclicked', {
            detail: { isActualizarClicked: true }
        });
        this.dispatchEvent(event);
    }

    handlePrecioClienteNeto(event) {
        const newPrecioSolicitado = parseFloat(event.target.value) || 0;
        const itemId = event.target.dataset.id;
        let currentDescuento;
        let currentMg;

        // Obtener valor actual de descuento
        const descuentoElement = this.template.querySelector(`.descuento-value[data-id="${itemId}"]`);
        if (descuentoElement) {
            currentDescuento = descuentoElement.value;
            if (currentDescuento === '') {
                currentDescuento = 0;
            }
            currentDescuento = helper.calculateDescuento(newPrecioSolicitado).toFixed(2);
            descuentoElement.value = currentDescuento;
        } else {
            console.log('Elemento no encontrado para el item con id', itemId);
        }

        // Obtener valor actual de %MG
        const mgElement = this.template.querySelector(`.mg-value[data-id="${itemId}"]`);
        if (mgElement) {
            currentMg = mgElement.innerText;
            if (currentMg === '') {
                currentMg = 0;
            }
            currentMg = helper.calculateMg(newPrecioSolicitado).toFixed(2);
            mgElement.innerText = currentMg;
        } else {
            console.log('Elemento no encontrado para el item con id', itemId);
        }

        // Ajustar el item actualizado en productDataDraft
        const product = this.productDataDraft.find(item => item.id === itemId);
        if (product) {
            product.descuento = currentDescuento.toString();
            product.margen = currentMg.toString();
            product.precioClienteNeto = newPrecioSolicitado;
            // TO DO: Actualizar margen por kilo
        }
    }

    handleDescuentoChange(event) {
        const newDescuento = parseFloat(event.target.value) || 0;
        const itemId = event.target.dataset.id;
        let currentPrecio;
        let currentMg;

        // Obtener valor actual de Precio Solicitado
        const precioElement = this.template.querySelector(`.precio-cliente-value[data-id="${itemId}"]`);
        if (precioElement) {
            currentPrecio = precioElement.value;
            if (currentPrecio === '') {
                currentPrecio = 0;
            }
            currentPrecio = helper.calculatePrecioSolicitado(newDescuento).toFixed(2);
            precioElement.value = currentPrecio;
        } else {
            console.log('Elemento no encontrado para el item con id', itemId);
        }

        // Obtener valor actual de %MG
        const mgElement = this.template.querySelector(`.mg-value[data-id="${itemId}"]`);
        if (mgElement) {
            currentMg = mgElement.innerText;
            if (currentMg === '') {
                currentMg = 0;
            }
            currentMg = helper.calculateMg(currentPrecio).toFixed(2);
            mgElement.innerText = currentMg;
        } else {
            console.log('Elemento no encontrado para el item con id', itemId);
        }

        // Ajustar el item actualizado en productDataDraft
        const auxProductDraft = [...this.productDataDraft]; // Evitar mutabilidad directa.
        const product = auxProductDraft.find(item => item.id === itemId);
        if (product) {
            try {
                product.descuento = newDescuento.toString();
                product.margen = currentMg.toString();
                product.precioClienteNeto = currentPrecio;
                // TO DO: Actualizar margen por kilo
            } catch (error) {
                console.log('error: ', error);
            }
        }
        this.productDataDraft = auxProductDraft;
    }

    handleFechaChange(event) {
        console.log(event.target.value);
    }

    handleDraft() {
        this.handleCreateQuoteButton('Draft');
    }

    handleAddProduct() {
        this.showModal = true;
    }

    handleOpenSugerencias() {
        if (!this.hasSugerencias) return;
        this.sugerenciasTableData = this.sugerenciasList.map((item) => {
            const reg = item.registro || {};
            return {
                ...reg,
                fugadoId: item.fugadoId,
                noVolverASugerir: false
            };
        });
        this.sugerenciasSelectedIds = this.sugerenciasTableData.map((r) => r.id);
        this.showModalSugerencias = true;
    }

    handleCloseModalSugerencias() {
        this.showModalSugerencias = false;
    }

    @track draftValuesSugerencias = [];

    handleSugerenciasCellChange(event) {
        const draft = event.detail.draftValues;
        if (!draft || !draft.length) return;
        const row = draft[0];
        const data = [...this.sugerenciasTableData];
        const idx = data.findIndex((r) => r.id === row.id);
        if (idx >= 0 && row.noVolverASugerir !== undefined) {
            data[idx].noVolverASugerir = row.noVolverASugerir;
            this.sugerenciasTableData = data;
        }
        this.draftValuesSugerencias = [];
    }

    handleSugerenciasRowSelection(event) {
        const selected = event.detail.selectedRows || [];
        this.sugerenciasSelectedIds = selected.map((r) => r.id);
    }

    handleModalContinueSugerencias() {
        const selectedIdsSet = new Set(this.sugerenciasSelectedIds || []);
        const selectedRows = this.sugerenciasTableData.filter((r) => selectedIdsSet.has(r.id));
        if (selectedRows.length > 0) {
            const recordData = selectedRows.map((r) => {
                const { fugadoId, selected, noVolverASugerir, ...registro } = r;
                return registro;
            });
            this.selectedProducts = { recordData };
            this.addSelectedProducts();
        }
        const noVolverIds = this.sugerenciasTableData
            .filter((r) => r.noVolverASugerir === true && r.fugadoId)
            .map((r) => r.fugadoId);
        if (noVolverIds.length > 0) {
            updateNoVolverASugerir({ fugadoIds: noVolverIds }).catch(() => {});
        }
        this.sugerenciasList = this.sugerenciasList.filter((item) => {
            const id = noVolverIds.find((fid) => fid === item.fugadoId);
            return !id;
        });
        this.showModalSugerencias = false;
    }

    handleCloseModal() {
        this.showModal = false;
    }

    handleModalContinue() {
        console.log('handleModalContinue llamado');
        console.log('selectedProducts:', this.selectedProducts);
        
        // Convertir usando JSON para asegurar que no queden Proxies
        let recordData = [];
        if (this.selectedProducts && this.selectedProducts.recordData) {
            try {
                // Usar JSON para convertir cualquier Proxy restante
                const jsonString = JSON.stringify(this.selectedProducts.recordData);
                recordData = JSON.parse(jsonString);
                
                if (!Array.isArray(recordData)) {
                    console.warn('recordData no es un array después de la conversión:', typeof recordData);
                    recordData = [];
                }
            } catch (e) {
                console.error('Error al convertir recordData con JSON:', e);
                // Si ya es un array normal, usarlo directamente
                if (Array.isArray(this.selectedProducts.recordData)) {
                    recordData = [...this.selectedProducts.recordData];
                } else {
                    recordData = [];
                }
            }
        }
        
        console.log('recordData convertido:', recordData);
        console.log('Cantidad de productos:', recordData.length);
        if (recordData.length > 0) {
            console.log('Primer producto:', recordData[0]);
            console.log('ID del primer producto:', recordData[0].id || recordData[0].Id || 'sin id');
            console.log('SKU del primer producto:', recordData[0].sku || 'sin sku');
        }
        
        if (!recordData || recordData.length === 0) {
            helper.showToast('warning', 'No se han seleccionado productos para agregar.', 'Sin productos seleccionados');
            this.showModal = false;
            return;
        }
        
        // Actualizar selectedProducts con el array convertido
        this.selectedProducts = { recordData: recordData };
        
        this.addSelectedProducts();
        this.showModal = false;
    }

    addSelectedProducts() {
        console.log('addSelectedProducts llamado');
        console.log('selectedProducts.recordData:', this.selectedProducts.recordData);
        console.log('allProductData antes:', this.allProductData.length);
        
        // Convertir usando JSON para asegurar que no queden Proxies
        let newProducts = [];
        if (this.selectedProducts && this.selectedProducts.recordData) {
            try {
                // Usar JSON para convertir cualquier Proxy restante
                const jsonString = JSON.stringify(this.selectedProducts.recordData);
                newProducts = JSON.parse(jsonString);
                
                if (!Array.isArray(newProducts)) {
                    console.error('newProducts no es un array después de la conversión:', typeof newProducts);
                    newProducts = [];
                }
            } catch (e) {
                console.error('Error al convertir newProducts con JSON:', e);
                // Si ya es un array normal, usarlo directamente
                if (Array.isArray(this.selectedProducts.recordData)) {
                    newProducts = [...this.selectedProducts.recordData];
                } else {
                    newProducts = [];
                }
            }
        }
        
        console.log('newProducts convertido:', newProducts);
        console.log('Cantidad de productos nuevos:', newProducts.length);
        if (newProducts.length > 0) {
            console.log('Primer producto nuevo:', newProducts[0]);
            console.log('ID del primer producto nuevo:', newProducts[0].id || newProducts[0].Id || 'sin id');
            console.log('SKU del primer producto nuevo:', newProducts[0].sku || 'sin sku');
        }
        
        if (newProducts.length === 0) {
            console.warn('No hay productos nuevos para agregar');
            helper.showToast('warning', 'No se pudieron obtener los productos seleccionados.', 'Error');
            return;
        }
        
        // Asegurarse de que newProducts tiene IDs válidos
        const validNewProducts = newProducts.filter(item => {
            const hasId = item && (item.id || item.Id);
            if (!hasId) {
                console.warn('Producto sin ID:', item);
            }
            return hasId;
        });
        
        if (validNewProducts.length === 0) {
            console.error('No hay productos válidos para agregar (sin IDs)');
            helper.showToast('error', 'Los productos seleccionados no tienen IDs válidos.', 'Error');
            return;
        }

        // No agregar productos que ya están en el listado (por productId o SKU)
        const existingProductIds = new Set((this.allProductData || []).map((p) => p.productId).filter(Boolean));
        const existingSkus = new Set((this.allProductData || []).map((p) => String(p.sku || '').trim()).filter(Boolean));
        const validNewProductsFiltered = validNewProducts.filter((p) => {
            const productId = p.productId;
            const sku = String(p.sku || '').trim();
            if (productId && existingProductIds.has(productId)) return false;
            if (sku && existingSkus.has(sku)) return false;
            return true;
        });
        const skipped = validNewProducts.length - validNewProductsFiltered.length;
        if (validNewProductsFiltered.length === 0) {
            helper.showToast('info', skipped > 0 ? 'Los productos seleccionados ya están en el listado.' : 'No hay productos nuevos para agregar.', 'Sin agregar');
            this.showModalSugerencias = false;
            return;
        }
        if (skipped > 0) {
            helper.showToast('info', `${skipped} producto(s) ya estaban en el listado y no se agregaron de nuevo.`, 'Duplicados omitidos');
        }
        
        console.log('Productos válidos para agregar:', validNewProductsFiltered.length);
        console.log('IDs de productos válidos:', validNewProductsFiltered.map(p => p.id || p.Id));
        
        // Crear copias planas de los productos nuevos antes de agregarlos
        const plainNewProducts = validNewProductsFiltered.map(item => {
            try {
                const jsonString = JSON.stringify(item);
                const plain = JSON.parse(jsonString);
                plain.selectedForQuote = true;
                return plain;
            } catch (e) {
                const plain = { ...item };
                plain.selectedForQuote = true;
                return plain;
            }
        });
        
        const newIds = plainNewProducts.map((p) => p.id || p.Id).filter(Boolean);
        this.selectedProductIds = [...new Set([...(this.selectedProductIds || []), ...newIds])];

        const currentlySelectedData = [...plainNewProducts, ...this.allProductData];

        // Remove duplicates based on the 'id' attribute
        const uniqueData = [];
        const idSet = new Set();

        currentlySelectedData.forEach(item => {
            const itemId = item.id || item.Id;
            if (itemId && !idSet.has(itemId)) {
                // Crear una copia plana del objeto para evitar mutaciones y problemas con Proxies
                let newItem;
                try {
                    const jsonString = JSON.stringify(item);
                    newItem = JSON.parse(jsonString);
                } catch (e) {
                    newItem = { ...item };
                }
                
                // Inicializar valores si no existen
                if (newItem.descuento == null || newItem.descuento == undefined) {
                    newItem.descuento = 0;
                }
                if (newItem.precioClienteNeto == null || newItem.precioClienteNeto == undefined) {
                    newItem.precioClienteNeto = newItem.listaPrecio || 0;
                }
                newItem.margen = helper.calculateMargen(newItem);
                newItem.margenContribucionKilo = helper.calculateKilo(newItem);
                // Aplicar formato a los números
                this.formatProductNumbers(newItem);
                uniqueData.push(newItem);
                idSet.add(itemId);
            }
        });

        console.log('allProductData después:', uniqueData.length);
        console.log('IDs finales:', uniqueData.map(p => p.id || p.Id));
        
        this.allProductData = uniqueData;
        this.filteredData = [...this.allProductData];
        this.updateMotivoComentarioEditable();

        // Resetear búsqueda y filtros para mostrar todos los productos
        this.searchTerm = '';
        this.precioMin = '';
        this.precioMax = '';
        this.descuentoMin = '';
        this.descuentoMax = '';
        this.fechaDesde = '';
        this.fechaHasta = '';
        this.filtroFugados = 'all';
        
        // Reordenar y actualizar paginación
        this.sortData('sku', 'asc');
        
        helper.showToast('success', `Se agregaron ${validNewProductsFiltered.length} producto(s) correctamente.`, 'Productos agregados');
    }

    handleCreateQuoteButton(status) {
        const selectedIdsSet = new Set(this.selectedProductIds || []);
        const selectedForQuote = this.filteredData.filter((item) => selectedIdsSet.has(item.id));
        if (!selectedForQuote || selectedForQuote.length === 0) {
            helper.showToast('error', 'Seleccione al menos un producto para la cotización.', 'Sin productos seleccionados');
            return;
        }

        // Validar contra TODA la lista del panel: Fugado Sí + no seleccionados deben tener Motivo
        const listaCompleta = this.allProductData || [];
        const fugadoVerdadero = (r) => r.fugado === true || r.fugado === 'true' || !!r.fugado;
        const fugadoYNoSeleccionados = listaCompleta.filter(
            (r) => fugadoVerdadero(r) && !selectedIdsSet.has(r.id)
        );
        const sinMotivo = fugadoYNoSeleccionados.filter(
            (r) => !(r.motivoFuga != null && String(r.motivoFuga).trim() !== '')
        );
        if (sinMotivo.length > 0) {
            const skus = sinMotivo.map((r) => r.sku || r.descripcion || r.id).slice(0, 5).join(', ');
            const msg = sinMotivo.length > 5
                ? `Debe ingresar motivo de fuga en los productos fugados no seleccionados (ej.: ${skus}...).`
                : `Debe ingresar motivo de fuga en: ${skus}.`;
            helper.showToast('error', msg, 'Motivo de fuga requerido');
            return;
        }

        const fugadosParaPersistir = fugadoYNoSeleccionados
            .filter((r) => (r.motivoFuga || '').trim() !== '')
            .map((r) => ({
                productId: r.productId || r.id,
                motivoFuga: (r.motivoFuga || '').trim(),
                comentarioFuga: (r.comentarioFuga || '').trim() || null
            }));

        const allFilteredProducts = selectedForQuote.map((item) => {
            let parsedMargin = parseFloat(item.margen);
            if (isNaN(parsedMargin)) parsedMargin = 0;
            return { ...item, margen: parsedMargin };
        });

        const registrosUnificadosJSON = JSON.parse(JSON.stringify(allFilteredProducts));
        this.showSpinner = true;
        helper.showToast('info', 'Pronto se redireccionará...', 'Creando Quote...');
        crearQuote({
            status: status,
            registrosUnificados: registrosUnificadosJSON,
            accountId: this.accountIdValue,
            fugadosParaPersistir: fugadosParaPersistir
        })
            .then((result) => {
                helper.showToast('success', 'Redireccionando...', 'Quote creada!');
                helper.redirectToQuote(result.Id);
            })
            .catch((error) => {
                const errorMessage = error.body && error.body.message ? error.body.message : 'Error desconocido al crear Quote. Comuniquese con su administrador';
                helper.showToast('error', errorMessage, 'Error al crear Quote');
                console.error('Error al crear Quote:', error);
                this.showSpinner = false;
            });
    }

    // Función helper para convertir Proxy a objeto plano
    convertProxyToPlainObject(proxyObj) {
        if (!proxyObj) return null;
        if (Array.isArray(proxyObj)) {
            return proxyObj.map(item => this.convertProxyToPlainObject(item));
        }
        if (typeof proxyObj === 'object') {
            const plain = {};
            for (const key in proxyObj) {
                if (proxyObj.hasOwnProperty(key)) {
                    const value = proxyObj[key];
                    if (value && typeof value === 'object' && !Array.isArray(value)) {
                        plain[key] = this.convertProxyToPlainObject(value);
                    } else if (Array.isArray(value)) {
                        plain[key] = value.map(item => this.convertProxyToPlainObject(item));
                    } else {
                        plain[key] = value;
                    }
                }
            }
            return plain;
        }
        return proxyObj;
    }

    handleSelectProducts(event) {
        // El evento viene con detail: { recordData: [...] }
        if (event && event.detail && event.detail.recordData) {
            // Usar JSON para convertir Proxy a objetos planos de manera confiable
            let recordData = [];
            try {
                const sourceData = event.detail.recordData;
                // JSON.stringify/parse es la forma más confiable de convertir Proxies
                const jsonString = JSON.stringify(sourceData);
                recordData = JSON.parse(jsonString);
                
                // Verificar que sea un array
                if (!Array.isArray(recordData)) {
                    console.warn('recordData no es un array después de la conversión:', typeof recordData);
                    recordData = [];
                }
            } catch (e) {
                console.error('Error al convertir recordData con JSON:', e);
                // Fallback: intentar iterar manualmente
                try {
                    const sourceData = event.detail.recordData;
                    if (sourceData && typeof sourceData.length !== 'undefined') {
                        for (let i = 0; i < sourceData.length; i++) {
                            try {
                                const item = sourceData[i];
                                // Intentar convertir cada item con JSON también
                                const itemJson = JSON.stringify(item);
                                recordData.push(JSON.parse(itemJson));
                            } catch (itemError) {
                                console.warn(`Error al convertir item ${i}:`, itemError);
                            }
                        }
                    }
                } catch (fallbackError) {
                    console.error('Error en fallback de conversión:', fallbackError);
                    recordData = [];
                }
            }
            
            this.selectedProducts = { recordData: recordData };
            console.log('Productos seleccionados:', this.selectedProducts);
            console.log('Cantidad de productos:', recordData.length);
            if (recordData.length > 0) {
                console.log('Primer producto:', recordData[0]);
                console.log('IDs de productos:', recordData.map(p => p.id || p.Id || 'sin id'));
            }
        } else {
            console.error('Error: event.detail o recordData no está definido', event);
            this.selectedProducts = { recordData: [] };
        }
    }

    handleCellChange(event) {
        const currentItem = event.detail.draftValues[0];
        
        // Detectar qué campo formateado fue editado
        const descuentoFormattedChanged = currentItem.descuentoFormatted != null && currentItem.descuentoFormatted !== undefined;
        const precioClienteNetoFormattedChanged = currentItem.precioClienteNetoFormatted != null && currentItem.precioClienteNetoFormatted !== undefined;
        const fechaChanged = currentItem.fechaVencimientoDescuento != null && currentItem.fechaVencimientoDescuento !== undefined;
        const motivoFugaChanged = currentItem.motivoFuga !== undefined;
        const comentarioFugaChanged = currentItem.comentarioFuga !== undefined;

        // Bloquear Motivo y Comentario si no es Fugado Sí o está seleccionado
        if (motivoFugaChanged || comentarioFugaChanged) {
            const row = (this.filteredData || []).find((item) => item.id === currentItem.id);
            if (row && row.motivoComentarioEditable === false) {
                helper.showToast(
                    'warning',
                    'Motivo y Comentario solo se pueden editar en productos con Fugado: Sí que no estén seleccionados.',
                    'Edición no permitida'
                );
                this.draftValues = [];
                return;
            }
        }

        // Actualizar en productDataDraft (página actual)
        const auxProductDraft = [...this.productDataDraft];
        const product = auxProductDraft.find(item => item.id === currentItem.id);
        
        // También actualizar en filteredData
        const auxFilteredData = [...this.filteredData];
        const productInFiltered = auxFilteredData.find(item => item.id === currentItem.id);
        
        // También actualizar en allProductData
        const auxAllProductData = [...this.allProductData];
        const productInAll = auxAllProductData.find(item => item.id === currentItem.id);

        if (product && productInFiltered && productInAll) {
            try {
                if (descuentoFormattedChanged) {
                    // Convertir el valor formateado a número
                    const descuentoValue = this.parseFormattedNumber(currentItem.descuentoFormatted);
                    if (descuentoValue !== null) {
                        product.descuento = descuentoValue;
                        product.precioClienteNeto = parseFloat(helper.calculatePrecioSolicitado(product));
                        productInFiltered.descuento = product.descuento;
                        productInFiltered.precioClienteNeto = product.precioClienteNeto;
                        productInAll.descuento = product.descuento;
                        productInAll.precioClienteNeto = product.precioClienteNeto;
                    }
                } else if (precioClienteNetoFormattedChanged) {
                    // Convertir el valor formateado a número
                    const precioValue = this.parseFormattedNumber(currentItem.precioClienteNetoFormatted);
                    if (precioValue !== null) {
                        product.precioClienteNeto = precioValue;
                        product.descuento = parseFloat(helper.calculateDescuento(product));
                        productInFiltered.precioClienteNeto = product.precioClienteNeto;
                        productInFiltered.descuento = product.descuento;
                        productInAll.precioClienteNeto = product.precioClienteNeto;
                        productInAll.descuento = product.descuento;
                    }
                } else if (fechaChanged) {
                    product.fechaVencimientoDescuento = helper.checkDate(product.fechaMaximaOriginal, currentItem.fechaVencimientoDescuento);
                    productInFiltered.fechaVencimientoDescuento = product.fechaVencimientoDescuento;
                    productInAll.fechaVencimientoDescuento = product.fechaVencimientoDescuento;
                } else if (motivoFugaChanged) {
                    product.motivoFuga = currentItem.motivoFuga != null ? String(currentItem.motivoFuga) : '';
                    productInFiltered.motivoFuga = product.motivoFuga;
                    productInAll.motivoFuga = product.motivoFuga;
                } else if (comentarioFugaChanged) {
                    product.comentarioFuga = currentItem.comentarioFuga != null ? String(currentItem.comentarioFuga) : '';
                    productInFiltered.comentarioFuga = product.comentarioFuga;
                    productInAll.comentarioFuga = product.comentarioFuga;
                }
                
                // Recalcular margen y margen por kilo
                product.margen = helper.calculateMargen(product);
                product.margenContribucionKilo = helper.calculateKilo(product);
                productInFiltered.margen = product.margen;
                productInFiltered.margenContribucionKilo = product.margenContribucionKilo;
                productInAll.margen = product.margen;
                productInAll.margenContribucionKilo = product.margenContribucionKilo;

                // Aplicar formato actualizado a todos los campos
                this.formatProductNumbers(product);
                this.formatProductNumbers(productInFiltered);
                this.formatProductNumbers(productInAll);

                this.productDataDraft = auxProductDraft;
                this.filteredData = auxFilteredData;
                this.allProductData = auxAllProductData;
                
                // Actualizar paginatedData para reflejar los cambios en la tabla
                this.updatePagination();
                
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