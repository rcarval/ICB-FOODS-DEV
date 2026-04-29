public with sharing class FlowExecutionValidator {
    @InvocableMethod
    public static List<Boolean> validateFlowExecution(List<Id> accountIds) {
        List<Boolean> results = new List<Boolean>();
        List<Account> accounts = [SELECT Id, CreatedDate FROM Account WHERE Id IN :accountIds];
        
        DateTime currentTime = DateTime.now();
        for (Account acc : accounts) {
            // Verificar si han pasado al menos 5 minutos desde el CreatedDate
            if (acc.CreatedDate.addMinutes(5) <= currentTime) {
                results.add(true); // Permitir la ejecución del Flow
            } else {
                results.add(false); // Bloquear la ejecución del Flow
            }
        }
        return results;
    }
}