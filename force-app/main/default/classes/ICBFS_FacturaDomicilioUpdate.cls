/**
* @File Name : ICBFS_FacturaDomicilioUpdate.cls
* @Description :
* @Author : Sebastian Albornoz
* @Last Modified By :
* @Last Modified On : October 20, 2025
* @Modification Log :
*==============================================================================
* Ver | Date | Author | Modification
*==============================================================================
* 1.0 | October 20, 2025 |   | Initial Version
**/
public with sharing class ICBFS_FacturaDomicilioUpdate {
    public class InputWrapper {
        @InvocableVariable(label='Lista de Id de Facturas (opcional)')
        public List<Id> facturaIds;
    }

    @InvocableMethod(label='Actualizar Domicilio de Facturas desde Batch')
    public static void invokeBatch(List<InputWrapper> wrappers) {
        Set<Id> facturaIdSet = new Set<Id>();
        if (wrappers != null) {
            for (InputWrapper w : wrappers) {
                if (w.facturaIds != null) {
                    facturaIdSet.addAll(w.facturaIds);
                }
            }
        }
        System.debug(LoggingLevel.INFO, 'ICBFS_FacturaDomicilioUpdate.invokeBatch – Número de Ids de facturas recibidas = ' 
                    + facturaIdSet.size());

        // lanzamos el batch con filtro (si facturaIdSet vacío significa “todos” con dirección no nula)
        ICBFS_FacturaDomicilioBatch batchJob = new ICBFS_FacturaDomicilioBatch(facturaIdSet);
        Database.executeBatch(batchJob, 200);
    }
}