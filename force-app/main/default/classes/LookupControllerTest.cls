@IsTest
public class LookupControllerTest {

    @TestSetup
    static void makeData(){
        TestUtils.makeTestData();
    }

    @IsTest
    static void testSearchWithSearchTermAndFilter() {
        // Arrange
        String searchTerm = 'Test';
        String myObject = 'Account';
        String filter = '';
        Map<String, List<String>> fieldValues = new Map<String, List<String>>{
            'RecordType.DeveloperName' => new List<String>{'Negocio'}
        };
        Integer offset = 0;
        
        // Act
        Test.startTest();
        List<SObject> results = LookupController.search(searchTerm, myObject, filter, fieldValues, offset);
        Test.stopTest();
        
        // Assert
        System.assertNotEquals(0, results.size(), 'Expected at least one result.');
        System.assertEquals('Test Account', (String)results[0].get('Name'), 'Expected Test Account to be in the results.');
    }
    
    @IsTest
    static void testSearchWithId() {
        // Arrange
        Account testAccount = [SELECT Id FROM Account LIMIT 1];
        String searchTerm = testAccount.Id;
        String myObject = 'Account';
        String filter = '';
        Map<String, List<String>> fieldValues = new Map<String, List<String>>{
            'RecordType.DeveloperName' => new List<String>{'Negocio'}
        };
        Integer offset = 0;
        
        // Act
        Test.startTest();
        List<SObject> results = LookupController.search(searchTerm, myObject, filter, fieldValues, offset);
        Test.stopTest();
        
        // Assert
        System.assertNotEquals(0, results.size(), 'Expected at least one result.');
        System.assertEquals(testAccount.Id, results[0].Id, 'Expected the result to match the ID of the test account.');
    }
    
    @IsTest
    static void testSearchWithEmptySearchTerm() {
        // Arrange
        String searchTerm = '';
        String myObject = 'Account';
        String filter = '';
        Map<String, List<String>> fieldValues = new Map<String, List<String>>{
            'RecordType.DeveloperName' => new List<String>{'Negocio'}
        };
        Integer offset = 0;
        
        // Act
        Test.startTest();
        List<SObject> results = LookupController.search(searchTerm, myObject, filter, fieldValues, offset);
        Test.stopTest();
        
        // Assert
        System.assertNotEquals(0, results.size(), 'Expected at least one result.');
    }
    
    @IsTest
    static void testSearchWithOffset() {
        // Arrange
        String searchTerm = 'Product';
        String myObject = 'Product2';
        String filter = null;
        Map<String, List<String>> fieldValues = new Map<String, List<String>>();
        Integer offset = 5;
        
        // Act
        Test.startTest();
        List<SObject> results = LookupController.search(searchTerm, myObject, filter, fieldValues, offset);
        Test.stopTest();
        
        // Assert
        System.assertEquals(5, results.size(), 'Expected exactly 5 results due to the offset.');
    }
}