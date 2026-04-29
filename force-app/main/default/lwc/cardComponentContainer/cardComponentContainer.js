import { LightningElement, track, api, wire } from 'lwc';
import { NavigationMixin, CurrentPageReference } from 'lightning/navigation';
import buscarPricebookCliente from '@salesforce/apex/MaestraPreciosController.getPricebookId';

const RECORD_TYPE = 'Negocio';

export default class CardComponent extends NavigationMixin(LightningElement) {
    @wire(CurrentPageReference) pageRef;
    @api title = 'Default Title';
    @api iconName = 'custom:custom14';
    @track selectedAccountId;
    @track isAccountSelected = false;
    @track isModalOpen = false; // Track modal visibility.
    @track recordData; // Track the added records.
    @track clientePricebook; // To store the found Pricebook
    @track whereClause = '';
    accountName = '';

    accountFieldValues = {
        'RecordType.DeveloperName': [RECORD_TYPE]
    };

    handleSelectedAccount(event) {
        const selectedAccount = event.detail;
        this.selectedAccountId = selectedAccount.value;
        this.accountName = selectedAccount.label;
    }

    handleValueSelectedChange(event) {
        this.isAccountSelected = event.detail;
    }

    handleDataChange(event) {
        this.recordData = event.detail;
    }

    openModal() {
        this.isModalOpen = true; // Open the modal
    }

    closeModal() {
        this.isModalOpen = false; // Close the modal
    }

    handleModalContinue() {
        this.closeModal();
        this.handleNavigate();
    }

    buscarPricebookCliente() {
        if (this.selectedAccountId) {
            buscarPricebookCliente({ accountId: this.selectedAccountId })
                .then((result) => {
                    if (result) {
                        this.clientePricebook = result;
                        this.whereClause = `Pricebook2.Id = '${result.Id}'`;
                        console.log('Pricebook encontrada:', result.Name);
                    } else {
                        console.log('No se encontró la Pricebook.');
                    }
                })
                .catch((error) => {
                    console.error('Error al buscar la Pricebook:', error);
                });
        } else {
            console.log('No hay ninguna cuenta seleccionada para buscar la Pricebook.');
        }
    }

    handleNavigate() {
        try {
            const compDefinition = {
                componentDef: "c:panelSeteo",
                attributes: {
                    accountIdValue: this.selectedAccountId,
                    accountName: this.accountName,
                    initialProductData: this.recordData.recordData,
                    shouldFilter: false,
                    shouldHideButton: true
                }
            };
            // Base64 encode the compDefinition JS object
            const encodedCompDef = btoa(JSON.stringify(compDefinition));
            this[NavigationMixin.Navigate]({
                type: 'standard__webPage',
                attributes: {
                    url: '/one/one.app#' + encodedCompDef
                }
            });
        } catch (error) {
            const proxy = new Proxy(error, {get: (target, key) => {return target[key];}})
            console.log(JSON.stringify(proxy));
        }
    }
}