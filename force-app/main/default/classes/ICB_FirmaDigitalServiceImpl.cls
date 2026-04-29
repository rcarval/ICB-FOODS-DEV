/**********************************************************************************
 * ICB_FirmaDigitalServiceImpl
 * Servicio API Firma Digital: upload, PUT S3, download. Named Credential ICB_FirmaDigital.
 * SEIDOR - RCG
 **********************************************************************************/
public with sharing class ICB_FirmaDigitalServiceImpl {

    private static final String NAMED_CREDENTIAL = 'ICB_FirmaDigital';
    private static final String PATH_UPLOAD = '/v1/firma/upload';
    private static final String PATH_DOWNLOAD = '/v1/firma/download';
    private static final Integer TIMEOUT_MS = 120000;
    private static final String LOG_PREFIX = '[ICB_FirmaDigital]';
    private static final Integer LOG_BODY_MAX_LENGTH = 500;

    public class FirmanteDto {
        public String nombre;
        public String email;
        public String rut;
        public String telefono;
    }

    public class SignatureConfigDto {
        public String nombre;
        public List<FirmanteDto> firmantes;
    }

    public class UploadRequestDto {
        public String contratoId;
        public String fileName;
        public SignatureConfigDto signatureConfig;
    }

    public class UploadResponseDto {
        public Boolean success;
        public String contratoId;
        public String uploadUrl;
        public String expiresAt;
    }

    public class DownloadRequestDto {
        public String contratoId;
    }

    public class DownloadResponseDto {
        public Boolean success;
        public String contratoId;
        public String downloadURL;  // API real: downloadURL (camelCase)
        public Integer expiresIn;
        public String expiresAt;
        public String tufirmaDocumentId;
        public String signedS3Key;
        public String completedAt;
        public String error;
    }

    public static UploadResponseDto solicitarUploadUrl(UploadRequestDto request) {
        logInfo('solicitarUploadUrl | inicio');
        String origen = 'ICB_FirmaDigitalServiceImpl.solicitarUploadUrl';
        Long startMs = System.currentTimeMillis();
        String requestBody = null;
        HttpResponse res = null;
        try {
            validarUploadRequest(request);
            requestBody = jsonToAscii(JSON.serialize(request));
            res = ejecutarCalloutApi(PATH_UPLOAD, 'POST', requestBody);
            validarRespuestaExito(res, 'solicitarUploadUrl');
            UploadResponseDto dto = (UploadResponseDto) JSON.deserialize(res.getBody(), UploadResponseDto.class);
            logInfo('solicitarUploadUrl | ok | contratoId=' + dto.contratoId);
            ICB_LogIntegracionService.insertarLogOutbound(origen, endpointForPath(PATH_UPLOAD), 'POST', 'Content-Type: application/json', requestBody, res.getStatusCode(), responseHeadersToString(res), res.getBody(), true, null, System.currentTimeMillis() - startMs, request.contratoId);
            return dto;
        } catch (Exception e) {
            ICB_LogIntegracionService.insertarLogOutbound(origen, endpointForPath(PATH_UPLOAD), 'POST', 'Content-Type: application/json', requestBody, res != null ? res.getStatusCode() : null, res != null ? responseHeadersToString(res) : null, res != null ? res.getBody() : null, false, e.getMessage(), System.currentTimeMillis() - startMs, request != null ? request.contratoId : null);
            throw e;
        }
    }

    public static void subirPdfAUploadUrl(String uploadUrl, Blob pdfBody) {
        logInfo('subirPdfAUploadUrl | inicio');
        String origen = 'ICB_FirmaDigitalServiceImpl.subirPdfAUploadUrl';
        Long startMs = System.currentTimeMillis();
        HttpResponse res = null;
        try {
            validarUploadUrlYPdf(uploadUrl, pdfBody);
            res = ejecutarPutBinario(uploadUrl, pdfBody);
            validarRespuestaExito(res, 'subirPdfAUploadUrl');
            logInfo('subirPdfAUploadUrl | ok');
            ICB_LogIntegracionService.insertarLogOutbound(origen, uploadUrl, 'PUT', 'Content-Type: application/pdf', '(binario PDF omitido)', res.getStatusCode(), responseHeadersToString(res), res.getBody(), true, null, System.currentTimeMillis() - startMs, null);
        } catch (Exception e) {
            ICB_LogIntegracionService.insertarLogOutbound(origen, uploadUrl, 'PUT', 'Content-Type: application/pdf', '(binario PDF omitido)', res != null ? res.getStatusCode() : null, res != null ? responseHeadersToString(res) : null, res != null ? res.getBody() : null, false, e.getMessage(), System.currentTimeMillis() - startMs, null);
            throw e;
        }
    }

    public static DownloadResponseDto solicitarUrlDescarga(String contratoId) {
        logInfo('solicitarUrlDescarga | inicio | contratoId=' + contratoId);
        String origen = 'ICB_FirmaDigitalServiceImpl.solicitarUrlDescarga';
        Long startMs = System.currentTimeMillis();
        String requestBody = null;
        HttpResponse res = null;
        try {
            validarContratoId(contratoId);
            DownloadRequestDto bodyDto = new DownloadRequestDto();
            bodyDto.contratoId = contratoId;
            requestBody = jsonToAscii(JSON.serialize(bodyDto));
            res = ejecutarCalloutApi(PATH_DOWNLOAD, 'POST', requestBody);
            validarRespuestaExito(res, 'solicitarUrlDescarga');
            DownloadResponseDto dto = (DownloadResponseDto) JSON.deserialize(res.getBody(), DownloadResponseDto.class);
            logInfo('solicitarUrlDescarga | ok');
            ICB_LogIntegracionService.insertarLogOutbound(origen, endpointForPath(PATH_DOWNLOAD), 'POST', 'Content-Type: application/json', requestBody, res.getStatusCode(), responseHeadersToString(res), res.getBody(), true, null, System.currentTimeMillis() - startMs, contratoId);
            return dto;
        } catch (Exception e) {
            ICB_LogIntegracionService.insertarLogOutbound(origen, endpointForPath(PATH_DOWNLOAD), 'POST', 'Content-Type: application/json', requestBody, res != null ? res.getStatusCode() : null, res != null ? responseHeadersToString(res) : null, res != null ? res.getBody() : null, false, e.getMessage(), System.currentTimeMillis() - startMs, contratoId);
            throw e;
        }
    }

    private static void validarUploadRequest(UploadRequestDto request) {
        if (request == null || String.isBlank(request.contratoId) || String.isBlank(request.fileName)) {
            throw new ICB_FirmaDigitalException('contratoId y fileName son obligatorios');
        }
    }

    private static void validarContratoId(String contratoId) {
        if (String.isBlank(contratoId)) {
            throw new ICB_FirmaDigitalException('contratoId es obligatorio');
        }
    }

    private static void validarUploadUrlYPdf(String uploadUrl, Blob pdfBody) {
        if (String.isBlank(uploadUrl) || pdfBody == null || pdfBody.size() == 0) {
            throw new ICB_FirmaDigitalException('uploadUrl y pdfBody son obligatorios');
        }
    }

    /** Convierte el JSON a solo ASCII escapando Unicode (\uXXXX en hex) para evitar MIME encoding en proxies. */
    private static String jsonToAscii(String json) {
        if (json == null) {
            return null;
        }
        String hexChars = '0123456789abcdef';
        String result = '';
        for (Integer i = 0; i < json.length(); i++) {
            String c = json.substring(i, i + 1);
            Integer code = c.charAt(0);
            if (code > 127) {
                Integer n = code;
                String hex = '';
                for (Integer j = 0; j < 4; j++) {
                    hex = hexChars.substring(Math.mod(n, 16), Math.mod(n, 16) + 1) + hex;
                    n = n / 16;
                }
                result += '\\u' + hex;
            } else {
                result += c;
            }
        }
        return result;
    }

    private static HttpResponse ejecutarCalloutApi(String path, String method, String requestBody) {
        String endpoint = 'callout:' + NAMED_CREDENTIAL + path;
        logInfo('ejecutarCalloutApi | endpoint=' + endpoint + ' | method=' + method);
        HttpRequest req = new HttpRequest();
        req.setEndpoint(endpoint);
        req.setMethod(method);
        req.setTimeout(TIMEOUT_MS);
        if (requestBody != null) {
            req.setHeader('Content-Type', 'application/json');
            req.setBody(requestBody);
            System.debug('requestBody: ' + requestBody);
            System.debug('requestBody: ' + JSON.serialize(requestBody));
        }
        Http http = new Http();
        HttpResponse res = http.send(req);
        logInfo('ejecutarCalloutApi | response status=' + res.getStatusCode() + ' ' + res.getStatus());
        return res;
    }

    private static HttpResponse ejecutarPutBinario(String uploadUrl, Blob pdfBody) {
        logInfo('ejecutarPutBinario | url length=' + uploadUrl.length());
        HttpRequest req = new HttpRequest();
        req.setEndpoint(uploadUrl);
        req.setMethod('PUT');
        req.setHeader('Content-Type', 'application/pdf');
        req.setBodyAsBlob(pdfBody);
        req.setTimeout(TIMEOUT_MS);
        Http http = new Http();
        return http.send(req);
    }

    private static void validarRespuestaExito(HttpResponse res, String operacion) {
        Integer status = res.getStatusCode();
        if (status < 200 || status >= 300) {
            String body = res.getBody();
            String bodySnippet = body != null && body.length() > LOG_BODY_MAX_LENGTH
                ? body.substring(0, LOG_BODY_MAX_LENGTH) + '...'
                : body;
            logError(operacion + ' | status=' + status + ' | body=' + bodySnippet);
            throw new ICB_FirmaDigitalException(operacion + ' fallido: ' + status + ' ' + res.getStatus() + (body != null ? ' | ' + bodySnippet : ''));
        }
    }

    private static void logInfo(String message) {
        System.debug(LoggingLevel.INFO, LOG_PREFIX + ' ' + message);
    }

    private static void logError(String message) {
        System.debug(LoggingLevel.ERROR, LOG_PREFIX + ' ' + message);
    }

    private static String endpointForPath(String path) {
        return 'callout:' + NAMED_CREDENTIAL + path;
    }

    private static String responseHeadersToString(HttpResponse res) {
        if (res == null) return null;
        List<String> parts = new List<String>();
        for (String key : res.getHeaderKeys()) {
            if (String.isNotBlank(key)) {
                parts.add(key + ': ' + res.getHeader(key));
            }
        }
        return parts.isEmpty() ? null : String.join(parts, '\n');
    }

    public class ICB_FirmaDigitalException extends Exception {
    }
}