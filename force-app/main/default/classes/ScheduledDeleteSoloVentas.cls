public class ScheduledDeleteSoloVentas implements Schedulable {
    public void execute(SchedulableContext sc) {
        Database.executeBatch(new BatchDeleteVentas(), 200);
    }
}