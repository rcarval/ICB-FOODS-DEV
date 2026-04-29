import { LightningElement, api, track } from 'lwc';
import getPricebookId from '@salesforce/apex/MaestraPreciosController.getPricebookId';
import getProductInfo from '@salesforce/apex/MaestraPreciosController.fetchPricebookEntryById';
import crearQuote from '@salesforce/apex/MaestraPreciosController.crearQuote';

export default class PanelSeteoSingle extends LightningElement  {
    @api title;
    @api iconName;
    @api recordId;
    @track product;
    @track productDataDraft = [];
    pricebookId;
    filter;
    displayInfo;
    matchingInfo;
    showProductInfo = false;
    disableProductPicker = true;

    connectedCallback() {
        getPricebookId({ accountId: this.recordId })
            .then((result) => {
                this.pricebookId = result;
                this.setFilter();
                this.setDisplayInfo();
                this.setMatchingInfo();
                this.disableProductPicker = false;
            })
            .catch((error) => {
                //helper.showToast('error', error.body.message, 'Error al crear Quote');
                console.error('Error en pricebookId:', error);
                //this.showSpinner = false;
            });
    }

    setFilter() {
        this.filter = {
            criteria: [
                {
                    fieldPath: 'Pricebook2Id',
                    operator: 'eq',
                    value: this.pricebookId
                },
                {
                    fieldPath: 'IsActive',
                    operator: 'eq',
                    value: true
                }
            ]
        }
    }

    setDisplayInfo() {
        this.displayInfo = {
            primaryField: 'Name',
            additionalFields: [ 'Product2.SKU_mas_UMV__c' ]
        }
    }

    setMatchingInfo() {
        this.matchingInfo = {
            primaryField: { fieldPath: 'Name' },
            additionalFields: [ { fieldPath: 'Product2.SKU_mas_UMV__c' } ]
        }
    }

    handleChange(event) {
        const selectedProductId = event.detail.recordId;
        console.log('selected product id: ' + selectedProductId);
        
        if (selectedProductId == '' || selectedProductId == null) {
            this.showProductInfo = false;
        } else {
            getProductInfo({ accountId: this.recordId, pricebookEntryId: selectedProductId })
                .then((result) => {
                    const resultMap = result.map(item => ({ ...item }));
                    this.product = resultMap[0];
                    this.showProductInfo = true;

                })
                .catch((error) => {
                    //helper.showToast('error', error.body.message, 'Error al crear Quote');
                    console.log('Error al buscar producto:', error);
                    //this.showSpinner = false;
                });
        }
    }

    handlePrecioClienteNeto(event) {
        try {
            console.log('entrando a handler de precio neto');
            let value = event.target.value;
            this.product.precioClienteNeto = value;
            this.calculateDescuento();
            this.calculateMargen();
            this.calculateKilo();
        } catch (error) {
            console.log(error);
        }
    }

    handleDescuento(event) {
        try {
            let value = event.target.value;
            this.product.descuento = value;
            this.calculatePrecioNeto();
            this.calculateMargen();
            this.calculateKilo();
        } catch (error) {
            console.log(error);
        }
    }

    fechaVencimientoDescuento(event) {
        let value = event.target.value;
        this.product.fechaVencimientoDescuento = value;
    }

    calculateDescuento(){
        const product = this.product;
        const listaPrecio = product.listaPrecio;
        const precioNeto = product.precioClienteNeto;
        if (listaPrecio === 0) {
            // TODO: show toast
            console.log('error, el valor no puede ser 0');
        }
        if (precioNeto == null) {
            precioNeto = 0;
        }
        const descuento = ((listaPrecio - precioNeto) * 100) / listaPrecio;
        product.descuento = descuento.toFixed(2);
        this.product = product;
    }

    calculatePrecioNeto() {
        const product = this.product;
        const precioLista = product.listaPrecio;
        const descuento = product.descuento != null ? product.descuento : 0;
        const rappel = product.rappel;
        let total = 0;
        if (rappel != null) {
            const totalBeforeRappel = precioLista - ((precioLista * descuento) / 100);
            total = totalBeforeRappel + ((totalBeforeRappel * rappel) / 100);
        } else {
            total = precioLista - ((precioLista * descuento) / 100);
        }
        product.precioClienteNeto = total.toFixed(2);
        this.product = product;
    }

    calculateMargen() {
        const product = this.product;
        let margen = 0;
        if (product.costo == null || product.costo == undefined || product.costo == 0) {
            margen = 0;
        } else if (product.rappel != null) {
            const rappelAplicado = Number(product.precioClienteNeto) * (product.rappel / 100);
            const precioConRappel = Number(product.precioClienteNeto) + rappelAplicado;
            margen = ((precioConRappel - product.costo) / precioConRappel) * 100;
            margen = margen.toFixed(2).toString();
        } else {
            margen = ((product.precioClienteNeto - product.costo) / product.precioClienteNeto) * 100;
            margen = margen.toFixed(2).toString();
        }
        product.margen = margen;
        this.product = product;
    }

    calculateKilo() {
        const product = this.product;
        let margenKilo = 0;
        if (product.costo == null) {
            // show error toast
            //this.showToast('Error', 'El producto no tiene costo, no se pueden calcular los margenes', 'error');
        }
        if (product.peso != null) {
            margenKilo = ((product.precioClienteNeto - product.costo) / product.peso);
        }
        product.margenContribucionKilo = margenKilo.toFixed(2);
        this.product = product;
    }

    showToast(title, message, variant) {
        const event = new ShowToastEvent({
            title: title,
            message: message,
            variant: variant // success, error, warning, info
        });
        this.dispatchEvent(event);
    }

    handleAdd() {
        // Crear una copia del producto actual
        const currentProduct = { ...this.product };

        // Verificar si el producto ya existe en productDataDraft
        const index = this.productDataDraft.findIndex(item => item.id === currentProduct.id);

        if (index !== -1) {
            // Reemplazar el producto existente
            this.productDataDraft = [
                ...this.productDataDraft.slice(0, index), 
                currentProduct,
                ...this.productDataDraft.slice(index + 1)
            ];
        } else {
            // Agregar el producto al final de la lista
            this.productDataDraft = [...this.productDataDraft, currentProduct];
        }

        this.product = {}; // Resetear valores de producto

        // Mostrar un toast de confirmación
        //showToast('Éxito', 'El producto ha sido añadido.', 'success');
    }

    handleSet() {
        // Formatear items antes de enviar a Apex.
        this.productDataDraft = this.productDataDraft.map((item) => {
            let parsedMargin = parseFloat(item.margen);
            if (isNaN(parsedMargin)) {
                parsedMargin = 0;
            }
            return {
                ...item,
                margen: parsedMargin, // Actualiza 'margen' con el valor numérico
            };
        });

        const registrosUnificadosJSON = JSON.parse(JSON.stringify(this.productDataDraft));
        //this.showSpinner = true;
        //showToast('info', 'Pronto se redireccionará...', 'Creando Quote...');
        crearQuote({ status: 'Approved', registrosUnificados: registrosUnificadosJSON, accountId: this.recordId, fugadosParaPersistir: [] })
            .then((result) => {
                //showToast('success', 'Redireccionando...', 'Quote creada!');
                this.redirectToQuote(result.Id);
            })
            .catch((error) => {
                //showToast('error', error.body.message, 'Error al crear Quote');
                console.error('Error al redireccionar:', error);
                //this.showSpinner = false;
            });

        this.showProductInfo = false;
    }


    redirectToQuote(quoteId) {
        const quoteUrl = `/lightning/r/Quote/${quoteId}/view`;
        window.location.href = quoteUrl;
    }
}