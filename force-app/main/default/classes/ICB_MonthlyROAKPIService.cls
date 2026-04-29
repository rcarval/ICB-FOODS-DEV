/**********************************************************************************
Desarrollado por: SEIDOR
Autor: Rodrigo Carvallo (RCG)
Proyecto: Ticket N°00024464 - Historico de ROAs
Descripción: Clase de servicio para calcular y almacenar métricas mensuales de ROA (Cartera Activa, Nuevos, Retenidos, Fugados, Recuperados) por Owner
Test: ICB_MonthlyROAKPI_AllTests

---------------------------------------------------------------------------------
No. Fecha                Autor                     Descripción
------ ---------- ---------------------------------------------------------------
1.0 22-12-2025            RCG                Creación de la clase.
**********************************************************************************/
public without sharing class ICB_MonthlyROAKPIService {

    /**
    * Método invocable para actualizar métricas mensuales de ROA por Owner
    * @author Rodrigo Carvallo
    * @param List<Id> userIds - Lista de IDs de usuarios (Owners). Si es null o vacío, procesa todos los Owners activos
    **/
    @InvocableMethod(label='Actualizar KPI Mensual ROA')
    public static void upsertMonthlyKPI(List<Id> userIds) {
        Set<Id> ownerIds = new Set<Id>();
        if (userIds != null) ownerIds.addAll(userIds);

        // Auto-descubre owners si no se especifican
        if (ownerIds.isEmpty()) {
            for (AggregateResult ar : [
                SELECT Cliente__r.OwnerId ownerId
                FROM Facturas__c
                WHERE Fecha_de_Documento__c = LAST_N_MONTHS:3
                GROUP BY Cliente__r.OwnerId
            ]) {
                Id oid = (Id) ar.get('ownerId');
                if (oid != null) ownerIds.add(oid);
            }
        }

        // Filtrar solo OwnerIds activos Y que sean Asesores
        Set<Id> activeOwnerIds = new Set<Id>();
        for (User u : [
            SELECT Id FROM User 
            WHERE Id IN :ownerIds 
            AND IsActive = true 
            AND UserRole.Name LIKE '%Asesor%'
        ]) {
            activeOwnerIds.add(u.Id);
        }
        if (activeOwnerIds.isEmpty()) return;

        // Obtener fecha de ayer (el proceso corre a las 00:01, procesando el día anterior)
        Date yesterday = Date.today().addDays(-1);
        Integer targetYear = yesterday.year();
        Integer targetMonth = yesterday.month();
        Date firstDayOfTargetMonth = Date.newInstance(targetYear, targetMonth, 1);
        Date lastDayOfTargetMonth = firstDayOfTargetMonth.addMonths(1).addDays(-1);
        Date threeMonthsAgo = firstDayOfTargetMonth.addMonths(-3);
        String monthKey = String.valueOf(targetYear) + '-' + (targetMonth < 10 ? '0' + String.valueOf(targetMonth) : String.valueOf(targetMonth));

        // Calcular Cartera Activa: clientes únicos con facturas en últimos 3 meses (relativo al mes objetivo)
        // Siguiendo la lógica de ChurnKPIService: clientes con compra en los últimos 3 meses
        Map<Id, Integer> carteraActivaMap = new Map<Id, Integer>();
        for (AggregateResult ar : [
            SELECT Cliente__r.OwnerId ownerId, COUNT_DISTINCT(Cliente__c) total
            FROM Facturas__c
            WHERE Fecha_de_Documento__c >= :threeMonthsAgo
              AND Fecha_de_Documento__c <= :lastDayOfTargetMonth
              AND Cliente__r.OwnerId IN :activeOwnerIds
            GROUP BY Cliente__r.OwnerId
        ]) {
            Id oid = (Id) ar.get('ownerId');
            Integer total = ((Decimal) ar.get('total')).intValue();
            carteraActivaMap.put(oid, total);
        }

        // Calcular Nuevos: clientes que facturaron por primera vez en el mes de ayer
        Map<Id, Integer> nuevosMap = new Map<Id, Integer>();
        for (AggregateResult ar : [
            SELECT OwnerId ownerId, COUNT(Id) total
            FROM Account
            WHERE OwnerId IN :activeOwnerIds
              AND Id IN (
                  SELECT Cliente__c
                  FROM Facturas__c
                  WHERE Fecha_de_Documento__c >= :firstDayOfTargetMonth
                    AND Fecha_de_Documento__c <= :lastDayOfTargetMonth
              )
              AND Id NOT IN (
                  SELECT Cliente__c
                  FROM Facturas__c
                  WHERE Fecha_de_Documento__c < :firstDayOfTargetMonth
              )
            GROUP BY OwnerId
        ]) {
            Id oid = (Id) ar.get('ownerId');
            Integer total = ((Decimal) ar.get('total')).intValue();
            nuevosMap.put(oid, total);
        }

        // Calcular Retenidos: clientes que facturaron en últimos 3 meses Y en el mes objetivo
        Map<Id, Integer> retainedMap = new Map<Id, Integer>();
        for (AggregateResult ar : [
            SELECT OwnerId ownerId, COUNT(Id) total
            FROM Account
            WHERE OwnerId IN :activeOwnerIds
              AND Id IN (
                  SELECT Cliente__c
                  FROM Facturas__c
                  WHERE Fecha_de_Documento__c >= :threeMonthsAgo
                    AND Fecha_de_Documento__c <= :lastDayOfTargetMonth
              )
              AND Id IN (
                  SELECT Cliente__c
                  FROM Facturas__c
                  WHERE Fecha_de_Documento__c >= :firstDayOfTargetMonth
                    AND Fecha_de_Documento__c <= :lastDayOfTargetMonth
              )
            GROUP BY OwnerId
        ]) {
            Id oid = (Id) ar.get('ownerId');
            Integer total = ((Decimal) ar.get('total')).intValue();
            retainedMap.put(oid, total);
        }

        // Calcular Fugados: clientes que facturaron en últimos 3 meses PERO NO en el mes objetivo
        // Siguiendo la lógica de ChurnKPIService: la fuga es parte de la cartera activa y no la sobrepasa
        Map<Id, Integer> churnedMap = new Map<Id, Integer>();
        for (AggregateResult ar : [
            SELECT OwnerId ownerId, COUNT(Id) total
            FROM Account
            WHERE OwnerId IN :activeOwnerIds
              AND Id IN (
                  SELECT Cliente__c
                  FROM Facturas__c
                  WHERE Fecha_de_Documento__c >= :threeMonthsAgo
                    AND Fecha_de_Documento__c <= :lastDayOfTargetMonth
              )
              AND Id NOT IN (
                  SELECT Cliente__c
                  FROM Facturas__c
                  WHERE Fecha_de_Documento__c >= :firstDayOfTargetMonth
                    AND Fecha_de_Documento__c <= :lastDayOfTargetMonth
              )
            GROUP BY OwnerId
        ]) {
            Id oid = (Id) ar.get('ownerId');
            Integer total = ((Decimal) ar.get('total')).intValue();
            churnedMap.put(oid, total);
        }

        // Calcular Recuperados: clientes que NO facturaron en el mes anterior al mes de ayer pero SÍ en el mes de ayer
        Map<Id, Integer> recuperadosMap = new Map<Id, Integer>();
        Date firstDayOfPreviousMonth = firstDayOfTargetMonth.addMonths(-1);
        Date lastDayOfPreviousMonth = firstDayOfTargetMonth.addDays(-1);
        for (AggregateResult ar : [
            SELECT OwnerId ownerId, COUNT(Id) total
            FROM Account
            WHERE OwnerId IN :activeOwnerIds
              AND Id IN (
                  SELECT Cliente__c
                  FROM Facturas__c
                  WHERE Fecha_de_Documento__c >= :firstDayOfTargetMonth
                    AND Fecha_de_Documento__c <= :lastDayOfTargetMonth
              )
              AND Id NOT IN (
                  SELECT Cliente__c
                  FROM Facturas__c
                  WHERE Fecha_de_Documento__c >= :firstDayOfPreviousMonth
                    AND Fecha_de_Documento__c <= :lastDayOfPreviousMonth
              )
            GROUP BY OwnerId
        ]) {
            Id oid = (Id) ar.get('ownerId');
            Integer total = ((Decimal) ar.get('total')).intValue();
            recuperadosMap.put(oid, total);
        }

        // Obtener registros existentes para el mes objetivo
        Set<String> uniqueKeys = new Set<String>();
        for (Id oId : activeOwnerIds) {
            uniqueKeys.add(String.valueOf(oId) + '|' + monthKey);
        }
        
        Map<String, MonthlyROAKPI__c> existingRecordsMap = new Map<String, MonthlyROAKPI__c>();
        for (MonthlyROAKPI__c existing : [
            SELECT Id, UniqueKey__c, OwnerId__c, Month__c, Year__c, MonthNumber__c,
                   CarteraActiva__c, Nuevos__c, Retenidos__c, Fugados__c, Recuperados__c
            FROM MonthlyROAKPI__c
            WHERE UniqueKey__c IN :uniqueKeys
        ]) {
            existingRecordsMap.put(existing.UniqueKey__c, existing);
        }

        // Construcción de registros para insertar o actualizar
        List<MonthlyROAKPI__c> toInsert = new List<MonthlyROAKPI__c>();
        List<MonthlyROAKPI__c> toUpdate = new List<MonthlyROAKPI__c>();
        
        for (Id oId : activeOwnerIds) {
            Integer carteraActiva = carteraActivaMap.containsKey(oId) ? carteraActivaMap.get(oId) : 0;
            Integer nuevos = nuevosMap.containsKey(oId) ? nuevosMap.get(oId) : 0;
            Integer retained = retainedMap.containsKey(oId) ? retainedMap.get(oId) : 0;
            Integer churned = churnedMap.containsKey(oId) ? churnedMap.get(oId) : 0;
            Integer recuperados = recuperadosMap.containsKey(oId) ? recuperadosMap.get(oId) : 0;

            // Solo crear/actualizar si hay al menos una métrica con valor
            if (carteraActiva == 0 && nuevos == 0 && retained == 0 && churned == 0 && recuperados == 0) continue;

            String uniqueKey = String.valueOf(oId) + '|' + monthKey;
            
            MonthlyROAKPI__c record = existingRecordsMap.get(uniqueKey);
            
            if (record != null) {
                // Actualizar registro existente
                record.CarteraActiva__c = carteraActiva;
                record.Nuevos__c = nuevos;
                record.Retenidos__c = retained;
                record.Fugados__c = churned;
                record.Recuperados__c = recuperados;
                toUpdate.add(record);
            } else {
                // Crear nuevo registro
                toInsert.add(new MonthlyROAKPI__c(
                    UniqueKey__c = uniqueKey,
                    OwnerId__c = oId,
                    Month__c = firstDayOfTargetMonth,
                    Year__c = targetYear,
                    MonthNumber__c = targetMonth,
                    CarteraActiva__c = carteraActiva,
                    Nuevos__c = nuevos,
                    Retenidos__c = retained,
                    Fugados__c = churned,
                    Recuperados__c = recuperados
                ));
            }
        }

        if (!toInsert.isEmpty()) {
            insert toInsert;
        }
        if (!toUpdate.isEmpty()) {
            update toUpdate;
        }
    }
}