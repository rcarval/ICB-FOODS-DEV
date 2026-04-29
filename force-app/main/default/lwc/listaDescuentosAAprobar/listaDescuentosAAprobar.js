import { api, wire, LightningElement } from 'lwc';
import { getFieldValue, getRecords } from "lightning/uiRecordApi";
import{ refreshApex } from '@salesforce/apex';
import ESTADO_MEDIOCAMPO_FIELD from "@salesforce/schema/Pendiente_aprobaci_n__c.Estado_mediocampo__c";
import ESTADO_SUBGERENT_FIELD from "@salesforce/schema/Pendiente_aprobaci_n__c.Estado_Subgerente__c";
import COMENTARIO_FIELD from "@salesforce/schema/Pendiente_aprobaci_n__c.Comentario__c";
import SKU_FIELD from "@salesforce/schema/Pendiente_aprobaci_n__c.Formula_SKU__c";
import UMV_FIELD from "@salesforce/schema/Pendiente_aprobaci_n__c.UMV__c";
import DESCRIPCION_FIELD from "@salesforce/schema/Pendiente_aprobaci_n__c.Descripcion_Producto__c";
import PRECIO_LISTA_FIELD from "@salesforce/schema/Pendiente_aprobaci_n__c.Precio_Lista__c";
import DESC_SOLICITADO_FIELD from "@salesforce/schema/Pendiente_aprobaci_n__c.Descuento_Solicitado__c";
import PRECIO_DESC_FIELD from "@salesforce/schema/Pendiente_aprobaci_n__c.Precio_con_Descuento__c";
import MARGEN_PROD_FIELD from "@salesforce/schema/Pendiente_aprobaci_n__c.Margen_Producto__c";
import CONTRIBUCION_PESO_FIELD from "@salesforce/schema/Pendiente_aprobaci_n__c.Contribucion_Peso__c";
import FECHA_DESDE_FIELD from "@salesforce/schema/Pendiente_aprobaci_n__c.Fecha_desde__c";
import FECHA_HASTA_FIELD from "@salesforce/schema/Pendiente_aprobaci_n__c.Fecha_hasta__c";

const columns = [
    { label: "Comentario" , fieldName: "Comentario__c", cellAttributes: { alignment: 'left' }},
    { label: "SKU" , fieldName: "Formula_SKU__c", cellAttributes: { alignment: 'left' } },
    { label: "UMV" , fieldName: "UMV__c", cellAttributes: { alignment: 'left' } },
    { label: "Descripcion Producto" , fieldName: "Descripcion_Producto__c", type: 'text', wrapText: true, cellAttributes: { alignment: 'left' } },
    { label: "Lista de Precio" , fieldName: "Precio_Lista__c", type: "text", cellAttributes: { alignment: 'left' },
        typeAttributes: { 
            maximumFractionDigits: '0'
        } 
    },
    { label: "Descuento%" , fieldName: "Descuento_Solicitado__c", type: 'percent',
        typeAttributes: { 
            step: '0.00001', minimumFractionDigits: '2', maximumFractionDigits: '2'
        },
        cellAttributes: {
            class: {
                fieldName: `format`
            },
            alignment: 'left' 
        }
    },
    { label: "Precio Cliente Neto" , fieldName: "Precio_con_Descuento__c", type: "number", cellAttributes: { alignment: 'left' },
        typeAttributes: { 
            maximumFractionDigits: '0'
        }
    },
    { label: "%MG" , fieldName: "Margen_Producto__c", cellAttributes: { alignment: 'left' } },
    { label: "MG Contribución x kilo" , fieldName: "Contribucion_Peso__c" , cellAttributes: { alignment: 'left' }},
    { label: "Fecha Inicio Descuento" , fieldName: "Fecha_desde__c" , type: 'date', 
        cellAttributes: { alignment: 'left' },
        typeAttributes:{
            weekday: "short",
            year: "numeric",
            month: "2-digit",
            day: "2-digit",
        }
    },
    { label: "Fecha Termino Descuento" , fieldName: "Fecha_hasta__c" , type: 'date', 
        cellAttributes: { alignment: 'left' },
        typeAttributes:{
            weekday: "short",
            year: "numeric",
            month: "2-digit",
            day: "2-digit",
        }
    }
];

export default class ListaDescuentosAAprobar extends LightningElement {
    _recordIds = [];
    _varRoleName;
    parameterObject;

    @api descuentosActualizados = [];
    @api 
    get varRolName(){
        return this._varRoleName;
    }

    set varRolName(value){
        this._varRoleName = value;
        let cols = [...columns];
        if(!(value.includes('sesor') || value == null)){
            if(value.includes('Medio')){
                cols.unshift({ label: 'Aprobar o Rechazar', fieldName: 'Estado_mediocampo__c', cellAttributes: { alignment: 'left'}});
            } else if (value.includes('SubGerente')){
                cols.unshift({ label: 'Aprobar o Rechazar', fieldName: 'Estado_Subgerente__c', cellAttributes: { alignment: 'left'}});
            }
            this.showTable = true;
        } else {
            this.showTable = false;
        }

        this.columns = cols;
    }

