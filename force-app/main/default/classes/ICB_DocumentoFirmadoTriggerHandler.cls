/**********************************************************************************
 * ICB_DocumentoFirmadoTriggerHandler
 * Actualiza Contrato_Digital__c cuando llega un evento DocumentoFirmado__e (TuFirma).
 * SEIDOR - RCG
 **********************************************************************************/
public with sharing class ICB_DocumentoFirmadoTriggerHandler {

    public static void onAfterInsert(List<DocumentoFirmado__e> events) {
        if (events == null || events.isEmpty()) {
            return;
        }
        String origen = 'ICB_DocumentoFirmadoTriggerHandler.onAfterInsert';
        String payload = JSON.serialize(events);
        Set<String> contratoIds = new Set<String>();
        for (DocumentoFirmado__e e : events) {
            if (String.isNotBlank(e.ContratoId__c)) {
                contratoIds.add(e.ContratoId__c);
            }
        }
        if (contratoIds.isEmpty()) {
            ICB_LogIntegracionService.insertarLogInbound(origen, payload, false, 'Ningún evento con ContratoId__c', 'eventos sin ContratoId__c válido');
            return;
        }
        try {
            List<Contrato_Digital__c> contratos = [
                SELECT Id, Contrato_ID__c
                FROM Contrato_Digital__c
                WHERE Contrato_ID__c IN :contratoIds
            ];
            Map<String, Contrato_Digital__c> byContratoId = new Map<String, Contrato_Digital__c>();
            for (Contrato_Digital__c c : contratos) {
                byContratoId.put(c.Contrato_ID__c, c);
            }
            List<Contrato_Digital__c> toUpdate = new List<Contrato_Digital__c>();
            for (DocumentoFirmado__e e : events) {
                if (String.isBlank(e.ContratoId__c)) {
                    continue;
                }
                Contrato_Digital__c c = byContratoId.get(e.ContratoId__c);
                if (c == null) {
                    continue;
                }
                applyEventToRecord(e, c);
                toUpdate.add(c);
            }
            if (!toUpdate.isEmpty()) {
                update toUpdate;
            }
            ICB_LogIntegracionService.insertarLogInbound(origen, payload, true, null, 'Contratos actualizados: ' + toUpdate.size());
        } catch (Exception e) {
            ICB_LogIntegracionService.insertarLogInbound(origen, payload, false, e.getMessage(), 'ContratoIds: ' + String.join(new List<String>(contratoIds), ', '));
            throw e;
        }
    }

    private static void applyEventToRecord(DocumentoFirmado__e e, Contrato_Digital__c c) {
        if (String.isNotBlank(e.Estado__c)) {
            c.Estado__c = mapEstadoFromEvent(e.Estado__c);
        } else if (e.FechaFirma__c != null || String.isNotBlank(e.PdfFirmadoUrl__c)) {
            c.Estado__c = 'Firmado';
        }
        if (String.isNotBlank(e.ExternalTransactionId__c)) {
            c.Documento_ID_TuFirma_del__c = e.ExternalTransactionId__c;
        }
        if (e.FechaFirma__c != null) {
            c.Fecha_Firma__c = e.FechaFirma__c;
        }
        if (String.isNotBlank(e.PdfFirmadoUrl__c)) {
            c.PDF_Firmado_URL__c = e.PdfFirmadoUrl__c;
        }

    }

    private static String mapEstadoFromEvent(String eventEstado) {
        if (String.isBlank(eventEstado)) {
            return null;
        }
        String normal = eventEstado.trim().toLowerCase();
        if (normal == 'signed' || normal == 'completed' || normal == 'firmado') {
            return 'Firmado';
        }
        if (normal == 'rejected' || normal == 'rechazado') {
            return 'Rechazado';
        }
        if (normal == 'expired' || normal == 'expirado') {
            return 'Expirado';
        }
        if (normal == 'error' || normal == 'failed' || normal == 'failure') {
            return 'Rechazado';
        }
        if (normal == 'sent' || normal == 'enviado') {
            return 'Enviado';
        }
        if (normal == 'pending' || normal == 'pendiente') {
            return 'Pendiente';
        }
        return eventEstado.trim();
    }

    private static String truncateToLength(String s, Integer maxLen) {
        if (s == null || s.length() <= maxLen) {
            return s;
        }
        return s.substring(0, maxLen);
    }
}