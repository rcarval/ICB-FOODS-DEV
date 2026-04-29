@isTest
private class SyncVisibleAndActiveTest {
    
    @isTest
    static void testSyncVisibleAndActive_Insert() {
        // Crear un producto con Visible_For_Sales__c en true
        Product2 newProduct = new Product2(
            Name = 'Test Product',
            codigo__C = 'TP001',
            Visible_For_Sales__c = true
        );
        
        // Insertar el producto
        insert newProduct;

        // Recuperar el producto de la base de datos
        Product2 insertedProduct = [SELECT Id, Visible_For_Sales__c, IsActive FROM Product2 WHERE Id = :newProduct.Id];

        // Verificar que IsActive se haya sincronizado con Visible_For_Sales__c
        System.assertEquals(insertedProduct.Visible_For_Sales__c, insertedProduct.IsActive, 'isActive no se sincronizó correctamente en inserción');
    }

    @isTest
    static void testSyncVisibleAndActive_Update() {
        // Crear e insertar un producto inicialmente con Visible_For_Sales__c en false
        Product2 existingProduct = new Product2(
            Name = 'Test Product 2',
            codigo__C = 'TP002',
            Visible_For_Sales__c = false
        );
        
        insert existingProduct;

        // Actualizar Visible_For_Sales__c a true
        existingProduct.Visible_For_Sales__c = true;
        update existingProduct;

        // Recuperar el producto actualizado
        Product2 updatedProduct = [SELECT Id, Visible_For_Sales__c, IsActive FROM Product2 WHERE Id = :existingProduct.Id];

        // Verificar que IsActive se haya actualizado correctamente
        System.assertEquals(updatedProduct.Visible_For_Sales__c, updatedProduct.IsActive, 'isActive no se sincronizó correctamente en actualización');
    }
}