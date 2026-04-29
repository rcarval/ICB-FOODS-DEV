public class BatchDeleteDetalles implements Database.Batchable<SObject> {

    private Date cutoffDate;

    public BatchDeleteDetalles() {
        // Mantener solo últimos 15 días
        cutoffDate = Date.today().addDays(-15);
    }

    public Database.QueryLocator start(Database.BatchableContext bc) {
        // Detalles cuya Venta está fuera del rango de 15 días
        return Database.getQueryLocator([
            SELECT Id
            FROM Detalle__c
            WHERE Venta__r.Fecha_de_Venta__c < :cutoffDate
        ]);
    }

    public void execute(Database.BatchableContext bc, List<Detalle__c> scope) {
        delete scope;
    }

    public void finish(Database.BatchableContext bc) {
        // Sin logs
    }
}