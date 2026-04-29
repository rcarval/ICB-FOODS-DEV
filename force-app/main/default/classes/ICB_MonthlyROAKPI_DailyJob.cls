/**********************************************************************************
Desarrollado por: SEIDOR
Autor: Rodrigo Carvallo (RCG)
Proyecto: Ticket N°00024464 - Historico de ROAs
Descripción: Clase Schedulable para ejecutar diariamente el cálculo de métricas mensuales de ROA
Test: ICB_MonthlyROAKPI_AllTests

---------------------------------------------------------------------------------
No. Fecha                Autor                     Descripción
------ ---------- ---------------------------------------------------------------
1.0 22-12-2025            RCG                Creación de la clase.
**********************************************************************************/
global without sharing class ICB_MonthlyROAKPI_DailyJob implements Schedulable {
    
    /**
    * Método execute requerido por la interfaz Schedulable
    * Ejecuta la lógica de cálculo de KPI mensual para todos los Owners activos
    * @author Rodrigo Carvallo
    * @param SchedulableContext sc - Contexto del job programado
    **/
    global void execute(SchedulableContext sc) {
        // Ejecuta la lógica de KPI mensual para todos los Owners
        ICB_MonthlyROAKPIService.upsertMonthlyKPI(null);
    }
}