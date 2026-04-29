public class BatchDeleteVentas implements Database.Batchable<SObject> {

    private Date cutoffDate;

    public BatchDeleteVentas() {
        cutoffDate = Date.today().addDays(-15);
    }

    public Database.QueryLocator start(Database.BatchableContext bc) {
        return Database.getQueryLocator([
            SELECT Id
            FROM Venta__c
            WHERE Fecha_de_Venta__c < :cutoffDate
        ]);
    }

    public void execute(Database.BatchableContext bc, List<Venta__c> scope) {
        delete scope;
    }

    public void finish(Database.BatchableContext bc) {
        // Sin logs
    }
}