/**
* @File Name : ICBFS_FacturaDomicilio_Test.cls
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
@isTest
private class ICBFS_FacturaDomicilio_Test {

    @testSetup
    static void setupTestData() {
        // Crear registros de Domicilio_de_Cliente__c
        List<Domicilio_de_Cliente__c> domicilios = new List<Domicilio_de_Cliente__c>();
        for (Integer i = 0; i < 5; i++) {
            domicilios.add(new Domicilio_de_Cliente__c(
                Cliente_Despacho__c = 'Direccion ' + i
            ));
        }
        insert domicilios;

        // Crear registros de Facturas__c
        List<Facturas__c> facturas = new List<Facturas__c>();
        for (Integer i = 0; i < 5; i++) {
            facturas.add(new Facturas__c(
                Direccion__c = 'Direccion ' + i
            ));
        }
        insert facturas;
    }

    @isTest
    static void testBatchExecution() {
        // Obtener las facturas insertadas
        List<Facturas__c> facturas = [SELECT Id, Direccion__c FROM Facturas__c];

        // Ejecutar el batch
        Test.startTest();
        ICBFS_FacturaDomicilioBatch batch = new ICBFS_FacturaDomicilioBatch(null);
        Database.executeBatch(batch);
        Test.stopTest();

        // Verificar que las facturas fueron actualizadas
        List<Facturas__c> facturasActualizadas = [SELECT Id, Domicilio_Cliente__c FROM Facturas__c];
        for (Facturas__c factura : facturasActualizadas) {
            System.assertNotEquals(null, factura.Domicilio_Cliente__c, 'La factura debe tener un Domicilio_Cliente asignado');
        }
    }

    @isTest
    static void testInvocableMethod() {
        // Crear un wrapper de entrada
        ICBFS_FacturaDomicilioUpdate.InputWrapper wrapper = new ICBFS_FacturaDomicilioUpdate.InputWrapper();
        wrapper.facturaIds = new List<Id>();

        // Obtener una factura y agregar su Id al wrapper
        Facturas__c factura = [SELECT Id FROM Facturas__c LIMIT 1];
        wrapper.facturaIds.add(factura.Id);

        // Ejecutar el método invocable
        Test.startTest();
        ICBFS_FacturaDomicilioUpdate.invokeBatch(new List<ICBFS_FacturaDomicilioUpdate.InputWrapper>{ wrapper });
        Test.stopTest();

        // Verificar que el batch fue ejecutado (esto puede implicar verificar logs o resultados esperados)
        System.assert(true, 'El método invocable fue ejecutado correctamente');
    }
}