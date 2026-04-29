public class ScheduledDeleteVentas implements Schedulable {
    public void execute(SchedulableContext sc) {
        // 1️⃣ Primero borrar detalles
        Database.executeBatch(new BatchDeleteDetalles(), 200);

        // 2️⃣ Luego programar borrado de ventas después de 5 minutos
        System.schedule(
            'Delete Ventas After Detalles ' + Datetime.now(),
            Datetime.now().addMinutes(5).format('s m H d M ? yyyy'),
            new ScheduledDeleteSoloVentas()
        );
    }
}