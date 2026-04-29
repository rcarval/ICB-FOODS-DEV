@isTest
private class ICBFS_GeocodeUpdateTest {
    
    @isTest
    static void testAplicarGeocodingARegistros_Success() {
        // Crear domicilio de prueba
        Domicilio_de_Cliente__c dom = new Domicilio_de_Cliente__c(
			Domicilio_Adicional__City__s = 'Rancagua',
            Domicilio_Adicional__PostalCode__s = '2820000',
			//Domicilio_Adicional__StateCode__s = '',
            Domicilio_Adicional__Street__s  = 'San Joaquin de los mayos'
        );
        insert dom;

        // Crear request simulando datos de geocodificación
        ICBFS_GeocodeUpdate.GeocodeUpdateRequest req = new ICBFS_GeocodeUpdate.GeocodeUpdateRequest();
        req.domicilioId = dom.Id;
        req.latitude = -33.45;
        req.longitude = -70.666;

        List<ICBFS_GeocodeUpdate.GeocodeUpdateRequest> reqs = new List<ICBFS_GeocodeUpdate.GeocodeUpdateRequest>{ req };

        Test.startTest();
        ICBFS_GeocodeUpdate.aplicarGeocodingARegistros(reqs);
        Test.stopTest();

        // Validar que los campos se actualizaron correctamente
        Domicilio_de_Cliente__c updated = [SELECT Latitud__c, Longitud__c
                                           FROM Domicilio_de_Cliente__c WHERE Id = :dom.Id];
        System.assertEquals(String.valueOf(-33.45), updated.Latitud__c, 'Latitud actualizada');
        System.assertEquals(String.valueOf(-70.666), updated.Longitud__c, 'Longitud actualizada');
    }

    @isTest
    static void testAplicarGeocodingARegistros_EmptyList() {
        // Llamada sin datos
        Test.startTest();
        ICBFS_GeocodeUpdate.aplicarGeocodingARegistros(new List<ICBFS_GeocodeUpdate.GeocodeUpdateRequest>());
        Test.stopTest();

        // No debería lanzar excepción
        System.assert(true, 'Debe ejecutarse sin errores');
    }
}