    @api get recordIds(){
        return this._recordIds;
    }
    
    set recordIds(ids){
        this._recordIds = ids;
        this.parameterObject = [];

        if(ids.length > 0){
            this.parameterObject.push({
                recordIds: ids,
                fields: [
                    ESTADO_MEDIOCAMPO_FIELD,ESTADO_SUBGERENT_FIELD,COMENTARIO_FIELD,SKU_FIELD,UMV_FIELD,DESCRIPCION_FIELD,PRECIO_LISTA_FIELD,
                    DESC_SOLICITADO_FIELD, PRECIO_DESC_FIELD,MARGEN_PROD_FIELD,CONTRIBUCION_PESO_FIELD,
                    FECHA_DESDE_FIELD,FECHA_HASTA_FIELD
                ],                
            });
        } 
    }
    data = [];
    columns;
    renderAprobarFlow = false;
    renderRechazarFlow = false;
    selectedRows;
    descuentos;
    inputVariables;
    comentario;
    showTable;
    hasRender = false;
    updatedRows = [];

    @wire(getRecords, {
        records: '$parameterObject',
      })
    getDescuentos(response){
        this.descuentos = response;
        let newData = [];
        if(response.data){
            response.data.results.forEach(record => {
                let desc = {  
                    Comentario__c: getFieldValue(record.result, COMENTARIO_FIELD),
                    Formula_SKU__c: getFieldValue(record.result, SKU_FIELD),
                    UMV__c: getFieldValue(record.result, UMV_FIELD),
                    Descripcion_Producto__c: getFieldValue(record.result, DESCRIPCION_FIELD),
                    Precio_Lista__c: getFieldValue(record.result, PRECIO_LISTA_FIELD),
                    Descuento_Solicitado__c: (getFieldValue(record.result, DESC_SOLICITADO_FIELD) / 100),
                    Precio_con_Descuento__c: getFieldValue(record.result, PRECIO_DESC_FIELD),
                    Margen_Producto__c: getFieldValue(record.result, MARGEN_PROD_FIELD),
                    Contribucion_Peso__c: getFieldValue(record.result, CONTRIBUCION_PESO_FIELD),
                    Fecha_desde__c: getFieldValue(record.result, FECHA_DESDE_FIELD),
                    Fecha_hasta__c: getFieldValue(record.result, FECHA_HASTA_FIELD),
                    Id: record.result.id,
                    format: getFieldValue(record.result, DESC_SOLICITADO_FIELD) > 50 ? 'slds-text-color_error' : ''
                };
                if(this.varRolName.includes('Medio')){
                    desc.Estado_mediocampo__c = getFieldValue(record.result, ESTADO_MEDIOCAMPO_FIELD);
                } else if (this.varRolName.includes('SubGerente')){
                    desc.Estado_Subgerente__c = getFieldValue(record.result, ESTADO_SUBGERENT_FIELD);
                }
                newData.push(desc);
            });

            this.data = newData;
        }
    };


    handleSelectedRow(event){
        this.selectedRows = event.detail.selectedRows
    }

    handleChange(event) {
        this.comentario = event.detail.value;
    }

    handleApprove(event){
        // let updatedRows = [];
        let data = [...this.data];
        this.selectedRows.forEach(row => {
            let indexData =  data.indexOf(row);
            if(this.varRolName.includes('Medio')){
                row.Estado_mediocampo__c = 'Aprobado';            
            } else if (this.varRolName.includes('SubGerente')){
                row.Estado_Subgerente__c = 'Aprobado';
            }

            let r = {...row, Descuento_Solicitado__c: row.Descuento_Solicitado__c * 100, Comentario__c : this.comentario };
            
            row.Comentario__c = this.comentario

            let index = this.descuentosActualizados.indexOf(this.descuentosActualizados.find(item => item.Id == r.Id));
            if (index != -1){
                this.descuentosActualizados[index] = r;
            } else {
                this.descuentosActualizados.push(r);
            }

            data[indexData] = row;
        });
                
        this.data = data;
        this.template.querySelector('lightning-datatable').selectedRows = [];
        this.comentario = undefined;
    }

    handleReject(event){
        // let updatedRows = [];
        let data = [...this.data];
        this.selectedRows.forEach(row => {
            let indexData =  data.indexOf(row);
            if(this.varRolName.includes('Medio')){
                row.Estado_mediocampo__c = 'Rechazado';            
            } else if (this.varRolName.includes('SubGerente')){
                row.Estado_Subgerente__c = 'Rechazado';
            }
            let r = {...row, Descuento_Solicitado__c: row.Descuento_Solicitado__c * 100, Comentario__c : this.comentario };
            
            row.Comentario__c = this.comentario

            let index = this.descuentosActualizados.indexOf(this.descuentosActualizados.find(item => item.Id == r.Id));
            if (index != -1){
                this.descuentosActualizados[index] = r;
            } else {
                this.descuentosActualizados.push(r);
            }

            data[indexData] = row;
        });
                
        this.data = data;
        this.template.querySelector('lightning-datatable').selectedRows = [];
        this.comentario = undefined;
    }
}