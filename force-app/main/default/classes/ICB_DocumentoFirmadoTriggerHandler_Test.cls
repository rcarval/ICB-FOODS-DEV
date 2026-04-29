/**********************************************************************************
 * ICB_DocumentoFirmadoTriggerHandler_Test - Tests del handler DocumentoFirmado__e. SEIDOR - RCG
 **********************************************************************************/
@IsTest
public class ICB_DocumentoFirmadoTriggerHandler_Test {

    @TestSetup
    static void setup() {
        Contrato_Digital__c c = new Contrato_Digital__c();
        c.Contrato_ID__c = 'FD-PE-TEST-001';
        c.Estado__c = 'Enviado';
        insert c;
    }

    @IsTest
    static void testOnAfterInsert_actualizaContrato() {
        List<DocumentoFirmado__e> events = new List<DocumentoFirmado__e>();
        DocumentoFirmado__e e = new DocumentoFirmado__e();
        e.ContratoId__c = 'FD-PE-TEST-001';
        e.Estado__c = 'Firmado';
        e.ExternalTransactionId__c = 'TF-EXT-123';
        e.FechaFirma__c = DateTime.now();
        e.PdfFirmadoUrl__c = 'https://ejemplo.com/firmado.pdf';
        e.RawPayload__c = '{"test":true}';
        events.add(e);

        Test.startTest();
        ICB_DocumentoFirmadoTriggerHandler.onAfterInsert(events);
        Test.stopTest();

        Contrato_Digital__c updated = [SELECT Id, Estado__c, Documento_ID_TuFirma_del__c, PDF_Firmado_URL__c, Fecha_Firma__c FROM Contrato_Digital__c WHERE Contrato_ID__c = 'FD-PE-TEST-001' LIMIT 1];
        System.assertEquals('Firmado', updated.Estado__c, 'Estado__c');
        System.assertEquals('TF-EXT-123', updated.Documento_ID_TuFirma_del__c, 'Documento_ID_TuFirma_del__c');
        System.assertEquals('https://ejemplo.com/firmado.pdf', updated.PDF_Firmado_URL__c, 'PDF_Firmado_URL__c');
        System.assert(updated.Fecha_Firma__c != null, 'Fecha_Firma__c');
    }

    @IsTest
    static void testOnAfterInsert_mapeaEstadoSignedAFirmado() {
        List<DocumentoFirmado__e> events = new List<DocumentoFirmado__e>();
        DocumentoFirmado__e e = new DocumentoFirmado__e();
        e.ContratoId__c = 'FD-PE-TEST-001';
        e.Estado__c = 'signed';
        events.add(e);

        Test.startTest();
        ICB_DocumentoFirmadoTriggerHandler.onAfterInsert(events);
        Test.stopTest();

        Contrato_Digital__c updated = [SELECT Estado__c FROM Contrato_Digital__c WHERE Contrato_ID__c = 'FD-PE-TEST-001' LIMIT 1];
        System.assertEquals('Firmado', updated.Estado__c, 'signed debe mapearse a Firmado');
    }

    @IsTest
    static void testOnAfterInsert_contratoNoEncontrado_noFalla() {
        List<DocumentoFirmado__e> events = new List<DocumentoFirmado__e>();
        DocumentoFirmado__e e = new DocumentoFirmado__e();
        e.ContratoId__c = 'NO-EXISTE';
        e.Estado__c = 'Firmado';
        events.add(e);

        Test.startTest();
        ICB_DocumentoFirmadoTriggerHandler.onAfterInsert(events);
        Test.stopTest();

        Integer count = [SELECT COUNT() FROM Contrato_Digital__c WHERE Contrato_ID__c = 'NO-EXISTE'];
        System.assertEquals(0, count);
    }

    @IsTest
    static void testOnAfterInsert_listaVacia() {
        ICB_DocumentoFirmadoTriggerHandler.onAfterInsert(new List<DocumentoFirmado__e>());
    }

    @IsTest
    static void testOnAfterInsert_contratoIdBlank() {
        List<DocumentoFirmado__e> events = new List<DocumentoFirmado__e>();
        events.add(new DocumentoFirmado__e());
        ICB_DocumentoFirmadoTriggerHandler.onAfterInsert(events);
    }

