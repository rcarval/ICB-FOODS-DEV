@IsTest
public class ICBFS_QuicksightEmbedControllerTest {

    /* ============================================================
       MOCK DEL CALLOUT A AWS / QUICK SIGHT
       ============================================================ */
    private class QuickSightMock implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(200);
            res.setHeader('Content-Type', 'application/json');

            res.setBody(
                '{"embedUrl":"https://quicksight.aws.amazon.com/embed/test","status":200,"requestId":"req-123"}'
            );
            return res;
        }
    }

    /* ============================================================
       TEST: getEmbedUrlForDashboard
       ============================================================ */
    @IsTest
    static void testGetEmbedUrlForDashboard_OK() {
        // Arrange
        Test.setMock(HttpCalloutMock.class, new QuickSightMock());

        // Act
        Test.startTest();
        String embedUrl = ICBFS_QuicksightEmbedController.getEmbedUrlForDashboard('DASHBOARD_TEST');
        Test.stopTest();

        // Assert
        System.assertNotEquals(
            null,
            embedUrl,
            'La URL embed no debería ser nula'
        );
        System.assert(
            embedUrl.contains('quicksight'),
            'La URL debería contener quicksight'
        );
    }

    /* ============================================================
       TEST: getDashboardOptions
       ============================================================ */
    @IsTest
    static void testGetDashboardOptions() {
        // Act
        Test.startTest();
        List<ICBFS_QuicksightEmbedController.LabelValue> options =
            ICBFS_QuicksightEmbedController.getDashboardOptions();
        Test.stopTest();

        // Assert
        System.assertNotEquals(
            null,
            options,
            'La lista de dashboards no debe ser nula'
        );
        // No forzamos cantidad, depende de metadata existente
    }

    /* ============================================================
       TEST: Callout error (status != 200)
       ============================================================ */
    private class QuickSightErrorMock implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(500);
            res.setBody('Error interno');
            return res;
        }
    }

    @IsTest
    static void testGetEmbedUrlForDashboard_Error() {
        // Arrange
        Test.setMock(HttpCalloutMock.class, new QuickSightErrorMock());

        Boolean exceptionThrown = false;

        // Act
        Test.startTest();
        try {
            ICBFS_QuicksightEmbedController.getEmbedUrlForDashboard('DASHBOARD_ERROR');
        } catch (Exception e) {
            exceptionThrown = true;
        }
        Test.stopTest();

        // Assert
        System.assert(
            exceptionThrown,
            'Debe lanzar excepción cuando el callout falla'
        );
    }
}