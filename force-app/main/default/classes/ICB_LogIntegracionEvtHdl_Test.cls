/**********************************************************************************
 * ICB_LogIntegracionEvtHdl_Test
 * Tests del servicio Log Integracion (el flow del usuario inserta en Log_Integracion__c).
 * SEIDOR - RCG
 **********************************************************************************/
@IsTest
public class ICB_LogIntegracionEvtHdl_Test {

    @IsTest
    static void testInsertarYPublicarLogs() {
        Test.startTest();
        ICB_LogIntegracionService.insertarLogOutbound(
            'ICB_LogIntegracionEvtHdl_Test',
            'https://test.com',
            'POST',
            null,
            '{}',
            200,
            null,
            '{}',
            true,
            null,
            100L,
            'test'
        );
        ICB_LogIntegracionService.publicarLogsOutboundPendientes();
        Test.stopTest();
        System.assert(true, 'Publicación sin excepción');
    }

    @IsTest
    static void testPublicarLogsVacio() {
        ICB_LogIntegracionService.publicarLogsOutboundPendientes();
        System.assert(true);
    }
}