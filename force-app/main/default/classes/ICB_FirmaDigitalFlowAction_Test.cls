/**********************************************************************************
 * ICB_FirmaDigitalFlowAction_Test - Tests de la acción invocable Firma Digital. SEIDOR - RCG
 **********************************************************************************/
@IsTest
public class ICB_FirmaDigitalFlowAction_Test {

    private class UploadAndPutMock implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            if (req.getMethod() == 'POST' && req.getEndpoint().contains('/v1/firma/upload')) {
                res.setStatusCode(200);
                res.setHeader('Content-Type', 'application/json');
                res.setBody(
                    '{"success":true,"contratoId":"FD-Q-001","uploadUrl":"https://s3.mock.amazonaws.com/unsigned/FD-Q-001?X-Amz-...","expiresAt":"2025-01-28T15:45:00Z"}'
                );
            } else if (req.getMethod() == 'PUT') {
                res.setStatusCode(200);
            } else {
                res.setStatusCode(404);
            }
            return res;
        }
    }

    @TestSetup
    static void setup() {
        Account acc = new Account(
            Name = 'Cliente Firma Digital Test'
        );
        insert acc;

        Contact con = new Contact(
            LastName = 'Firmante Test',
            AccountId = acc.Id,
            Email = 'firmadigital@test.com',
            MobilePhone = '+56912345678',
            RUT__c = '11111111-1'
        );
        insert con;

        Opportunity opp = new Opportunity(
            Name = 'Opp Test Firma',
            StageName = 'Prospecting',
            CloseDate = Date.today().addDays(30),
            AccountId = acc.Id
        );
        insert opp;

        Quote q = new Quote(
            Name = 'Cotización Firma Test',
            OpportunityId = opp.Id,
            ContactId = con.Id,
            Pricebook2Id = Test.getStandardPricebookId()
        );
        insert q;
    }

    private static String getPdfBase64Test() {
        return EncodingUtil.base64Encode(Blob.valueOf('%PDF-1.4 fake pdf content'));
    }

    @IsTest
    static void testEnviarPdfAFirmaDigital_Ok() {
        Quote q = [SELECT Id, QuoteNumber FROM Quote LIMIT 1];

        ICB_FirmaDigitalFlowAction.InvocableInput input = new ICB_FirmaDigitalFlowAction.InvocableInput();
        input.quoteId = q.Id;
        input.pdfBase64 = getPdfBase64Test();
        input.pdfFileName = 'contrato_test.pdf';

        Test.setMock(HttpCalloutMock.class, new UploadAndPutMock());

        Test.startTest();
        List<ICB_FirmaDigitalFlowAction.InvocableOutput> outputs = ICB_FirmaDigitalFlowAction.enviarPdfAFirmaDigital(new List<ICB_FirmaDigitalFlowAction.InvocableInput>{ input });
        Test.stopTest();

        System.assert(!outputs.isEmpty(), 'Debe devolver una salida');
        ICB_FirmaDigitalFlowAction.InvocableOutput out = outputs[0];
        System.assert(out.success == true, 'success debe ser true');
        System.assert(String.isNotBlank(out.contratoId), 'contratoId debe venir');
        System.assert(out.errorMessage == null, 'errorMessage debe ser null');
        // contratoDigitalId puede ser null si el objeto Contrato_Digital__c no existe en la org de test
        if (String.isNotBlank(out.contratoDigitalId)) {
            List<SObject> contratos = Database.query('SELECT Id FROM Contrato_Digital__c WHERE Id = \'' + out.contratoDigitalId + '\'');
            System.assert(!contratos.isEmpty(), 'Debe existir registro en Contrato_Digital__c');
        }
    }

    @IsTest
    static void testEnviarPdfAFirmaDigital_QuoteIdVacio() {
        ICB_FirmaDigitalFlowAction.InvocableInput input = new ICB_FirmaDigitalFlowAction.InvocableInput();
        input.quoteId = '';
        input.pdfBase64 = getPdfBase64Test();

        List<ICB_FirmaDigitalFlowAction.InvocableOutput> outputs = ICB_FirmaDigitalFlowAction.enviarPdfAFirmaDigital(new List<ICB_FirmaDigitalFlowAction.InvocableInput>{ input });

        System.assert(!outputs.isEmpty());
        System.assert(outputs[0].success == false);
        System.assert(String.isNotBlank(outputs[0].errorMessage));
    }

    @IsTest
    static void testEnviarPdfAFirmaDigital_PdfBase64Vacio() {
        Quote q = [SELECT Id FROM Quote LIMIT 1];
        ICB_FirmaDigitalFlowAction.InvocableInput input = new ICB_FirmaDigitalFlowAction.InvocableInput();
        input.quoteId = q.Id;
        input.pdfBase64 = '';

        List<ICB_FirmaDigitalFlowAction.InvocableOutput> outputs = ICB_FirmaDigitalFlowAction.enviarPdfAFirmaDigital(new List<ICB_FirmaDigitalFlowAction.InvocableInput>{ input });

        System.assert(!outputs.isEmpty());
        System.assert(outputs[0].success == false);
        System.assert(String.isNotBlank(outputs[0].errorMessage));
    }

    @IsTest
    static void testEnviarPdfAFirmaDigital_DataUrlPrefix() {
        Quote q = [SELECT Id FROM Quote LIMIT 1];
        ICB_FirmaDigitalFlowAction.InvocableInput input = new ICB_FirmaDigitalFlowAction.InvocableInput();
        input.quoteId = q.Id;
        input.pdfBase64 = 'data:application/pdf;base64,' + EncodingUtil.base64Encode(Blob.valueOf('%PDF-1.4 x')).toString();
        input.pdfFileName = 'doc';

        Test.setMock(HttpCalloutMock.class, new UploadAndPutMock());
        Test.startTest();
        List<ICB_FirmaDigitalFlowAction.InvocableOutput> outputs = ICB_FirmaDigitalFlowAction.enviarPdfAFirmaDigital(new List<ICB_FirmaDigitalFlowAction.InvocableInput>{ input });
        Test.stopTest();

        System.assert(!outputs.isEmpty());
        System.assert(outputs[0].success == true);
    }

    @IsTest
    static void testEnviarPdfAFirmaDigital_QuoteSinContact() {
        Account acc = new Account(Name = 'Sin Contact');
        insert acc;
        Opportunity opp = new Opportunity(Name = 'Opp', StageName = 'Prospecting', CloseDate = Date.today().addDays(30), AccountId = acc.Id);
        insert opp;
        Quote q = new Quote(Name = 'Q sin contact', OpportunityId = opp.Id, Pricebook2Id = Test.getStandardPricebookId());
        insert q;

        ICB_FirmaDigitalFlowAction.InvocableInput input = new ICB_FirmaDigitalFlowAction.InvocableInput();
        input.quoteId = q.Id;
        input.pdfBase64 = getPdfBase64Test();

        List<ICB_FirmaDigitalFlowAction.InvocableOutput> outputs = ICB_FirmaDigitalFlowAction.enviarPdfAFirmaDigital(new List<ICB_FirmaDigitalFlowAction.InvocableInput>{ input });

        System.assert(!outputs.isEmpty());
        System.assert(outputs[0].success == false);
        System.assert(String.isNotBlank(outputs[0].errorMessage));
    }

    private class Upload403Mock implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(403);
            res.setBody('{"message":"Forbidden"}');
            return res;
        }
    }

    @IsTest
    static void testEnviarPdfAFirmaDigital_ApiFalla() {
        Quote q = [SELECT Id FROM Quote LIMIT 1];
        ICB_FirmaDigitalFlowAction.InvocableInput input = new ICB_FirmaDigitalFlowAction.InvocableInput();
        input.quoteId = q.Id;
        input.pdfBase64 = getPdfBase64Test();
        input.pdfFileName = 'test.pdf';

        Test.setMock(HttpCalloutMock.class, new Upload403Mock());
        Test.startTest();
        List<ICB_FirmaDigitalFlowAction.InvocableOutput> outputs = ICB_FirmaDigitalFlowAction.enviarPdfAFirmaDigital(new List<ICB_FirmaDigitalFlowAction.InvocableInput>{ input });
        Test.stopTest();

        System.assert(!outputs.isEmpty());
        System.assert(outputs[0].success == false);
        System.assert(String.isNotBlank(outputs[0].errorMessage));
    }
}