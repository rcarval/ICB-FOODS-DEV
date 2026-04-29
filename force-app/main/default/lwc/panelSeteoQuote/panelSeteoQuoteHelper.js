import { ShowToastEvent } from 'lightning/platformShowToastEvent';
const helper = {
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

    initializeColumns: () => {
        return [
            { label: 'SKU', fieldName: 'sku', type: 'text', initialWidth: 120 },
            { label: 'UMV', fieldName: 'umv', type: 'text', initialWidth: 80 },
            { label: 'Descripción', fieldName: 'descripcion', type: 'text', initialWidth: 300, wrapText: true },
            { label: '% Autónomo', fieldName: 'descuentoAutonomo', type: 'number', typeAttributes: { minimumFractionDigits: 2 }, cellAttributes: { alignment: 'left'}, initialWidth: 120 },
            { label: 'Lista de Precio', fieldName: 'listaPrecio', type: 'number', typeAttributes: { maximumFractionDigits: 2 }, cellAttributes: { alignment: 'left'}, initialWidth: 140 },
            { label: 'Descuento %', fieldName: 'descuento', type: 'number', typeAttributes: { minimumFractionDigits: 2 }, editable: true, cellAttributes: { alignment: 'left'}, initialWidth: 120 },
            { label: 'Precio Cliente Neto', fieldName: 'precioClienteNeto', type: 'number', typeAttributes: { maximumFractionDigits: 2 }, editable: true, cellAttributes: { alignment: 'left'}, initialWidth: 160 },
            { label: '%MG', fieldName: 'margen', type: 'text', initialWidth: 100 },
            { label: 'MG Contribución x Kilo', fieldName: 'margenContribucionKilo', type: 'number', typeAttributes: { maximumFractionDigits: 0 }, cellAttributes: { alignment: 'left'}, initialWidth: 180 },
            { label: 'Fecha Vto de Descuento', fieldName: 'fechaVencimientoDescuento', type: 'date', editable: true, typeAttributes: {year: 'numeric', month: '2-digit', day:'2-digit'}, initialWidth: 180 }
        ];
    },

    calculateDescuento: (product) => {
        const listaPrecio = product.listaPrecio;
        const precioNeto = product.precioClienteNeto;
        if (listaPrecio === 0) {
            helper.showToast('error', 'El valor de lista no puede ser 0, ya que causaría una división por cero.', 'Error');
            return 0;
        }
        if (precioNeto == null) {
            return 0;
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
                type = 'info';
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