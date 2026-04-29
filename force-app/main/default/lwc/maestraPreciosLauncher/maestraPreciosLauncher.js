import { LightningElement, api, wire } from 'lwc';
import { getRecord } from 'lightning/uiRecordApi';
import { NavigationMixin } from 'lightning/navigation';
import ACCOUNT_NAME_FIELD from '@salesforce/schema/Account.Name';

export default class maestraPreciosLauncher extends NavigationMixin(LightningElement) {
    @api recordId; 
    @api accountName;

    //Wire para obtener datos de la cuenta
    @wire(getRecord, { recordId: '$recordId', fields: [ACCOUNT_NAME_FIELD] })
    wiredAccount({ error, data }) {
        if (data) {
            this.accountName = data.fields.Name.value;
            this.handleNavigate(); // Navega al usuario automaticamente al LWC de la Maestra
        } else if (error) {
            console.error('Error al recuperar la cuenta:', error);
        }
    }

    handleNavigate() {
        const compDefinition = {
            componentDef: "c:maestraPrecios",
            attributes: {
                accountIdValue: this.recordId,
                accountName: this.accountName
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
    }
}