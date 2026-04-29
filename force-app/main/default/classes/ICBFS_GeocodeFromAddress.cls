public with sharing class ICBFS_GeocodeFromAddress {
    // Wrapper para recibir datos desde Flow
    public class GeocodeRequest {
        @InvocableVariable(label='Id del domicilio')
        public Id domicilioId;
    }
    // Wrapper para devolver latitud/longitud o error
    public class GeocodeResponse {
        @InvocableVariable(label='Latitud')
        public Double latitude;
        @InvocableVariable(label='Longitud')
        public Double longitude;
        @InvocableVariable(label='Mensaje de error (si lo hubo)')
        public String errorMessage;
    }

    @InvocableMethod(label='Geocodificar dirección de domicilio')
    public static List<GeocodeResponse> geocode(List<GeocodeRequest> requests) {
        System.debug('Geocode invoked with requests: ' + requests);
        List<GeocodeResponse> results = new List<GeocodeResponse>();
        // Recolectar los Ids para consulta
        Set<Id> domicilioIds = new Set<Id>();
        for (GeocodeRequest req : requests) {
            System.debug('Processing request for domicilioId: ' + req.domicilioId);
            if (req.domicilioId != null) {
                domicilioIds.add(req.domicilioId);
            }
        }
        System.debug('Domicilio Ids set: ' + domicilioIds);

        // Consulta de domicilios
        Map<Id, Domicilio_de_Cliente__c> mapDom = new Map<Id, Domicilio_de_Cliente__c>(
            [SELECT Id, Domicilio_Adicional__c FROM Domicilio_de_Cliente__c WHERE Id IN :domicilioIds]
        );
        System.debug('Domicilios fetched: ' + mapDom);

        for (GeocodeRequest req : requests) {
            GeocodeResponse resp = new GeocodeResponse();
            System.debug('Handling request: ' + req);

            if (req.domicilioId == null) {
                resp.errorMessage = 'Id de domicilio nulo';
                results.add(resp);
                System.debug('Error: ' + resp.errorMessage);
                continue;
            }
            Domicilio_de_Cliente__c dom = mapDom.get(req.domicilioId);
            System.debug('Domicilio record: ' + dom);
            if (dom == null) {
                resp.errorMessage = 'No se encuentra el domicilio con ese Id';
                results.add(resp);
                System.debug('Error: ' + resp.errorMessage);
                continue;
            }
            String direccion = String.valueOf(dom.Domicilio_Adicional__c);
            System.debug('Direccion a geocodificar: ' + direccion);
            if (String.isBlank(direccion)) {
                resp.errorMessage = 'La dirección está vacía';
                results.add(resp);
                System.debug('Error: ' + resp.errorMessage);
                continue;
            }

            try {
                HttpRequest httpReq = new HttpRequest();
                String endpointUrl = 'https://maps.googleapis.com/maps/api/geocode/json?address='
                    + EncodingUtil.urlEncode(direccion, 'UTF-8')
                    + '&key=AIzaSyC4ObJce3_zjgNUXCSC7eSe88Tn9B-Jecs';
                httpReq.setEndpoint(endpointUrl);
                httpReq.setMethod('GET');
                System.debug('HTTP request endpoint: ' + endpointUrl);

                Http http = new Http();
                HttpResponse httpResp = http.send(httpReq);
                System.debug('HTTP response status: ' + httpResp.getStatusCode());
                System.debug('HTTP response body: ' + httpResp.getBody());

                if (httpResp.getStatusCode() == 200) {
                    Map<String,Object> root = (Map<String,Object>) JSON.deserializeUntyped(httpResp.getBody());
                    System.debug('Parsed root JSON: ' + root);
                    if (root.containsKey('results')) {
                        List<Object> resultsList = (List<Object>) root.get('results');
                        System.debug('Results list: ' + resultsList);
                        if (!resultsList.isEmpty()) {
                            Map<String,Object> first = (Map<String,Object>) resultsList.get(0);
                            System.debug('First result: ' + first);
                            if (first.containsKey('geometry')) {
                                Map<String,Object> geometry = (Map<String,Object>) first.get('geometry');
                                System.debug('Geometry: ' + geometry);
                                if (geometry.containsKey('location')) {
                                    Map<String,Object> loc = (Map<String,Object>) geometry.get('location');
                                    System.debug('Location: ' + loc);
                                    resp.latitude = (Double) loc.get('lat');
                                    resp.longitude = (Double) loc.get('lng');
                                }
                            }
                        } else {
                            resp.errorMessage = 'No se encontró resultado para geocodificación';
                            System.debug('Error: ' + resp.errorMessage);
                        }
                    } else {
                        resp.errorMessage = 'Respuesta no tiene nodo results';
                        System.debug('Error: ' + resp.errorMessage);
                    }
                } else {
                    resp.errorMessage = 'HTTP ' + httpResp.getStatusCode() + ': ' + httpResp.getBody();
                    System.debug('Error: ' + resp.errorMessage);
                }

            } catch (Exception ex) {
                resp.errorMessage = 'Error en callout o parsing: ' + ex.getMessage();
                System.debug('Excepción: ' + ex.getMessage());
            }
               

            System.debug('Response prepared: ' + resp);
            results.add(resp);
        }
        System.debug('All responses: ' + results);
        return results;
    }
}