/**********************************************************************************
 * ICB_AccountSII_ResponseHandler
 * Procesa resultado de validación y respuesta HTTP del servicio SII; actualiza Account origen.
 * Ticket: 00025935 — SEIDOR
 * TODO: Mapear campos custom (Estado_Integracion_SII__c, etc.) cuando existan en metadata.
 * COMPLETAR: Implementar la lógica de procesamiento de la respuesta HTTP y actualización del Account.
 **********************************************************************************/
public with sharing class ICB_AccountSII_ResponseHandler {

    private static final String LOG_PREFIX = '[ICB_AccountSII_ResponseHandler]';

    /**
     * Registra en log (y más adelante en Account) cuando la validación corta antes del HTTP.
     * @param accountId Cuenta objetivo; si es null no hace nada.
     * @param vr Resultado con missingFields; si viene null se asume mensaje genérico.
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
     * Delega en applyResponse; punto de extensión si más adelante se loguea request/response aquí.
     * @param accountId Cuenta a actualizar tras el callout.
     * @param res Respuesta del HTTP client; null si aún no hay integración.
     * @param requestPayloadJson Body enviado (auditoría); opcional.
     */
    public static void applyHttpResponse(Id accountId, HttpResponse res, String requestPayloadJson) {
        applyResponse(accountId, res, requestPayloadJson);
    }

    /**
     * Interpreta la respuesta HTTP (o ausencia de ella) y aplica updates al Account cuando existan campos.
     * @param accountId Cuenta origen de la integración.
     * @param res Null mientras no haya callout: camino “pendiente”, no se interpreta status.
     * @param requestPayloadJson Reservado para logging o correlación con el request.
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

    /**
     * Corta strings largos para debug; no altera null.
     * @param maxLen Longitud máxima del prefijo conservado; si es null o menor o igual a 0 devuelve s sin cambios.
     * @return Mismo texto o prefijo + sufijo elipsis Unicode.
     */
    private static String truncar(String s, Integer maxLen) {
        if (String.isBlank(s) || maxLen == null || maxLen <= 0) {
            return s;
        }
        return s.length() > maxLen ? s.substring(0, maxLen) + '…' : s;
    }
}