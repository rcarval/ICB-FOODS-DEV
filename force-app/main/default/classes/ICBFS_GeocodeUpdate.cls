public with sharing class ICBFS_GeocodeUpdate {

    public class GeocodeUpdateRequest {
        @InvocableVariable(label='Id del domicilio')
        public Id domicilioId;
        @InvocableVariable(label='Latitud')
        public Double latitude;
        @InvocableVariable(label='Longitud')
        public Double longitude;
        @InvocableVariable(label='Mensaje de error (si lo hubo)')
        public String errorMessage;
    }

    @InvocableMethod(label='Actualizar ubicación geocodificada')
    public static void aplicarGeocodingARegistros(List<GeocodeUpdateRequest> requests) {
        List<Domicilio_de_Cliente__c> toUpdate = new List<Domicilio_de_Cliente__c>();

        for (GeocodeUpdateRequest req : requests) {
            if (req.latitude != null && req.longitude != null) {
                Domicilio_de_Cliente__c dom = new Domicilio_de_Cliente__c(
                    Id = req.domicilioId,
                    Latitud__c = String.valueOf(req.latitude),
                    Longitud__c = String.valueOf(req.longitude)
                );
                toUpdate.add(dom);
            }
        }

        if (!toUpdate.isEmpty()) {
            try {
                update toUpdate;
            } catch (Exception ex) {
                // Manejo de errores
            }
        }
    }
}