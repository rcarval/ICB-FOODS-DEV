@IsTest
public with sharing class FlowExecutionValidatorTest {
    
    @TestSetup
    static void makeData(){
        TestUtils.makeTestData();
    }

    @IsTest
    static void validateFiveMinutesNotPassed(){
    
        List<Account> accountList = [SELECT Id FROM Account LIMIT 1];
        List<Id> accListIds = new List<Id>();
        for (Account acc : accountList) {
            accListIds.add(acc.Id);
        }
        List<Boolean> resultList;

        Test.startTest();
        resultList = FlowExecutionValidator.validateFlowExecution(accListIds);
        Test.stopTest();
        
        Assert.isFalse(resultList[0], 'No deberian haber pasado mas de 5 minutos desde la creacion de la cuenta');
    }

    @IsTest
    static void validateFiveMinutesPassed(){
    
        List<Account> accountList = [SELECT Id, CreatedDate FROM Account LIMIT 1];
        List<Id> accListIds = new List<Id>();
        for (Account acc : accountList) {
            Test.setCreatedDate(acc.Id, acc.CreatedDate.addMinutes(-6));
            accListIds.add(acc.Id);
        }
        List<Boolean> resultList;

        Test.startTest();
        resultList = FlowExecutionValidator.validateFlowExecution(accListIds);
        Test.stopTest();
        
        Assert.isTrue(resultList[0], 'Deberían haber pasado mas de 5 minutos desde la creacion de la cuenta');
    }
}