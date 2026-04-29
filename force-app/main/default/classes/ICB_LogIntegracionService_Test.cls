/**********************************************************************************
 * ICB_LogIntegracionService_Test
 * Tests del servicio que publica Log_Integracion_Event__e.
 * El flujo asíncrono del usuario inserta en Log_Integracion__c.
 * SEIDOR - RCG
 **********************************************************************************/
@IsTest
public class ICB_LogIntegracionService_Test {

    @IsTest
    static void testInsertarLogOutbound_Exito() {
        Test.startTest();
        ICB_LogIntegracionService.insertarLogOutbound(
            'Test.servicio',
            'https://api.test.com/endpoint',
            'POST',
            'Content-Type: application/json',
            '{"key":"value"}',
            200,
            'Content-Type: application/json',
            '{"success":true}',
            true,
            null,
            150L,
            'FD-001'
        );
        ICB_LogIntegracionService.publicarLogsOutboundPendientes();
        Test.stopTest();
        // Solo verifica que no lance excepción. El flujo asíncrono inserta en Log_Integracion__c.
    }

    @IsTest
    static void testInsertarLogOutbound_Error() {
        Test.startTest();
        ICB_LogIntegracionService.insertarLogOutbound(
            'Test.servicioError',
            'https://api.test.com/error',
            'GET',
            null,
            null,
            500,
            null,
            '{"error":"Internal Server Error"}',
            false,
            'Error 500',
            2000L,
            null
        );
        ICB_LogIntegracionService.publicarLogsOutboundPendientes();
        Test.stopTest();
    }

    @IsTest
    static void testInsertarLogInbound_Exito() {
        Test.startTest();
        ICB_LogIntegracionService.insertarLogInbound(
            'Test.inbound',
            '{"ContratoId__c":"FD-001","Estado__c":"Firmado"}',
            true,
            null,
            'Procesados: 1'
        );
        Test.stopTest();
    }

    @IsTest
    static void testInsertarLogInbound_Error() {
        Test.startTest();
        ICB_LogIntegracionService.insertarLogInbound(
            'Test.inboundError',
            '{}',
            false,
            'Contrato no encontrado',
            'FD-NO-EXISTE'
        );
        Test.stopTest();
    }
}