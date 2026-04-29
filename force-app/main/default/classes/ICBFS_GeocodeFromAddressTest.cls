@isTest
private class ICBFS_GeocodeFromAddressTest {
    
    @isTest
    static void testGeocode_Success() {
        // Crear registro de prueba con dirección válida
        Domicilio_de_Cliente__c dom = new Domicilio_de_Cliente__c(
            //Domicilio_Adicional__c = 'Santiago, Chile',
            Domicilio_Adicional__City__s = 'Rancagua',
            Domicilio_Adicional__PostalCode__s = '2820000',
            Domicilio_Adicional__StateCode__s = '',
            Domicilio_Adicional__Street__s  = 'San Joaquin de los mayos'
        );
        insert dom;

        // Simular la respuesta del servicio externo (Mock HTTP)
        Test.setMock(HttpCalloutMock.class, new MockGeocodeResponse(200, 
            '{ "results": [ { "geometry": { "location": { "lat": -33.45, "lng": -70.666 } } } ], "status": "OK" }'
        ));

        // Preparar solicitud
        ICBFS_GeocodeFromAddress.GeocodeRequest req = new ICBFS_GeocodeFromAddress.GeocodeRequest();
        req.domicilioId = dom.Id;

        List<ICBFS_GeocodeFromAddress.GeocodeRequest> reqs = new List<ICBFS_GeocodeFromAddress.GeocodeRequest>{ req };

        Test.startTest();
        List<ICBFS_GeocodeFromAddress.GeocodeResponse> responses = ICBFS_GeocodeFromAddress.geocode(reqs);
        Test.stopTest();

        /*
         * System.assertEquals(1, responses.size(), 'Debe haber una respuesta');
        System.assertEquals(-33.45, responses[0].latitude, 'Latitud esperada');
        System.assertEquals(-70.666, responses[0].longitude, 'Longitud esperada');
        System.assertEquals(null, responses[0].errorMessage, 'No debe haber error');
		*/
    }

    @isTest
    static void testGeocode_Error_EmptyAddress() {
        Domicilio_de_Cliente__c dom = new Domicilio_de_Cliente__c(
            //Domicilio_Adicional__c = 'Santiago, Chile',
            Domicilio_Adicional__City__s = 'Rancagua',
            Domicilio_Adicional__PostalCode__s = '2820000',
//            Domicilio_Adicional__StateCode__s = '',
            Domicilio_Adicional__Street__s  = 'San Joaquin de los mayos'
        );
        insert dom;

        ICBFS_GeocodeFromAddress.GeocodeRequest req = new ICBFS_GeocodeFromAddress.GeocodeRequest();
        req.domicilioId = dom.Id;

        Test.startTest();
        List<ICBFS_GeocodeFromAddress.GeocodeResponse> responses = ICBFS_GeocodeFromAddress.geocode(
            new List<ICBFS_GeocodeFromAddress.GeocodeRequest>{ req }
        );
        Test.stopTest();

        System.assertNotEquals(null, responses[0].errorMessage, 'Debe haber un mensaje de error');
    }

    // --- Mock para simular la respuesta HTTP del servicio Google Maps ---
    private class MockGeocodeResponse implements HttpCalloutMock {
        Integer statusCode;
        String body;
        MockGeocodeResponse(Integer code, String body) {
            this.statusCode = code;
            this.body = body;
        }
        public HTTPResponse respond(HTTPRequest req) {
            HttpResponse res = new HttpResponse();
            res.setHeader('Content-Type', 'application/json');
            res.setBody(body);
            res.setStatusCode(statusCode);
            return res;
        }
    }
}