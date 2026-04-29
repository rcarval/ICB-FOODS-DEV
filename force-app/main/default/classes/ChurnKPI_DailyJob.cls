global without sharing class ChurnKPI_DailyJob implements Schedulable {
    global void execute(SchedulableContext sc) {
        // Ejecuta la lógica de KPI igual que en el script
        ChurnKPIService.upsertKPI(null);
    }
}