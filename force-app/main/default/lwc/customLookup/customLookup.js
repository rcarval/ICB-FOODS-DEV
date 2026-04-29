import lookUp from '@salesforce/apex/LookupController.search';
import { fireEvent, registerListener, unregisterAllListeners } from 'c/pubsub';
import { api, LightningElement, track, wire } from 'lwc';
 
 
export default class customLookUp extends LightningElement {
 
    @api pageRef = null;
    @api objName;
    @api iconName;
    @api filter = '';
    @api fieldValues;
    @api searchPlaceholder='Search...';
    @api defaultValue = null;
    @api disabled = false;
    @track selectedName;
    @track records;
    @track isValueSelected;
    @track blurTimeout;
    @api inputName;
    inputType = 'search';
    searchTerm;
    offset = 0;
    @track scrollRecord = [];
    //css
    @track boxClass = 'slds-combobox slds-dropdown-trigger slds-dropdown-trigger_click slds-has-focus';
    @track inputClass = '';
    @wire(lookUp, { searchTerm: '$searchTerm', myObject: '$objName', filter: '$filter', fieldValues: '$fieldValues', offset: '$offset' })
    wiredRecords({ error, data }) {
        if (data) {
            this.error = undefined;
            this.records = data;
            this.scrollRecord = this.scrollRecord != null ? this.scrollRecord.concat(this.records) : this.records;
            if (data.length == 1 && this.defaultValue == data[0].Id) {
                this.selectedName = data[0].Name;
                if(this.blurTimeout) {
                    clearTimeout(this.blurTimeout);
                }
                this.defaultValue = null;
            }
        } else if (error) {
            console.log(error);
            this.error = error;
            this.records = undefined;
        }
    }
 
    connectedCallback() {
        if(this.defaultValue) {
            this.searchTerm = this.defaultValue;
            this.isValueSelected = true;
        }
        if(this.disabled) {
            this.inputType='text';
        }
        else{
            this.inputType='search';
        }
    }
 
    handleOnScroll() {
        let limit = 5;
        const div = this.template.querySelector('[data-id="slds-scrollable"]');
        let counterOffset = this.offset + limit;
        if (div.scrollTop + div.clientHeight >= div.scrollHeight - 1 && this.scrollRecord.length >= counterOffset) {
            this.offset = counterOffset;
        }
    }
    handleClick() {
        if(!this.disabled) {
            this.searchTerm = '';
            this.defaultValue = null;
            this.inputClass = 'slds-has-focus';
            this.boxClass = 'slds-combobox slds-dropdown-trigger slds-dropdown-trigger_click slds-has-focus slds-is-open';
        }
    }
    onBlur() {
        this.blurTimeout = setTimeout(() =>  {this.boxClass = 'slds-combobox slds-dropdown-trigger slds-dropdown-trigger_click slds-has-focus'}, 300);
    }
 
    onSelect(event) {
        let selectedId = event.currentTarget.dataset.id;
        let selectedName = event.currentTarget.dataset.name;
        const valueSelectedEvent = new CustomEvent('lookupselected', {detail:  {label: selectedName, value: selectedId} });
        this.dispatchEvent(valueSelectedEvent);
        this.isValueSelected = true;
        this.selectedName = selectedName;

        // Dispatch custom event to notify parent about value selection
        const valueChangedEvent = new CustomEvent('valueselectedchange', { detail: this.isValueSelected });
        this.dispatchEvent(valueChangedEvent);

        if(this.blurTimeout) {
            clearTimeout(this.blurTimeout);
        }
        this.boxClass = 'slds-combobox slds-dropdown-trigger slds-dropdown-trigger_click slds-has-focus';
    }
 
    handleRemovePill() {
        this.isValueSelected = false;

        // Dispatch custom event to notify parent that the value has been removed
        const valueChangedEvent = new CustomEvent('valueselectedchange', { detail: this.isValueSelected });
        this.dispatchEvent(valueChangedEvent);
    }
 
    onChange(event) {
        this.searchTerm = event.target.value;
        this.scrollRecord = [];
    
        if (this.searchTerm === '') {
            fireEvent(this.pageRef, 'contactInputCleared', this.inputName);
            this.isValueSelected = false;

            // Dispatch event to parent.
            const valueChangedEvent = new CustomEvent('valueselectedchange', { detail: this.isValueSelected });
            this.dispatchEvent(valueChangedEvent);
        }
    }
}