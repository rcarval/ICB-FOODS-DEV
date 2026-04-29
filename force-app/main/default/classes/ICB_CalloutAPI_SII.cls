/**********************************************************************************
 * ICB_CalloutAPI_SII
 * Servicio de integración con API Gateway SII para consulta de contribuyentes.
 * SEIDOR - SMH - Integración API Gateway SII

 **********************************************************************************/
public with sharing class ICB_CalloutAPI_SII {

    /** Constantes de Configuración */
    private static final String NAMED_CREDENTIAL = 'ICB_SII_API';
    private static final String PATH_AUTORIZACION = '/api/v2/sii/contribuyentes/situacion_tributaria/tercero/{rut}';
    private static final Integer TIMEOUT_MS = 120000;
    private static final String LOG_PREFIX = '[ICB_SII]';
    private static final Integer LOG_BODY_MAX_LENGTH = 1000;

    /** Mapeamos la respuesta JSON */
    public class SituacionTributariaResponseDto {
        public SituacionTributariaDataDto data;
    }

    public class SituacionTributariaDataDto {
        public Long rut;
        public String dv;
        public String razon_social;
        public Boolean inicio_actividades;
        public String fecha_inicio_actividades;
        public Boolean pro_pyme;
        public Boolean moneda_extranjera;
        public Boolean obligacion_dte;
        public Boolean excepcion_dte;
        public List<ActividadDto> actividades;
        public List<DocumentoTimbradoDto> documentos_timbrados;
        public ObservacionesDto observaciones;
    }

    public class ActividadDto {
        public String codigo;
        public String glosa;
        public Integer categoria;
        public Boolean afecta;
    }

    public class DocumentoTimbradoDto {
        public String documento;
        public Integer ultimo_timbraje;
    }

    public class ObservacionesDto {
        public Boolean inconcurrente;
        public Boolean suplantado;
        public Boolean no_ubicado;
        public Boolean termino_giro;
        public Boolean domicilio_inexistente;
        public Boolean actividad_esporadica;
        public Boolean no_habido_domicilio;
        public Boolean termino_giro_obligatorio;
    }
    
    /**
     * Realiza la consulta de estado de autorización al SII.
     * rut - RUT del contribuyente (formato 12345678-9)
     * SituacionTributariaResponseDto con la información del servicio.
     * ICB_CalloutSIIException en caso de error de negocio o conexión.
     */
    public static SituacionTributariaResponseDto consultarEstadoAutorizacion(String rut) {
        String origen = 'ICB_CalloutAPI_SII.consultarEstadoAutorizacion';
        logInfo('Iniciando consulta para RUT: ' + rut);
        
        // 1. Validación Defensiva por si no está el RUT
        if (String.isBlank(rut)) {
            throw new ICB_CalloutSIIException('El RUT es obligatorio para realizar la consulta.');
        }

        Long startMs = System.currentTimeMillis();
        
        // Construcción dinámica del endpoint 
        String endpoint = 'callout:' + NAMED_CREDENTIAL + String.format(PATH_AUTORIZACION, new List<String>{ rut });
        endpoint = endpoint.replace('{rut}', rut);
        
        HttpRequest req = new HttpRequest();
        req.setEndpoint(endpoint);
        req.setMethod('GET');
        req.setTimeout(TIMEOUT_MS); 

        Http http = new Http();
        HttpResponse res = null;
        
        try {
            // 2. Ejecución del Callout envuelto en try/catch
            res = http.send(req);
            
            // 3. Validación de Respuesta Exitosa
            if (res.getStatusCode() == 200) {
                logInfo('Petición exitosa recibida.');
                SituacionTributariaResponseDto dto = (SituacionTributariaResponseDto) JSON.deserialize(res.getBody(), SituacionTributariaResponseDto.class);
                
                ICB_LogIntegracionService.insertarLogOutbound(origen, endpoint, 'GET', null, null, res.getStatusCode(), null, res.getBody(), true, null, System.currentTimeMillis() - startMs, rut);
                return dto;
            } else {
                String errorMsg = 'Error en respuesta SII. Status: ' + res.getStatusCode() + ' - ' + res.getStatus();
                logError(errorMsg + ' | Body: ' + getBodySnippet(res != null ? res.getBody() : null));
                
                ICB_LogIntegracionService.insertarLogOutbound(origen, endpoint, 'GET', null, null, res != null ? res.getStatusCode() : null, null, res != null ? res.getBody() : null, false, errorMsg, System.currentTimeMillis() - startMs, rut);
                throw new ICB_CalloutSIIException(errorMsg);
            }
        } catch (Exception e) {
            logError('Error de integración: ' + e.getMessage());
            ICB_LogIntegracionService.insertarLogOutbound(origen, endpoint, 'GET', null, null, res != null ? res.getStatusCode() : null, null, res != null ? res.getBody() : null, false, e.getMessage(), System.currentTimeMillis() - startMs, rut);
            throw e;
        } finally {
            // 4. Publicación obligatoria de logs 
            ICB_LogIntegracionService.publicarLogsOutboundPendientes();
        }
    }

    /** Métodos de utilidad privados */

    private static String getBodySnippet(String body) {
        if (String.isBlank(body)) return '';
        return body.length() > LOG_BODY_MAX_LENGTH ? body.substring(0, LOG_BODY_MAX_LENGTH) + '...' : body;
    }

    private static void logInfo(String mensaje) {
        System.debug(LoggingLevel.INFO, LOG_PREFIX + ' ' + mensaje);
    }

    private static void logError(String mensaje) {
        System.debug(LoggingLevel.ERROR, LOG_PREFIX + ' ' + mensaje);
    }

    /** Excepción personalizada para la integración */
    public class ICB_CalloutSIIException extends Exception {}
}