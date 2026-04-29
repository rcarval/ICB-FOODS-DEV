import LightningDatatable from 'lightning/datatable';
import motivoPicklistTemplate from './motivoPicklist.html';
import motivoPicklistEditTemplate from './motivoPicklistEdit.html';

export default class PanelSeteoDatatable extends LightningDatatable {
    static customTypes = {
        ...LightningDatatable.customTypes,
        motivoPicklist: {
            template: motivoPicklistTemplate,
            editTemplate: motivoPicklistEditTemplate,
            standardCellLayout: true,
            typeAttributes: ['options', 'context', 'fieldName']
        }
    };
}