    @IsTest
    static void testTrigger_EjecutaTriggerYHandler() {
        DocumentoFirmado__e evt = new DocumentoFirmado__e();
        evt.ContratoId__c = 'FD-PE-TEST-001';
        evt.Estado__c = 'signed';

        Test.startTest();
        EventBus.publish(evt);
        Test.getEventBus().deliver();
        Test.stopTest();

        Contrato_Digital__c updated = [SELECT Estado__c FROM Contrato_Digital__c WHERE Contrato_ID__c = 'FD-PE-TEST-001' LIMIT 1];
        System.assertEquals('Firmado', updated.Estado__c);
    }

    @IsTest
    static void testOnAfterInsert_mapeaEstadosVarios() {
        Contrato_Digital__c c2 = new Contrato_Digital__c(Contrato_ID__c = 'FD-TEST-002', Estado__c = 'Enviado');
        insert c2;
        Contrato_Digital__c c3 = new Contrato_Digital__c(Contrato_ID__c = 'FD-TEST-003', Estado__c = 'Enviado');
        insert c3;
        Contrato_Digital__c c4 = new Contrato_Digital__c(Contrato_ID__c = 'FD-TEST-004', Estado__c = 'Enviado');
        insert c4;

        List<DocumentoFirmado__e> events = new List<DocumentoFirmado__e>();
        DocumentoFirmado__e e1 = new DocumentoFirmado__e();
        e1.ContratoId__c = 'FD-TEST-002';
        e1.Estado__c = 'rejected';
        events.add(e1);
        DocumentoFirmado__e e2 = new DocumentoFirmado__e();
        e2.ContratoId__c = 'FD-TEST-003';
        e2.Estado__c = 'expired';
        events.add(e2);
        DocumentoFirmado__e e3 = new DocumentoFirmado__e();
        e3.ContratoId__c = 'FD-TEST-004';
        e3.Estado__c = 'sent';
        events.add(e3);

        ICB_DocumentoFirmadoTriggerHandler.onAfterInsert(events);

        Contrato_Digital__c u2 = [SELECT Estado__c FROM Contrato_Digital__c WHERE Contrato_ID__c = 'FD-TEST-002'];
        System.assertEquals('Rechazado', u2.Estado__c);
        Contrato_Digital__c u3 = [SELECT Estado__c FROM Contrato_Digital__c WHERE Contrato_ID__c = 'FD-TEST-003'];
        System.assertEquals('Expirado', u3.Estado__c);
        Contrato_Digital__c u4 = [SELECT Estado__c FROM Contrato_Digital__c WHERE Contrato_ID__c = 'FD-TEST-004'];
        System.assertEquals('Enviado', u4.Estado__c);
    }

    @IsTest
    static void testOnAfterInsert_fechaFirmaSinEstado() {
        Contrato_Digital__c c = new Contrato_Digital__c(Contrato_ID__c = 'FD-FECHA-TEST', Estado__c = 'Enviado');
        insert c;

        List<DocumentoFirmado__e> events = new List<DocumentoFirmado__e>();
        DocumentoFirmado__e e = new DocumentoFirmado__e();
        e.ContratoId__c = 'FD-FECHA-TEST';
        e.FechaFirma__c = DateTime.now();
        e.PdfFirmadoUrl__c = 'https://url.pdf';
        events.add(e);

        ICB_DocumentoFirmadoTriggerHandler.onAfterInsert(events);

        Contrato_Digital__c updated = [SELECT Estado__c, PDF_Firmado_URL__c, Fecha_Firma__c FROM Contrato_Digital__c WHERE Contrato_ID__c = 'FD-FECHA-TEST'];
        System.assertEquals('Firmado', updated.Estado__c);
        System.assertEquals('https://url.pdf', updated.PDF_Firmado_URL__c);
        System.assert(updated.Fecha_Firma__c != null);
    }

    @IsTest
    static void testOnAfterInsert_null() {
        ICB_DocumentoFirmadoTriggerHandler.onAfterInsert(null);
    }
}