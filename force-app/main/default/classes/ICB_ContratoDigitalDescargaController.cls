/**********************************************************************************
 * ICB_ContratoDigitalDescargaController
 * Obtiene la URL prefirmada de S3 para descargar/previsualizar el PDF firmado.
 * Soporta recordId de Contrato_Digital__c o Quote (usa Quote.Contrato_Digital__c).
 * SEIDOR - RCG
 **********************************************************************************/
public with sharing class ICB_ContratoDigitalDescargaController {

    @AuraEnabled(cacheable=false)
    public static DescargaResult getUrlDescargaPdf(Id recordId) {
        DescargaResult result = new DescargaResult();
        result.url = null;
        result.error = null;

        if (recordId == null) {
            result.error = 'recordId es obligatorio.';
            return result;
        }

        try {
            String contratoId = obtenerContratoId(recordId);
            if (String.isBlank(contratoId)) {
                result.error = 'No se encontró Contrato_ID__c. Verifique que el registro tenga un contrato digital asociado.';
                return result;
            }

            ICB_FirmaDigitalServiceImpl.DownloadResponseDto dto = ICB_FirmaDigitalServiceImpl.solicitarUrlDescarga(contratoId);
            String url = dto.downloadURL;

            if (String.isBlank(url)) {
                result.error = 'La API no devolvió URL de descarga.';
                return result;
            }

            result.url = url;
        } catch (ICB_FirmaDigitalServiceImpl.ICB_FirmaDigitalException e) {
            result.error = e.getMessage();
        } catch (Exception e) {
            result.error = 'Error al obtener URL: ' + e.getMessage();
        } finally {
            ICB_LogIntegracionService.publicarLogsOutboundPendientes();
        }

        return result;
    }

    private static String obtenerContratoId(Id recordId) {
        Schema.SObjectType soType = recordId.getSObjectType();
        String typeName = soType.getDescribe().getName();

        if (typeName == 'Contrato_Digital__c') {
            List<Contrato_Digital__c> contratos = [
                SELECT Contrato_ID__c
                FROM Contrato_Digital__c
                WHERE Id = :recordId
                LIMIT 1
            ];
            return contratos.isEmpty() ? null : contratos[0].Contrato_ID__c;
        }

        if (typeName == 'Quote') {
            List<Quote> quotes = [
                SELECT Contrato_Digital__r.Contrato_ID__c
                FROM Quote
                WHERE Id = :recordId
                LIMIT 1
            ];
            if (quotes.isEmpty() || quotes[0].Contrato_Digital__c == null) {
                return null;
            }
            return quotes[0].Contrato_Digital__r.Contrato_ID__c;
        }

        return null;
    }

    public class DescargaResult {
        @AuraEnabled public String url;
        @AuraEnabled public String error;
    }
}