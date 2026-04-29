public without sharing class ChurnKPIService {

    @InvocableMethod(label='Actualizar Churn KPI')
    public static void upsertKPI(List<Id> userIds) {
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
            for (AggregateResult ar : [
                SELECT OwnerId ownerId
                FROM Account
                WHERE Id IN (
                    SELECT Cliente__c
                    FROM Facturas__c
                    WHERE Fecha_de_Documento__c = LAST_N_MONTHS:3
                )
                AND Id NOT IN (
                    SELECT Cliente__c
                    FROM Facturas__c
                    WHERE Fecha_de_Documento__c = THIS_MONTH
                )
                GROUP BY OwnerId
            ]) {
                Id oid = (Id) ar.get('ownerId');
                if (oid != null) ownerIds.add(oid);
            }
        }

        // Filtrar solo OwnerIds activos
        Set<Id> activeOwnerIds = new Set<Id>();
        for (User u : [
            SELECT Id FROM User WHERE Id IN :ownerIds AND IsActive = true
        ]) {
            activeOwnerIds.add(u.Id);
        }
        if (activeOwnerIds.isEmpty()) return;

        Date today = Date.today();
        String todayKey = String.valueOf(today);

        // --- KPI por cuenta (existente) ---
        Map<Id, Integer> activeMap = new Map<Id, Integer>();
        for (AggregateResult ar : [
            SELECT Cliente__r.OwnerId ownerId, COUNT_DISTINCT(Cliente__c) total
            FROM Facturas__c
            WHERE Fecha_de_Documento__c = LAST_N_MONTHS:3
              AND Cliente__r.OwnerId IN :activeOwnerIds
            GROUP BY Cliente__r.OwnerId
        ]) {
            Id oid = (Id) ar.get('ownerId');
            Integer total = ((Decimal) ar.get('total')).intValue();
            activeMap.put(oid, total);
        }

        Map<Id, Integer> churnedMap = new Map<Id, Integer>();
        for (AggregateResult ar : [
            SELECT OwnerId ownerId, COUNT(Id) total
            FROM Account
            WHERE OwnerId IN :activeOwnerIds
              AND Id IN (
                  SELECT Cliente__c
                  FROM Facturas__c
                  WHERE Fecha_de_Documento__c = LAST_N_MONTHS:3
              )
              AND Id NOT IN (
                  SELECT Cliente__c
                  FROM Facturas__c
                  WHERE Fecha_de_Documento__c = THIS_MONTH
              )
            GROUP BY OwnerId
        ]) {
            Id oid = (Id) ar.get('ownerId');
            Integer total = ((Decimal) ar.get('total')).intValue();
            churnedMap.put(oid, total);
        }

        Map<Id, Integer> retainedMap = new Map<Id, Integer>();
        for (AggregateResult ar : [
            SELECT OwnerId ownerId, COUNT(Id) total
            FROM Account
            WHERE OwnerId IN :activeOwnerIds
              AND Id IN (
                  SELECT Cliente__c
                  FROM Facturas__c
                  WHERE Fecha_de_Documento__c = LAST_N_MONTHS:3
              )
              AND Id IN (
                  SELECT Cliente__c
                  FROM Facturas__c
                  WHERE Fecha_de_Documento__c = THIS_MONTH
              )
            GROUP BY OwnerId
        ]) {
            Id oid = (Id) ar.get('ownerId');
            Integer total = ((Decimal) ar.get('total')).intValue();
            retainedMap.put(oid, total);
        }

        Set<Id> recoverableAccounts = new Set<Id>();

        for (Account a : [
            SELECT Id
            FROM Account
            WHERE Id IN (
                SELECT Cliente__c
                FROM Facturas__c
                WHERE Fecha_de_Documento__c >= LAST_N_MONTHS:12
                  AND Fecha_de_Documento__c < LAST_N_MONTHS:3
            )
            AND Id NOT IN (
                SELECT Cliente__c
                FROM Facturas__c
                WHERE Fecha_de_Documento__c >= LAST_N_MONTHS:3
                  AND Fecha_de_Documento__c < THIS_MONTH
            )
        ]) {
            recoverableAccounts.add(a.Id);
        }

        Map<Id, Integer> recoveredMap = new Map<Id, Integer>();
        if (!recoverableAccounts.isEmpty()) {
            for (AggregateResult ar : [
                SELECT OwnerId ownerId, COUNT(Id) total
                FROM Account
                WHERE OwnerId IN :activeOwnerIds
                  AND Id IN :recoverableAccounts
                  AND Id IN (
                      SELECT Cliente__c
                      FROM Facturas__c
                      WHERE Fecha_de_Documento__c = THIS_MONTH
                  )
                GROUP BY OwnerId
            ]) {
                Id oid = (Id) ar.get('ownerId');
                Integer total = ((Decimal) ar.get('total')).intValue();
                recoveredMap.put(oid, total);
            }
        }

        Map<Id, Integer> newAccountMap = new Map<Id, Integer>();
        for (AggregateResult ar : [
            SELECT OwnerId ownerId, COUNT(Id) total
            FROM Account
            WHERE OwnerId IN :activeOwnerIds
              AND Id IN (
                  SELECT Cliente__c
                  FROM Facturas__c
                  WHERE Fecha_de_Documento__c = THIS_MONTH
              )
              AND Id NOT IN (
                  SELECT Cliente__c
                  FROM Facturas__c
                  WHERE Fecha_de_Documento__c >= LAST_N_MONTHS:12
                  AND Fecha_de_Documento__c < THIS_MONTH
              )
            GROUP BY OwnerId
        ]) {
            Id oid = (Id) ar.get('ownerId');
            Integer total = ((Decimal) ar.get('total')).intValue();
            newAccountMap.put(oid, total);
        }

        // --- KPI por domicilio: solo Facturas__c con Domicilio_Cliente__c ---
        Map<Id, Integer> domActiveMap = new Map<Id, Integer>();
        for (AggregateResult ar : [
            SELECT Cliente__r.OwnerId ownerId, COUNT_DISTINCT(Domicilio_Cliente__c) total
            FROM Facturas__c
            WHERE Fecha_de_Documento__c = LAST_N_MONTHS:3
              AND Domicilio_Cliente__c != null
              AND Cliente__r.OwnerId IN :activeOwnerIds
            GROUP BY Cliente__r.OwnerId
        ]) {
            Id oid = (Id) ar.get('ownerId');
            domActiveMap.put(oid, ((Decimal) ar.get('total')).intValue());
        }

        Map<Id, Integer> domChurnedMap = new Map<Id, Integer>();
        for (AggregateResult ar : [
            SELECT Cliente__r.OwnerId ownerId, COUNT(Id) total
            FROM Domicilio_de_Cliente__c
            WHERE Cliente__r.OwnerId IN :activeOwnerIds
              AND Id IN (
                  SELECT Domicilio_Cliente__c
                  FROM Facturas__c
                  WHERE Fecha_de_Documento__c = LAST_N_MONTHS:3
                    AND Domicilio_Cliente__c != null
              )
              AND Id NOT IN (
                  SELECT Domicilio_Cliente__c
                  FROM Facturas__c
                  WHERE Fecha_de_Documento__c = THIS_MONTH
                    AND Domicilio_Cliente__c != null
              )
            GROUP BY Cliente__r.OwnerId
        ]) {
            Id oid = (Id) ar.get('ownerId');
            domChurnedMap.put(oid, ((Decimal) ar.get('total')).intValue());
        }

        Map<Id, Integer> domRetainedMap = new Map<Id, Integer>();
        for (AggregateResult ar : [
            SELECT Cliente__r.OwnerId ownerId, COUNT(Id) total
            FROM Domicilio_de_Cliente__c
            WHERE Cliente__r.OwnerId IN :activeOwnerIds
              AND Id IN (
                  SELECT Domicilio_Cliente__c
                  FROM Facturas__c
                  WHERE Fecha_de_Documento__c = LAST_N_MONTHS:3
                    AND Domicilio_Cliente__c != null
              )
              AND Id IN (
                  SELECT Domicilio_Cliente__c
                  FROM Facturas__c
                  WHERE Fecha_de_Documento__c = THIS_MONTH
                    AND Domicilio_Cliente__c != null
              )
            GROUP BY Cliente__r.OwnerId
        ]) {
            Id oid = (Id) ar.get('ownerId');
            domRetainedMap.put(oid, ((Decimal) ar.get('total')).intValue());
        }

        Set<Id> recoverableDomicilioIds = new Set<Id>();
        for (Domicilio_de_Cliente__c dom : [
            SELECT Id
            FROM Domicilio_de_Cliente__c
            WHERE Id IN (
                SELECT Domicilio_Cliente__c
                FROM Facturas__c
                WHERE Fecha_de_Documento__c >= LAST_N_MONTHS:12
                  AND Fecha_de_Documento__c < LAST_N_MONTHS:3
                  AND Domicilio_Cliente__c != null
            )
            AND Id NOT IN (
                SELECT Domicilio_Cliente__c
                FROM Facturas__c
                WHERE Fecha_de_Documento__c >= LAST_N_MONTHS:3
                  AND Fecha_de_Documento__c < THIS_MONTH
                  AND Domicilio_Cliente__c != null
            )
        ]) {
            recoverableDomicilioIds.add(dom.Id);
        }

        Map<Id, Integer> domRecoveredMap = new Map<Id, Integer>();
        if (!recoverableDomicilioIds.isEmpty()) {
            for (AggregateResult ar : [
                SELECT Cliente__r.OwnerId ownerId, COUNT(Id) total
                FROM Domicilio_de_Cliente__c
                WHERE Cliente__r.OwnerId IN :activeOwnerIds
                  AND Id IN :recoverableDomicilioIds
                  AND Id IN (
                      SELECT Domicilio_Cliente__c
                      FROM Facturas__c
                      WHERE Fecha_de_Documento__c = THIS_MONTH
                        AND Domicilio_Cliente__c != null
                  )
                GROUP BY Cliente__r.OwnerId
            ]) {
                Id oid = (Id) ar.get('ownerId');
                domRecoveredMap.put(oid, ((Decimal) ar.get('total')).intValue());
            }
        }

        Map<Id, Integer> domNewMap = new Map<Id, Integer>();
        for (AggregateResult ar : [
            SELECT Cliente__r.OwnerId ownerId, COUNT(Id) total
            FROM Domicilio_de_Cliente__c
            WHERE Cliente__r.OwnerId IN :activeOwnerIds
              AND Id IN (
                  SELECT Domicilio_Cliente__c
                  FROM Facturas__c
                  WHERE Fecha_de_Documento__c = THIS_MONTH
                    AND Domicilio_Cliente__c != null
              )
              AND Id NOT IN (
                  SELECT Domicilio_Cliente__c
                  FROM Facturas__c
                  WHERE Fecha_de_Documento__c >= LAST_N_MONTHS:12
                    AND Fecha_de_Documento__c < THIS_MONTH
                    AND Domicilio_Cliente__c != null
              )
            GROUP BY Cliente__r.OwnerId
        ]) {
            Id oid = (Id) ar.get('ownerId');
            domNewMap.put(oid, ((Decimal) ar.get('total')).intValue());
        }

        List<SalesKPI__c> toUpsert = new List<SalesKPI__c>();
        List<MonthlyROAKPI__c> toUpsertMonthly = new List<MonthlyROAKPI__c>();
        List<DomicilioSalesKPI__c> toUpsertDom = new List<DomicilioSalesKPI__c>();
        List<MonthlyDomicilioROAKPI__c> toUpsertMonthlyDom = new List<MonthlyDomicilioROAKPI__c>();

        Date lastDayOfMonth = today.toStartOfMonth().addMonths(1).addDays(-1);
        Boolean isLastDayOfMonth = today == lastDayOfMonth;

        for (Id oId : activeOwnerIds) {
            Integer activeCount    = activeMap.containsKey(oId)    ? activeMap.get(oId)    : 0;
            Integer churnedCount   = churnedMap.containsKey(oId)   ? churnedMap.get(oId)   : 0;
            Integer retainedCount  = retainedMap.containsKey(oId)  ? retainedMap.get(oId)  : 0;
            Integer recoveredCount = recoveredMap.containsKey(oId) ? recoveredMap.get(oId) : 0;
            Integer newAccountCount = newAccountMap.containsKey(oId) ? newAccountMap.get(oId) : 0;

            if (activeCount == 0 && churnedCount == 0 && retainedCount == 0 && recoveredCount == 0 && newAccountCount == 0) {
                // skip cuenta
            } else {
                Decimal denom       = Decimal.valueOf(activeCount + churnedCount);
                Decimal churnPct    = denom == 0 ? 0 : Decimal.valueOf(churnedCount) / denom;
                Decimal retainedPct = denom == 0 ? 0 : Decimal.valueOf(retainedCount) / denom;

                String uniqueKey = String.valueOf(oId) + '|' + todayKey;

                toUpsert.add(new SalesKPI__c(
                    UniqueKey__c     = uniqueKey,
                    OwnerId          = oId,
                    AsOfDate__c      = today,
                    ActiveCount__c   = activeCount,
                    ChurnedCount__c  = churnedCount,
                    ChurnPct__c      = churnPct,
                    RetainedCount__c = retainedCount,
                    RetainedPct__c   = retainedPct,
                    RecoveredCount__c = recoveredCount,
                    NewAccountCount__c = newAccountCount
                ));

                if (isLastDayOfMonth) {
                    String monthKey = String.valueOf(today.year()) + '-' +
                        (today.month() < 10 ? '0' + String.valueOf(today.month()) : String.valueOf(today.month()));
                    String monthlyUniqueKey = String.valueOf(oId) + '|' + monthKey;

                    toUpsertMonthly.add(new MonthlyROAKPI__c(
                        UniqueKey__c     = monthlyUniqueKey,
                        OwnerId__c       = oId,
                        Month__c         = today,
                        Year__c          = today.year(),
                        MonthNumber__c   = today.month(),
                        CarteraActiva__c = activeCount,
                        Nuevos__c        = newAccountCount,
                        Retenidos__c     = retainedCount,
                        Fugados__c       = churnedCount,
                        Recuperados__c   = recoveredCount
                    ));
                }
            }

            Integer domActive    = domActiveMap.containsKey(oId)    ? domActiveMap.get(oId)    : 0;
            Integer domChurned   = domChurnedMap.containsKey(oId)   ? domChurnedMap.get(oId)   : 0;
            Integer domRetained  = domRetainedMap.containsKey(oId)  ? domRetainedMap.get(oId)  : 0;
            Integer domRecovered = domRecoveredMap.containsKey(oId) ? domRecoveredMap.get(oId) : 0;
            Integer domNew       = domNewMap.containsKey(oId)       ? domNewMap.get(oId)       : 0;

            if (domActive == 0 && domChurned == 0 && domRetained == 0 && domRecovered == 0 && domNew == 0) {
                continue;
            }

            Decimal domDenom       = Decimal.valueOf(domActive + domChurned);
            Decimal domChurnPct    = domDenom == 0 ? 0 : Decimal.valueOf(domChurned) / domDenom;
            Decimal domRetainedPct = domDenom == 0 ? 0 : Decimal.valueOf(domRetained) / domDenom;

            String domUniqueKey = 'DOM|' + String.valueOf(oId) + '|' + todayKey;

            toUpsertDom.add(new DomicilioSalesKPI__c(
                Name             = domUniqueKey.length() > 80 ? domUniqueKey.substring(0, 80) : domUniqueKey,
                UniqueKey__c     = domUniqueKey,
                OwnerId          = oId,
                AsOfDate__c      = today,
                ActiveCount__c   = domActive,
                ChurnedCount__c  = domChurned,
                ChurnPct__c      = domChurnPct,
                RetainedCount__c = domRetained,
                RetainedPct__c   = domRetainedPct,
                RecoveredCount__c = domRecovered,
                NewAccountCount__c = domNew
            ));

            if (isLastDayOfMonth) {
                String monthKeyDom = String.valueOf(today.year()) + '-' +
                    (today.month() < 10 ? '0' + String.valueOf(today.month()) : String.valueOf(today.month()));
                String monthlyDomKey = 'DOM|' + String.valueOf(oId) + '|' + monthKeyDom;

                toUpsertMonthlyDom.add(new MonthlyDomicilioROAKPI__c(
                    Name             = monthlyDomKey.length() > 80 ? monthlyDomKey.substring(0, 80) : monthlyDomKey,
                    UniqueKey__c     = monthlyDomKey,
                    OwnerId__c       = oId,
                    Month__c         = today,
                    Year__c          = today.year(),
                    MonthNumber__c   = today.month(),
                    CarteraActiva__c = domActive,
                    Nuevos__c        = domNew,
                    Retenidos__c     = domRetained,
                    Fugados__c       = domChurned,
                    Recuperados__c   = domRecovered
                ));
            }
        }

        if (!toUpsert.isEmpty()) {
            upsert toUpsert SalesKPI__c.Fields.UniqueKey__c;
        }

        if (!toUpsertMonthly.isEmpty()) {
            upsert toUpsertMonthly MonthlyROAKPI__c.Fields.UniqueKey__c;
        }

        if (!toUpsertDom.isEmpty()) {
            upsert toUpsertDom DomicilioSalesKPI__c.Fields.UniqueKey__c;
        }

        if (!toUpsertMonthlyDom.isEmpty()) {
            upsert toUpsertMonthlyDom MonthlyDomicilioROAKPI__c.Fields.UniqueKey__c;
        }
    }
}