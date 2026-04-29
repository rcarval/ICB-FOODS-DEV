public with sharing class ICBFS_QuicksightEmbedController {

    // =============================
    // == MÉTODOS PÚBLICOS (LWC)  ==
    // =============================

    /**
     * Obtiene la URL embed para un dashboard específico
     */
    @AuraEnabled
    public static String getEmbedUrlForDashboard(String dashboardId) {

        System.debug('=== [getEmbedUrlForDashboard] INICIO ===');
        System.debug('dashboardId recibido: ' + dashboardId);

        // Validación básica de entrada
        if (String.isBlank(dashboardId)) {
            System.debug(LoggingLevel.ERROR, 'dashboardId viene vacío o nulo');
            throw new AuraHandledException('El dashboardId no puede estar vacío');
        }

        QuicksightConfig cfg = loadConfig();
        System.debug('Config cargada: ' + cfg);

        // Validar que la configuración exista
        if (cfg == null || String.isBlank(cfg.endpoint) || String.isBlank(cfg.apiKey)) {
            System.debug(LoggingLevel.ERROR,
                'Configuración inválida | endpoint=' + (cfg != null ? cfg.endpoint : null) +
                ' | apiKey=' + (cfg != null ? '***' : null)
            );
            throw new AuraHandledException('Configuración de QuickSight incompleta');
        }

        try {
            String userEmail = UserInfo.getUserEmail();
            System.debug('User email utilizado: ' + userEmail);

            String embedUrl = generateEmbedUrl(cfg, dashboardId, userEmail);
            System.debug('Embed URL generada correctamente: ' + embedUrl);

            System.debug('=== [getEmbedUrlForDashboard] FIN OK ===');
            return embedUrl;

        } catch (CalloutException coEx) {
            System.debug(LoggingLevel.ERROR,
                'CalloutException en getEmbedUrlForDashboard: ' + coEx.getMessage()
            );
            throw new AuraHandledException(
                'Callout fallido al obtener Embed URL: ' + coEx.getMessage()
            );

        } catch (Exception e) {
            System.debug(LoggingLevel.ERROR,
                'Exception inesperada en getEmbedUrlForDashboard: ' + e.getMessage()
            );
            throw new AuraHandledException(
                'Error inesperado al generar Embed URL: ' + e.getMessage()
            );
        }
    }

    /**
     * Obtiene la lista de dashboards disponibles desde Custom Metadata
     */
    @AuraEnabled(cacheable=true)
    public static List<LabelValue> getDashboardOptions() {

        System.debug('=== [getDashboardOptions] INICIO ===');

        List<Dashboard_quickSight__mdt> records = [
            SELECT Nombre_dashboard__c, id_dashboard__c
            FROM Dashboard_quickSight__mdt
            WHERE Activo__c = true
            ORDER BY Nombre_dashboard__c
        ];

        System.debug('Cantidad de dashboards activos encontrados: ' + records.size());

        List<LabelValue> result = new List<LabelValue>();
        for (Dashboard_quickSight__mdt r : records) {
            System.debug(
                'Dashboard metadata | Nombre=' + r.Nombre_dashboard__c +
                ' | IdDashboard=' + r.id_dashboard__c
            );

            if (r.Nombre_dashboard__c != null && r.id_dashboard__c != null) {
                result.add(new LabelValue(r.Nombre_dashboard__c, r.id_dashboard__c));
            }
        }

        System.debug('Cantidad de opciones retornadas al LWC: ' + result.size());
        System.debug('=== [getDashboardOptions] FIN ===');

        return result;
    }

    // =============================
    // == LÓGICA INTERNA          ==
    // =============================

    private static QuicksightConfig loadConfig() {

        System.debug('=== [loadConfig] Cargando Custom Metadata aws_quicksight__mdt ===');

        aws_quicksight__mdt cfg = [
            SELECT endpoiny_aws__c, x_api_key__c
            FROM aws_quicksight__mdt
            LIMIT 1
        ];

        System.debug(
            'Metadata obtenida | endpoint=' + cfg.endpoiny_aws__c +
            ' | apiKey=' + (cfg.x_api_key__c != null ? '***' : null)
        );

        return new QuicksightConfig(
            cfg.endpoiny_aws__c,
            cfg.x_api_key__c
        );
    }

    private static String generateEmbedUrl(
        QuicksightConfig cfg,
        String dashboardId,
        String userEmail
    ) {

        System.debug('=== [generateEmbedUrl] INICIO ===');
        System.debug('Endpoint: ' + cfg.endpoint);
        System.debug('DashboardId: ' + dashboardId);
        System.debug('UserEmail: ' + userEmail);

        Map<String, Object> payload = new Map<String, Object>{
            //'email' => userEmail,
                'email' => 'jsilvac@icbfs.cl',
            'dashboardId' => dashboardId
        };

        String body = JSON.serialize(payload);
        System.debug('Request payload: ' + body);

        HttpRequest req = new HttpRequest();
        req.setEndpoint(cfg.endpoint);
        req.setMethod('POST');
        req.setHeader('Content-Type', 'application/json');
        req.setHeader('X-API-Key', cfg.apiKey);
        req.setBody(body);
        req.setTimeout(120000);

        System.debug('HttpRequest configurado correctamente');

        Http http = new Http();
        HttpResponse res = http.send(req);

        System.debug(
            'Respuesta HTTP | Status=' + res.getStatusCode() +
            ' | Body=' + res.getBody()
        );

        if (res.getStatusCode() != 200) {
            System.debug(LoggingLevel.ERROR,
                'Status HTTP inválido: ' + res.getStatusCode()
            );
            throw new CalloutException(
                'Callout fallido (' + res.getStatusCode() + '): ' + res.getBody()
            );
        }

        QuickSightResponse response =
            (QuickSightResponse) JSON.deserialize(res.getBody(), QuickSightResponse.class);

        System.debug('Respuesta deserializada: ' + response);

        if (response == null || response.embedUrl == null) {
            System.debug(LoggingLevel.ERROR,
                'Respuesta sin embedUrl | response=' + response
            );
            throw new CalloutException('Respuesta sin embedUrl');
        }

        System.debug('EmbedUrl final retornada: ' + response.embedUrl);
        System.debug('=== [generateEmbedUrl] FIN OK ===');

        return response.embedUrl;
    }

    // =============================
    // == CLASES AUXILIARES       ==
    // =============================

    public class LabelValue {
        @AuraEnabled public String label;
        @AuraEnabled public String value;
        public LabelValue(String l, String v) {
            label = l;
            value = v;
        }
    }

    private class QuicksightConfig {
        public String endpoint;
        public String apiKey;
        public QuicksightConfig(String e, String k) {
            endpoint = e;
            apiKey = k;
        }
    }

    private class QuickSightResponse {
        public String embedUrl;
        public Integer status;
        public String requestId;
    }
}