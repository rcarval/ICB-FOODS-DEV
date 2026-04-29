/**********************************************************************************
 * ICB_AccountSII_ResponseHandler
 * Procesa resultado de validación y respuesta HTTP del servicio SII; actualiza Account origen.
 * Ticket: 00025935 — SEIDOR
 * TODO: Mapear campos custom (Estado_Integracion_SII__c, etc.) cuando existan en metadata.
 **********************************************************************************/
public with sharing class ICB_AccountSII_ResponseHandler {

    private static final String LOG_PREFIX = '[ICB_AccountSII_ResponseHandler]';

    /**
     * Cuenta con datos incompletos antes del callout.
     */
    public static void applyValidationFailure(Id accountId, ICB_AccountSII_IntegrationService.ValidationResult vr) {
        if (accountId == null) {
            return;
        }
        String msg = vr != null && vr.missingFields != null && !vr.missingFields.isEmpty()
            ? 'Faltan datos: ' + String.join(vr.missingFields, ', ')
            : 'Validación fallida.';
        System.debug(LoggingLevel.WARN, LOG_PREFIX + ' accountId=' + accountId + ' | ' + msg);
        // TODO: update Account con estado error / mensaje cuando existan campos en org
    }

    /**
     * Respuesta del servicio (o null mientras el callout en ICB_CalloutAPI_SII no esté implementado).
     */
    public static void applyHttpResponse(Id accountId, HttpResponse res, String requestPayloadJson) {
        applyResponse(accountId, res, requestPayloadJson);
    }

    /**
     * Punto único para parsear cuerpo y persistir en Account.
     */
    public static void applyResponse(Id accountId, HttpResponse res, String requestPayloadJson) {
        if (accountId == null) {
            return;
        }
        if (res == null) {
            System.debug(
                LoggingLevel.INFO,
                LOG_PREFIX + ' Sin respuesta HTTP aún (integración pendiente). accountId=' + accountId
            );
            // TODO: opcional — marcar estado "Pendiente" en Account cuando existan campos
            return;
        }

        Integer code = res.getStatusCode();
        String body = res.getBody();
        System.debug(
            LoggingLevel.INFO,
            LOG_PREFIX + ' accountId=' + accountId + ' status=' + code + ' body=' + truncar(body, 1000)
        );

        Boolean exito = code >= 200 && code < 300;
        // TODO: deserializar JSON real y actualizar Account (Id externo SII, estado, errores)
        if (exito) {
            System.debug(LoggingLevel.INFO, LOG_PREFIX + ' Integración respondió OK (mapeo pendiente de spec).');
        } else {
            System.debug(LoggingLevel.WARN, LOG_PREFIX + ' Integración respondió error HTTP.');
        }
    }

    private static String truncar(String s, Integer maxLen) {
        if (String.isBlank(s) || maxLen == null || maxLen <= 0) {
            return s;
        }
        return s.length() > maxLen ? s.substring(0, maxLen) + '…' : s;
    }
}