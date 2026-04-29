@isTest
private class DeleteVentasYDetallesTest {

    // Método auxiliar para crear datos de prueba
    private static void createTestData() {
        // Crear cliente obligatorio con nombre único
        Account cliente = new Account(
            Name = 'Cliente Test ' + System.currentTimeMillis()
        );
        insert cliente;

        // Crear ventas viejas asociadas al cliente
        List<Venta__c> ventas = new List<Venta__c>();
        for (Integer i = 0; i < 3; i++) {
            ventas.add(new Venta__c(
                Cliente__c = cliente.Id,
                Fecha_de_Venta__c = Date.today().addDays(-20)
            ));
        }
        insert ventas;

        // Crear detalles asociados a las ventas
        List<Detalle__c> detalles = new List<Detalle__c>();
        for (Venta__c v : ventas) {
            detalles.add(new Detalle__c(
                Venta__c = v.Id
            ));
        }
        insert detalles;
    }

    @isTest
    static void testBatchDeleteDetalles() {
        createTestData();
        Test.startTest();
        Database.executeBatch(new BatchDeleteDetalles(), 200);
        Test.stopTest();
        System.assertEquals(0, [SELECT COUNT() FROM Detalle__c]);
    }

    @isTest
    static void testBatchDeleteVentas() {
        createTestData();
        Test.startTest();
        Database.executeBatch(new BatchDeleteVentas(), 200);
        Test.stopTest();
        System.assertEquals(0, [SELECT COUNT() FROM Venta__c]);
    }

    @isTest
    static void testScheduledDeleteVentas() {
        createTestData();
        Test.startTest();
        new ScheduledDeleteVentas().execute(null);
        new ScheduledDeleteSoloVentas().execute(null);
        Test.stopTest();
        System.assertEquals(0, [SELECT COUNT() FROM Detalle__c]);
        System.assertEquals(0, [SELECT COUNT() FROM Venta__c]);
    }

    @isTest
    static void testScheduledDeleteSoloVentas() {
        createTestData();
        Test.startTest();
        new ScheduledDeleteSoloVentas().execute(null);
        Test.stopTest();
        System.assertEquals(0, [SELECT COUNT() FROM Venta__c]);
    }

    @isTest
    static void testFlujoCompleto() {
        createTestData();
        Test.startTest();
        new ScheduledDeleteVentas().execute(null);
        new ScheduledDeleteSoloVentas().execute(null);
        Test.stopTest();
        System.assertEquals(0, [SELECT COUNT() FROM Detalle__c]);
        System.assertEquals(0, [SELECT COUNT() FROM Venta__c]);
    }
}