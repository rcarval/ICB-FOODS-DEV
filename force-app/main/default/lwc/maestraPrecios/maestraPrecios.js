import { LightningElement, api, track, wire} from 'lwc';
import { helper } from './maestraPreciosHelper';
import obtenerRegistrosUnificados from '@salesforce/apex/MaestraPreciosController.obtenerRegistrosUnificados';
import { getRecord } from 'lightning/uiRecordApi';
import ACCOUNT_NAME_FIELD from '@salesforce/schema/Account.Name';

export default class MaestraPrecios extends LightningElement {
    @api accountIdValue;
    @api accountName;
    @track allProductData = [];
    @track filteredData = [];
    @track paginatedData = [];
    @track sortedBy = '';
    @track sortedDirection = 'asc';
    @track productsAvailable = false;
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
    @track errorMessage = '';
    @track hasError = false;
    @track accountNameFromRecord = '';
    @track activeFilterSection = '';
    isActualizarClicked = false;
    columns = [];
    encabezado = '';
    initialProductData;

    // Wire para obtener el nombre de la cuenta directamente desde Salesforce
    @wire(getRecord, { recordId: '$accountIdValue', fields: [ACCOUNT_NAME_FIELD] })
    wiredAccount({ error, data }) {
        if (data) {
            // Obtener el nombre directamente desde el registro para evitar problemas de codificación
            this.accountNameFromRecord = data.fields.Name.value;
        } else if (error) {
            console.error('Error al recuperar el nombre de la cuenta:', error);
            // Si falla, usar el accountName pasado como parámetro como fallback
            this.accountNameFromRecord = this.accountName || '';
        }
    }

    connectedCallback() {
        this.encabezado = helper.generarEncabezado();
        this.columns = helper.initializeColumns();
        if (this.accountIdValue) {
            this.cargarDatosMaestra();
        }
    }
    
    renderedCallback() {
        // Asegurar que el select muestre el valor correcto
        const selectElement = this.template.querySelector('.page-size-select');
        if (selectElement && selectElement.value !== this.pageSizeString) {
            selectElement.value = this.pageSizeString;
        }
    }

    cargarDatosMaestra() {
        this.hasError = false;
        this.errorMessage = '';
        obtenerRegistrosUnificados({ accountId: this.accountIdValue })
            .then((result) => {
                // Filtrar registros vacíos o inválidos (registros fantasma)
                this.allProductData = result.filter(product => {
                    // Eliminar registros que no tengan SKU o que sean completamente vacíos
                    return product && product.sku && product.sku.toString().trim() !== '';
                });
                helper.transformarDatos(this.allProductData);
                this.filteredData = [...this.allProductData];
                this.sortData('sku', 'asc');
                this.updatePagination();
                this.productsAvailable = true;
            })
            .catch((error) => {
                console.error('Error al cargar datos de maestra:', error);
                this.hasError = true;
                this.productsAvailable = true; // Para ocultar el spinner
                
                // Extraer mensaje de error
                if (error.body && error.body.message) {
                    this.errorMessage = error.body.message;
                } else if (error.message) {
                    this.errorMessage = error.message;
                } else {
                    this.errorMessage = 'Ocurrió un error al cargar la maestra de precios. Por favor, contacta al administrador.';
                }
            });
    }

    handleActualizar() {
        this.isActualizarClicked = true;
        this.initialProductData = [...this.allProductData];
    }

    handleAtrasClicked() {
        this.isActualizarClicked = false;
    }

    handleSort(event) {
        const { fieldName: sortedBy, sortDirection } = event.detail;
        this.sortedDirection = sortDirection;
        this.sortedBy = sortedBy;
        this.sortData(sortedBy, sortDirection);
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
            'fugadoDisplay': 'fugado'
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

            if (typeof valueA === 'boolean' && typeof valueB === 'boolean') {
                const numA = valueA ? 1 : 0;
                const numB = valueB ? 1 : 0;
                return reverse * (numA - numB);
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
                if (!product.fechaMaximaOriginal) return false;
                const fecha = new Date(product.fechaMaximaOriginal);
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
        
        this.filteredData = filtered;
        this.noResultsFound = this.filteredData.length === 0;
        this.currentPage = 1; // Reset a la primera página
        
        if (this.sortedBy) {
            this.sortData(this.sortedBy, this.sortedDirection);
        } else {
            this.updatePagination();
        }
    }

    // Método para limpiar la búsqueda
    clearSearch() {
        this.searchTerm = '';
        this.filteredData = [...this.allProductData];
        this.noResultsFound = false;
        this.currentPage = 1;
        
        // Reenfocar el campo de búsqueda
        const searchInput = this.template.querySelector('#search-input');
        if (searchInput) {
            searchInput.focus();
        }
        
        // Reaplicar ordenamiento si existe
        if (this.sortedBy) {
            this.sortData(this.sortedBy, this.sortedDirection);
        } else {
            this.updatePagination();
        }
    }
    
    // Métodos para filtros avanzados
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
    
    // Métodos de paginación
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
    
    goToPage(page) {
        if (page >= 1 && page <= this.totalPages) {
            this.currentPage = page;
            this.updatePagination();
        }
    }
    
    handlePageClick(event) {
        const page = parseInt(event.currentTarget.dataset.page, 10);
        this.goToPage(page);
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
    
    get filterButtonIcon() {
        return this.showAdvancedFilters ? 'utility:chevronup' : 'utility:chevrondown';
    }
    
    get filterButtonLabel() {
        return this.showAdvancedFilters ? 'Ocultar filtros avanzados' : 'Mostrar filtros avanzados';
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
    
    get isEmpty() {
        return this.productsAvailable && (!this.hasData || this.filteredData.length === 0);
    }
    
    get isEmptyWithoutFilters() {
        return this.productsAvailable && !this.hasData && !this.searchTerm && !this.hasAdvancedFilters;
    }
    
    get isDataAvailable() {
        return this.hasData;
    }
    
    get isDataDisabled() {
        return !this.hasData;
    }
    
    get pageSizeString() {
        return String(this.pageSize);
    }
    
    // Getter para mostrar el nombre de la cuenta
    // Prioriza el nombre obtenido directamente del registro (accountNameFromRecord)
    // para evitar problemas de codificación al pasar por navegación
    get displayAccountName() {
        // Usar el nombre obtenido directamente del registro si está disponible
        if (this.accountNameFromRecord) {
            return this.accountNameFromRecord;
        }
        // Fallback al accountName pasado como parámetro si no se ha cargado aún
        return this.accountName || '';
    }
    
    // Getter para deshabilitar el botón "Actualizar Maestra Actual" cuando hay error de sucursal
    get isUpdateButtonDisabled() {
        // Deshabilitar si hay un error relacionado con la sucursal
        if (this.hasError && this.errorMessage) {
            // Verificar si el mensaje de error menciona "sucursal" (case insensitive)
            const errorLower = this.errorMessage.toLowerCase();
            return errorLower.includes('sucursal');
        }
        // También deshabilitar si no hay datos disponibles
        return !this.hasData;
    }
}