/**********************************************************************************
 * ICB_ContratoDescargaCtrl_Test
 * Tests del controlador de descarga de PDF firmado.
 * SEIDOR - RCG
 **********************************************************************************/
@IsTest
public class ICB_ContratoDescargaCtrl_Test {

    private class DownloadOkMock implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(200);
            res.setHeader('Content-Type', 'application/json');
            res.setBody(
                '{"contratoId":"FD-TEST-001","tufirmaDocumentId":"abc123","downloadURL":"https://icbfs-documents-qa.s3.amazonaws.com/signed/FD-TEST-001/doc.pdf","expiresIn":900}'
            );
            return res;
        }
    }

    private class DownloadErrorMock implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(404);
            res.setStatus('Not Found');
            res.setBody('{"error":"Contrato no encontrado"}');
            return res;
        }
    }

    @IsTest
    static void testGetUrlDescargaPdf_ContratoDigital_OK() {
        Contrato_Digital__c c = new Contrato_Digital__c();
        c.Contrato_ID__c = 'FD-TEST-001';
        c.Estado__c = 'Firmado';
        insert c;

        Test.setMock(HttpCalloutMock.class, new DownloadOkMock());

        Test.startTest();
        ICB_ContratoDigitalDescargaController.DescargaResult result = ICB_ContratoDigitalDescargaController.getUrlDescargaPdf(c.Id);
        Test.stopTest();

        System.assert(result != null, 'Result no debe ser nulo');
        System.assert(String.isNotBlank(result.url), 'url debe venir');
        System.assert(result.url.contains('icbfs-documents-qa.s3'), 'url debe ser de S3');
        System.assert(result.error == null, 'error debe ser null');
    }

    @IsTest
    static void testGetUrlDescargaPdf_Quote_OK() {
        Account acc = new Account(Name = 'Test Account');
        insert acc;
        Contact con = new Contact(LastName = 'Test', AccountId = acc.Id, Email = 'test@test.com');
        insert con;
        Opportunity opp = new Opportunity(Name = 'Test Opp', StageName = 'Prospecting', CloseDate = Date.today(), AccountId = acc.Id);
        insert opp;

        Contrato_Digital__c contrato = new Contrato_Digital__c();
        contrato.Contrato_ID__c = 'FD-TEST-002';
        contrato.Estado__c = 'Firmado';
        insert contrato;

        Quote q = new Quote(Name = 'Test Quote', OpportunityId = opp.Id, ContactId = con.Id);
        insert q;
        q.Contrato_Digital__c = contrato.Id;
        update q;

        Test.setMock(HttpCalloutMock.class, new DownloadOkMock());

        Test.startTest();
        ICB_ContratoDigitalDescargaController.DescargaResult result = ICB_ContratoDigitalDescargaController.getUrlDescargaPdf(q.Id);
        Test.stopTest();

        System.assert(result != null, 'Result no debe ser nulo');
        System.assert(String.isNotBlank(result.url), 'url debe venir');
        System.assert(result.error == null, 'error debe ser null');
    }

    @IsTest
    static void testGetUrlDescargaPdf_RecordIdNull() {
        Test.startTest();
        ICB_ContratoDigitalDescargaController.DescargaResult result = ICB_ContratoDigitalDescargaController.getUrlDescargaPdf(null);
        Test.stopTest();

        System.assert(result != null, 'Result no debe ser nulo');
        System.assert(result.url == null, 'url debe ser null');
        System.assert(String.isNotBlank(result.error), 'error debe venir');
    }

    @IsTest
    static void testGetUrlDescargaPdf_QuoteSinContrato() {
        Account acc = new Account(Name = 'Test Account');
        insert acc;
        Contact con = new Contact(LastName = 'Test', AccountId = acc.Id, Email = 'test@test.com');
        insert con;
        Opportunity opp = new Opportunity(Name = 'Test Opp', StageName = 'Prospecting', CloseDate = Date.today(), AccountId = acc.Id);
        insert opp;

        Quote q = new Quote(Name = 'Test Quote', OpportunityId = opp.Id, ContactId = con.Id);
        insert q;
        // Quote sin Contrato_Digital__c

        Test.startTest();
        ICB_ContratoDigitalDescargaController.DescargaResult result = ICB_ContratoDigitalDescargaController.getUrlDescargaPdf(q.Id);
        Test.stopTest();

        System.assert(result != null, 'Result no debe ser nulo');
        System.assert(result.url == null, 'url debe ser null');
        System.assert(String.isNotBlank(result.error), 'error debe venir');
    }

    @IsTest
    static void testGetUrlDescargaPdf_ApiError() {
        Contrato_Digital__c c = new Contrato_Digital__c();
        c.Contrato_ID__c = 'FD-NO-EXISTE';
        c.Estado__c = 'Firmado';
        insert c;

        Test.setMock(HttpCalloutMock.class, new DownloadErrorMock());

        Test.startTest();
        ICB_ContratoDigitalDescargaController.DescargaResult result = ICB_ContratoDigitalDescargaController.getUrlDescargaPdf(c.Id);
        Test.stopTest();

        System.assert(result != null, 'Result no debe ser nulo');
        System.assert(result.url == null, 'url debe ser null');
        System.assert(String.isNotBlank(result.error), 'error debe venir');
    }
}