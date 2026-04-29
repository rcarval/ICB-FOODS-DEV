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

    initializeColumns: () => {
        return [
            { 
                label: 'SKU', 
                fieldName: 'sku', 
                type: 'text', 
                initialWidth: 100,
                sortable: true 
            },
            { 
                label: 'UMV', 
                fieldName: 'umv', 
                type: 'text', 
                initialWidth: 80,
                sortable: true 
            },
            { 
                label: 'Descripción', 
                fieldName: 'descripcion', 
                type: 'text', 
                initialWidth: 350,
                sortable: true 
            },
            { 
                label: 'Fugados', 
                fieldName: 'fugadoDisplay', 
                type: 'text', 
                initialWidth: 130,
                sortable: true,
                cellAttributes: { class: { fieldName: 'fugadoDisplayClass' } }
            },
            { 
                label: 'Lista de Precio', 
                fieldName: 'listaPrecioFormatted', 
                type: 'text', 
                initialWidth: 150, 
                cellAttributes: { alignment: 'right' },
                sortable: true 
            },
            { 
                label: 'Fecha Vigencia', 
                fieldName: 'fechaMaximaOriginal', 
                type: 'date', 
                initialWidth: 150, 
                typeAttributes: { day: '2-digit', month: '2-digit', year: 'numeric', weekday: undefined },
                sortable: true 
            },
            { 
                label: 'Descuento %', 
                fieldName: 'descuentoFormatted', 
                type: 'text', 
                initialWidth: 140, 
                cellAttributes: { alignment: 'right' },
                sortable: true 
            },
            { 
                label: 'Precio Cliente Neto', 
                fieldName: 'precioClienteNetoFormatted', 
                type: 'text', 
                initialWidth: 180, 
                cellAttributes: { alignment: 'right' },
                sortable: true 
            },
            { 
                label: 'Rappel', 
                fieldName: 'rappelFormatted', 
                type: 'text', 
                initialWidth: 100, 
                cellAttributes: { alignment: 'right' },
                sortable: true 
            },
            { 
                label: '%MG', 
                fieldName: 'margenFormatted', 
                type: 'text', 
                initialWidth: 100, 
                cellAttributes: { alignment: 'right' },
                sortable: true 
            },
            { 
                label: 'MG Contribución x Kilo', 
                fieldName: 'margenContribucionKiloFormatted', 
                initialWidth: 200, 
                type: 'text', 
                cellAttributes: { alignment: 'right' },
                sortable: true 
            },
        ];
    },

    transformarDatos: (productos) => {
        productos.forEach(producto => {
            // Mantener valores numéricos originales para ordenamiento
            producto.descuento = producto.descuento ? Number(producto.descuento) : 0;
            producto.margen = producto.margen ? Number(producto.margen) : 0;
            producto.margenContribucionKilo = producto.margenContribucionKilo ? Number(producto.margenContribucionKilo) : 0;
            producto.rappel = producto.rappel ? Number(producto.rappel) : 0;
            producto.listaPrecio = producto.listaPrecio ? Number(producto.listaPrecio) : 0;
            producto.precioClienteNeto = producto.precioClienteNeto ? Number(producto.precioClienteNeto) : 0;
            
            // Crear campos formateados para visualización
            // Lista de Precio y Precio Cliente Neto: no mostrar ,00 si no hay decimales
            producto.listaPrecioFormatted = helper.formatNumber(producto.listaPrecio, 2, false);
            producto.descuentoFormatted = helper.formatNumber(producto.descuento, 2);
            producto.precioClienteNetoFormatted = helper.formatNumber(producto.precioClienteNeto, 2, false);
            producto.rappelFormatted = helper.formatNumber(producto.rappel, 2);
            producto.margenFormatted = helper.formatNumber(producto.margen, 2);
            producto.margenContribucionKiloFormatted = helper.formatNumber(producto.margenContribucionKilo, 0);
            
            // Procesar descripción para asegurar correcta codificación UTF-8
            if (producto.descripcion) {
                try {
                    // Asegurar que el texto se interprete correctamente como UTF-8
                    producto.descripcion = decodeURIComponent(encodeURIComponent(producto.descripcion));
                } catch (e) {
                    // Si falla, mantener el texto original
                    console.warn('Error al procesar descripción:', e);
                }
            }
            
            // Procesar SKU también por si acaso
            if (producto.sku) {
                try {
                    producto.sku = decodeURIComponent(encodeURIComponent(String(producto.sku)));
                } catch (e) {
                    // Si falla, mantener el texto original
                }
            }

            // Fugados: Sí = fondo rojo texto blanco, No = fondo verde texto blanco (SLDS theme)
            producto.fugadoDisplay = producto.fugado ? 'Sí' : 'No';
            producto.fugadoDisplayClass = producto.fugado
                ? 'slds-theme--error slds-text-inverse slds-p-around_x-small slds-text-align_center'
                : 'slds-theme--success slds-text-inverse slds-p-around_x-small slds-text-align_center';
        });
    }
}

export { helper }