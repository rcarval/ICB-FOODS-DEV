/**********************************************************************************
 * ICB_LogIntegracionService
 * Publica eventos Log_Integracion_Event__e para registrar integraciones.
 * Los logs outbound se acumulan en memoria y se publican al final (evita bloquear callouts).
 * El flujo inserta en Log_Integracion__c cuando llega el evento.
 * SEIDOR - RCG
 **********************************************************************************/
public with sharing class ICB_LogIntegracionService {

    private static final Integer MAX_HEADERS = 32768;
    private static final Integer MAX_BODY = 100000;

    private static List<Log_Integracion_Event__e> logsOutboundPendientes = new List<Log_Integracion_Event__e>();

    /**
     * Acumula un log outbound. No publica hasta llamar publicarLogsOutboundPendientes() al final del flujo.
     * Evita bloquear callouts posteriores (EventBus.publish y @future cuentan como trabajo pendiente).
     */
    public static void insertarLogOutbound(
        String origen,
        String url,
        String metodoHttp,
        String requestHeaders,
        String requestBody,
        Integer responseStatusCode,
        String responseHeaders,
        String responseBody,
        Boolean exito,
        String mensajeError,
        Long duracionMs,
        String contexto
    ) {
        try {
            Log_Integracion_Event__e evt = new Log_Integracion_Event__e();
            evt.Direccion__c = 'Outbound';
            evt.Origen__c = truncar(origen, 255);
            evt.Exito__c = exito;
            evt.Mensaje_Error__c = truncar(mensajeError, MAX_HEADERS);
            evt.Duracion_Ms__c = duracionMs != null ? duracionMs.intValue() : null;
            evt.Contexto__c = truncar(contexto, 255);
            evt.URL__c = truncar(url, MAX_HEADERS);
            evt.Metodo_HTTP__c = metodoHttp;
            evt.Request_Headers__c = truncar(requestHeaders, MAX_HEADERS);
            evt.Request_Body__c = truncar(requestBody, MAX_BODY);
            evt.Response_Status_Code__c = responseStatusCode;
            evt.Response_Headers__c = truncar(responseHeaders, MAX_HEADERS);
            evt.Response_Body__c = truncar(responseBody, MAX_BODY);
            logsOutboundPendientes.add(evt);
        } catch (Exception e) {
            System.debug(LoggingLevel.ERROR, '[ICB_LogIntegracion] Error al acumular log outbound: ' + e.getMessage());
        }
    }

    /**
     * Publica todos los logs outbound acumulados. Llamar al final del flujo, después del último callout.
     */
    public static void publicarLogsOutboundPendientes() {
        if (logsOutboundPendientes.isEmpty()) {
            return;
        }
        try {
            List<Log_Integracion_Event__e> copia = new List<Log_Integracion_Event__e>(logsOutboundPendientes);
            logsOutboundPendientes.clear();
            EventBus.publish(copia);
        } catch (Exception e) {
            System.debug(LoggingLevel.ERROR, '[ICB_LogIntegracion] Error al publicar logs outbound: ' + e.getMessage());
        }
    }

    /**
     * Publica un log inbound. El flujo inserta en Log_Integracion__c.
     */
    public static void insertarLogInbound(
        String origen,
        String payload,
        Boolean exito,
        String mensajeError,
        String contexto
    ) {
        try {
            Log_Integracion_Event__e evt = new Log_Integracion_Event__e();
            evt.Direccion__c = 'Inbound';
            evt.Origen__c = truncar(origen, 255);
            evt.Exito__c = exito;
            evt.Mensaje_Error__c = truncar(mensajeError, MAX_HEADERS);
            evt.Contexto__c = truncar(contexto, 255);
            evt.Request_Body__c = truncar(payload, MAX_BODY);
            EventBus.publish(evt);
        } catch (Exception e) {
            System.debug(LoggingLevel.ERROR, '[ICB_LogIntegracion] Error al publicar log inbound: ' + e.getMessage());
        }
    }

    private static String truncar(String s, Integer maxLen) {
        if (s == null) return null;
        if (s.length() <= maxLen) return s;
        String suffix = ' (truncado)';
        return s.substring(0, maxLen - suffix.length()) + suffix;
    }
}