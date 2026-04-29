import { ShowToastEvent } from 'lightning/platformShowToastEvent';

// Valores por defecto del picklist Fugado__c.Motivo__c (por si getPicklistValues no está disponible)
const MOTIVO_PICKLIST_DEFAULT = [
    { label: 'Precio elevado', value: 'Precio elevado' },
    { label: 'Fecha especial (Navidad, Año Nuevo, eventos)', value: 'Fecha especial' },
    { label: 'Calidad / insatisfacción con producto', value: 'Calidad' },
    { label: 'Cambio de proveedor o marca', value: 'Cambio de proveedor' },
    { label: 'Baja demanda / cierre temporal', value: 'Baja demanda' },
    { label: 'Producto descontinuado o sin stock', value: 'Producto descontinuado' },
    { label: 'Promoción o compra puntual', value: 'Promoción puntual' },
    { label: 'Otro (complementar con Comentario)', value: 'Otro' }
];

const helper = {
    // Función para formatear números con punto para miles y coma para decimales
    formatNumber: (value, decimals = 2, showDecimalsIfZero = true) => {
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
        
        // Si showDecimalsIfZero es false y los decimales son cero, no mostrar decimales
        if (!showDecimalsIfZero && decimalPart && parseFloat(decimalPart) === 0) {
            return formattedInteger;
        }
        
        // Retornar con coma como separador decimal
        return decimalPart ? `${formattedInteger},${decimalPart}` : formattedInteger;
    },

    generarEncabezado: () => {
        const today = new Date();

        const meses = [
            'Enero', 'Febrero', 'Marzo', 'Abril', 'Mayo', 'Junio',
            'Julio', 'Agosto', 'Septiembre', 'Octubre', 'Noviembre', 'Diciembre'
        ];

        const mesTexto = meses[today.getMonth()];
        const anio = today.getFullYear();
        
        return `${mesTexto.toUpperCase()} ${anio}`;
    },

    getMotivoPicklistDefault: () => MOTIVO_PICKLIST_DEFAULT,

    /**
     * @param {Array<{label: string, value: string}>} [motivoPicklistOptions] - Opciones del picklist Fugado__c.Motivo__c para columna Motivo
     */
    initializeColumns: (motivoPicklistOptions) => {
        const motivoColumn = motivoPicklistOptions && motivoPicklistOptions.length > 0
            ? { label: 'Motivo', fieldName: 'motivoFuga', type: 'motivoPicklist', editable: true, sortable: true, initialWidth: 220, typeAttributes: { options: motivoPicklistOptions, context: { fieldName: 'id' }, fieldName: 'motivoFuga' } }
            : { label: 'Motivo', fieldName: 'motivoFuga', type: 'text', editable: true, sortable: true, initialWidth: 180 };
        return [
            { label: 'SKU', fieldName: 'sku', type: 'text', sortable: true, initialWidth: 100 },
            { label: 'UMV', fieldName: 'umv', type: 'text', sortable: true, initialWidth: 80 },
            { label: 'Descripción', fieldName: 'descripcion', type: 'text', sortable: true, initialWidth: 350 },
            { label: 'Fugados', fieldName: 'fugadoDisplay', type: 'text', sortable: true, initialWidth: 90, cellAttributes: { class: { fieldName: 'fugadoDisplayClass' } } },
            motivoColumn,
            { label: 'Comentario', fieldName: 'comentarioFuga', type: 'text', editable: true, sortable: true, initialWidth: 200 },
            { label: '% Autónomo', fieldName: 'descuentoAutonomoFormatted', type: 'text', cellAttributes: { alignment: 'right' }, sortable: true, initialWidth: 120 },
            { label: 'Lista de Precio', fieldName: 'listaPrecioFormatted', type: 'text', cellAttributes: { alignment: 'right' }, sortable: true, initialWidth: 150 },
            { label: 'Descuento %', fieldName: 'descuentoFormatted', type: 'text', editable: true, cellAttributes: { alignment: 'right' }, sortable: true, initialWidth: 140 },
            { label: 'Precio Cliente Neto', fieldName: 'precioClienteNetoFormatted', type: 'text', editable: true, cellAttributes: { alignment: 'right' }, sortable: true, initialWidth: 180 },
            { label: '%MG', fieldName: 'margenFormatted', type: 'text', sortable: true, initialWidth: 100 },
            { label: 'MG Contribución x Kilo', fieldName: 'margenContribucionKiloFormatted', type: 'text', cellAttributes: { alignment: 'right' }, sortable: true, initialWidth: 200 },
            { label: 'Fecha Vto de Descuento', fieldName: 'fechaVencimientoDescuento', type: 'date', editable: true, typeAttributes: {year: 'numeric', month: '2-digit', day:'2-digit'}, sortable: true, initialWidth: 180 }
        ];
    },

    filtrarProductos: (productos) => {
        return productos.filter(producto => (producto.precioFinal != null && producto.tieneCosto == true && producto.listaPrecio != null && producto.listaPrecio != 0 && producto.fechaVencimientoDescuento != null));
    },

    calculateDescuento: (product) => {
        const listaPrecio = product.listaPrecio;
        const precioNeto = product.precioClienteNeto;
        if (listaPrecio === 0) {
            showToast('error', 'El valor1 no puede ser 0, ya que causaría una división por cero.', 'Error');
        }
        if (precioNeto == null) {
            precioNeto = 0;
        }
        const porcentaje = ((listaPrecio - precioNeto) * 100) / listaPrecio;
        return porcentaje.toFixed(2);
    },

    calculateMargen: (product) => {
        let margen = 0;
        if (product.costo == null || product.costo == undefined || product.costo == 0) {
            margen = 'SIN COSTO';
        } else if (product.rappel != null) {
            const rappelAplicado = Number(product.precioClienteNeto) * (product.rappel / 100);
            const precioConRappel = Number(product.precioClienteNeto) + rappelAplicado;
            margen = ((precioConRappel - product.costo) / precioConRappel) * 100;
            margen = margen.toFixed(2).toString();
        } else {
            margen = ((product.precioClienteNeto - product.costo) / product.precioClienteNeto) * 100;
            margen = margen.toFixed(2).toString();
        }
        return margen;
    },
    
    calculateKilo: (product) => {
        let margenKilo = 0;
        if (product.peso != null) {
            margenKilo = ((product.precioClienteNeto - product.costo) / product.peso);
        } 
        return margenKilo.toFixed(2);
    },

    calculatePrecioSolicitado: (product) => {
        const precioLista = product.listaPrecio;
        const descuento = product.descuento;
        const rappel = product.rappel;
        let total = 0;
        if (rappel != null) {
            const totalBeforeRappel = precioLista - ((precioLista * descuento) / 100);
            total = totalBeforeRappel + ((totalBeforeRappel * rappel) / 100);
        } else {
            total = precioLista - ((precioLista * descuento) / 100);
        }
        return total.toFixed(2);
    },

    redirectToQuote: (quoteId) => {
        const quoteUrl = `/lightning/r/Quote/${quoteId}/view`;
        window.location.href = quoteUrl;
    },

    checkDate: (maxDate, newDate) => {
        let date;
        if (newDate > maxDate) {
            date = maxDate;
            // Formatear la fecha como dia-mes-año
            const formatDate = (inputDate) => {
                    const options = { day: '2-digit', month: '2-digit', year: 'numeric' };
                    return new Intl.DateTimeFormat('es-ES', options).format(new Date(inputDate));
                };
            helper.showToast('warning', 'La fecha no puede ser mayor a la máxima permitida: ' + formatDate(date), 'Ajuste en Fecha');
        } else {
            date = newDate;
        }
        return date;
    },

    showToast: (type, message, title) => {
        switch (type) {
            case 'success':
                title = title;
                break;
            case 'error':
                title = title;
                break;
            case 'warning':
                title = title;
                break;
            case 'info':
                title = title;
                break;
            default:
                title = 'Info';
                type = 'info'; // Default type if an unrecognized type is passed
        }

        const toastEvent = new ShowToastEvent({
            title: title,
            message: message,
            variant: type,
            mode: type == 'error' ? 'sticky' : 'dismissable'
        });
        dispatchEvent(toastEvent);
    }
}

export { helper }