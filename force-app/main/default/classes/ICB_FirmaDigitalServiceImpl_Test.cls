/**********************************************************************************
 * ICB_FirmaDigitalServiceImpl_Test - Tests del servicio API Firma Digital. SEIDOR - RCG
 **********************************************************************************/
@IsTest
public class ICB_FirmaDigitalServiceImpl_Test {

    private class UploadMock implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(200);
            res.setHeader('Content-Type', 'application/json');
            res.setBody(
                '{"success":true,"contratoId":"COMOD-2025-001","uploadUrl":"https://icbfs-documents-qa.s3.amazonaws.com/unsigned/COMOD-2025-001?X-Amz-...","expiresAt":"2025-01-28T15:45:00Z"}'
            );
            return res;
        }
    }

    private class PutS3Mock implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(200);
            return res;
        }
    }

    private class DownloadMock implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(200);
            res.setHeader('Content-Type', 'application/json');
            res.setBody(
                '{"contratoId":"COMOD-2025-001","tufirmaDocumentId":"69a0b2e309d04c70a6d2aa0e","downloadURL":"https://icbfs-documents-qa.s3.amazonaws.com/signed/COMOD-2025-001/documento.pdf","expiresIn":900,"signedS3Key":"signed/COMOD-2025-001/...","completedAt":"2025-01-28T16:00:00Z"}'
            );
            return res;
        }
    }

    private class UploadYPutMock implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            HttpResponse res = new HttpResponse();
            if (req.getMethod() == 'POST' && req.getEndpoint().contains('/v1/firma/upload')) {
                res.setStatusCode(200);
                res.setHeader('Content-Type', 'application/json');
                res.setBody(
                    '{"success":true,"contratoId":"COMOD-2025-001","uploadUrl":"https://s3.mock.amazonaws.com/unsigned/COMOD?X-Amz-...","expiresAt":"2025-01-28T15:45:00Z"}'
                );
            } else if (req.getMethod() == 'PUT') {
                res.setStatusCode(200);
            } else {
                res.setStatusCode(404);
            }
            return res;
        }
    }

    @IsTest
    static void testSolicitarUploadUrl_OK() {
        Test.setMock(HttpCalloutMock.class, new UploadMock());
        ICB_FirmaDigitalServiceImpl.UploadRequestDto req = new ICB_FirmaDigitalServiceImpl.UploadRequestDto();
        req.contratoId = 'COMOD-2025-001';
        req.fileName = 'contrato.pdf';
        req.signatureConfig = new ICB_FirmaDigitalServiceImpl.SignatureConfigDto();
        req.signatureConfig.nombre = 'Contrato Comodato';
        req.signatureConfig.firmantes = new List<ICB_FirmaDigitalServiceImpl.FirmanteDto>();
        ICB_FirmaDigitalServiceImpl.FirmanteDto f = new ICB_FirmaDigitalServiceImpl.FirmanteDto();
        f.nombre = 'Juan Pérez';
        f.email = 'juan@empresa.cl';
        f.rut = '12.345.678-9';
        req.signatureConfig.firmantes.add(f);

        Test.startTest();
        ICB_FirmaDigitalServiceImpl.UploadResponseDto resp = ICB_FirmaDigitalServiceImpl.solicitarUploadUrl(req);
        Test.stopTest();

        System.assert(resp != null, 'Respuesta no debe ser nula');
        System.assert(resp.success == true, 'success debe ser true');
        System.assertEquals('COMOD-2025-001', resp.contratoId, 'contratoId debe coincidir');
        System.assert(String.isNotBlank(resp.uploadUrl), 'uploadUrl debe venir informada');
    }

    @IsTest
    static void testSolicitarUploadUrl_SinContratoId_LanzaExcepcion() {
        ICB_FirmaDigitalServiceImpl.UploadRequestDto req = new ICB_FirmaDigitalServiceImpl.UploadRequestDto();
        req.contratoId = '';
        req.fileName = 'contrato.pdf';

        Boolean lanzada = false;
        try {
            ICB_FirmaDigitalServiceImpl.solicitarUploadUrl(req);
        } catch (ICB_FirmaDigitalServiceImpl.ICB_FirmaDigitalException e) {
            lanzada = true;
        }
        System.assert(lanzada, 'Debe lanzar ICB_FirmaDigitalException cuando contratoId está vacío');
    }

    @IsTest
    static void testSubirPdfAUploadUrl_OK() {
        Test.setMock(HttpCalloutMock.class, new PutS3Mock());
        String uploadUrl = 'https://s3.mock.amazonaws.com/unsigned/test?X-Amz-...';
        Blob pdfBody = Blob.valueOf('%PDF-1.4 fake content');

        Test.startTest();
        ICB_FirmaDigitalServiceImpl.subirPdfAUploadUrl(uploadUrl, pdfBody);
        Test.stopTest();

        System.assert(true, 'PUT debe completar sin excepción');
    }

    @IsTest
    static void testSubirPdfAUploadUrl_UrlVacia_LanzaExcepcion() {
        Boolean lanzada = false;
        try {
            ICB_FirmaDigitalServiceImpl.subirPdfAUploadUrl('', Blob.valueOf('x'));
        } catch (ICB_FirmaDigitalServiceImpl.ICB_FirmaDigitalException e) {
            lanzada = true;
        }
        System.assert(lanzada, 'Debe lanzar excepción con URL vacía');
    }

    @IsTest
    static void testSolicitarUrlDescarga_OK() {
        Test.setMock(HttpCalloutMock.class, new DownloadMock());

        Test.startTest();
        ICB_FirmaDigitalServiceImpl.DownloadResponseDto resp = ICB_FirmaDigitalServiceImpl.solicitarUrlDescarga('COMOD-2025-001');
        Test.stopTest();

        System.assert(resp != null, 'Respuesta no debe ser nula');
        System.assert(String.isNotBlank(resp.downloadURL), 'downloadURL debe venir');
    }

    private class Upload403Mock implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(403);
            res.setStatus('Forbidden');
            res.setBody('{"message":"Forbidden"}');
            return res;
        }
    }

    @IsTest
    static void testSolicitarUploadUrl_403_LanzaExcepcion() {
        Test.setMock(HttpCalloutMock.class, new Upload403Mock());
        ICB_FirmaDigitalServiceImpl.UploadRequestDto req = new ICB_FirmaDigitalServiceImpl.UploadRequestDto();
        req.contratoId = 'TEST';
        req.fileName = 'test.pdf';

        Boolean lanzada = false;
        try {
            ICB_FirmaDigitalServiceImpl.solicitarUploadUrl(req);
        } catch (ICB_FirmaDigitalServiceImpl.ICB_FirmaDigitalException e) {
            lanzada = true;
        }
        System.assert(lanzada, 'Debe lanzar ICB_FirmaDigitalException cuando el API responde 403');
    }
}