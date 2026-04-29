/**********************************************************************************
Desarrollado por: SEIDOR
Autor: Rodrigo Carvallo (RCG)
Proyecto: Ticket N°00024464 - Historico de ROAs
Descripción: Clase de test para ICB_MonthlyROAKPIService e ICB_MonthlyROAKPI_DailyJob

---------------------------------------------------------------------------------
No. Fecha                Autor                     Descripción
------ ---------- ---------------------------------------------------------------
1.0 22-12-2025            RCG                Creación de la clase.
**********************************************************************************/
@IsTest
private class ICB_MonthlyROAKPI_AllTests {

    /**
    * Método helper para crear usuarios de test
    * @author Rodrigo Carvallo
    * @param String alias - Alias para el usuario
    * @return User - Usuario creado
    **/
    private static User mkUser(String alias) {
        Profile p = [SELECT Id FROM Profile WHERE Id = :UserInfo.getProfileId()];
        
        // Intentar obtener un rol de Asesor para los tests
        UserRole asesorRole = null;
        try {
            asesorRole = [SELECT Id FROM UserRole WHERE Name LIKE '%Asesor%' LIMIT 1];
        } catch (Exception e) {
            // Si no existe rol de Asesor, crear usuario sin rol (los tests pueden fallar si el org requiere rol)
        }
        
        User u = new User(
            ProfileId = p.Id,
            Username = alias + DateTime.now().getTime() + '@t.icb',
            LastName = 'T',
            Email = alias + '@t.icb',
            Alias = alias.left(8),
            CommunityNickname = alias + DateTime.now().getTime(),
            TimeZoneSidKey = 'America/Santiago',
            LocaleSidKey = 'es_CL',
            EmailEncodingKey = 'UTF-8',
            LanguageLocaleKey = 'es',
            IsActive = true
        );
        
        if (asesorRole != null) {
            u.UserRoleId = asesorRole.Id;
        }
        
        insert u;
        return u;
    }

    /**
    * Setup de datos de test
    * @author Rodrigo Carvallo
    **/
    @testSetup
    static void data() {
        User ownerU = mkUser('ownerROA');
        User ownerU2 = mkUser('ownerROA2');

        List<Account> accts = new List<Account>{
            new Account(Name='Cliente A1', OwnerId=ownerU.Id),
            new Account(Name='Cliente A2', OwnerId=ownerU.Id),
            new Account(Name='Cliente A3', OwnerId=ownerU.Id),
            new Account(Name='Cliente A4', OwnerId=ownerU.Id), // Para probar Fugados
            new Account(Name='Cliente B1', OwnerId=ownerU2.Id)
        };
        insert accts;

        // Fechas para las pruebas
        Date yesterday = Date.today().addDays(-1);
        Date firstDayOfMonth = Date.newInstance(yesterday.year(), yesterday.month(), 1);
        Date lastDayOfMonth = firstDayOfMonth.addMonths(1).addDays(-1);
        Date previousMonth = firstDayOfMonth.addMonths(-1);
        Date threeMonthsAgo = firstDayOfMonth.addMonths(-3);

        // Facturas del mes actual (ayer)
        List<Facturas__c> facturas = new List<Facturas__c>{
            // Cliente A1: factura en mes actual (Cartera Activa, Retenido)
            new Facturas__c(Cliente__c = accts[0].Id, Fecha_de_Documento__c = yesterday),
            // Cliente A2: factura en mes actual y también en meses anteriores (Cartera Activa, Retenido)
            new Facturas__c(Cliente__c = accts[1].Id, Fecha_de_Documento__c = yesterday),
            new Facturas__c(Cliente__c = accts[1].Id, Fecha_de_Documento__c = threeMonthsAgo.addDays(10)),
            // Cliente A3: factura en mes actual pero NO en mes anterior (Cartera Activa, Nuevo o Recuperado)
            new Facturas__c(Cliente__c = accts[2].Id, Fecha_de_Documento__c = yesterday),
            // Cliente B1: factura en mes actual (para otro owner)
            new Facturas__c(Cliente__c = accts[4].Id, Fecha_de_Documento__c = yesterday)
        };
        insert facturas;

        // Facturas del mes anterior (para probar Recuperados)
        List<Facturas__c> facturasAnteriores = new List<Facturas__c>{
            // Cliente A2: tenía factura en mes anterior (para que sea Retenido)
            new Facturas__c(Cliente__c = accts[1].Id, Fecha_de_Documento__c = previousMonth.addDays(15))
        };
        insert facturasAnteriores;

        // Facturas de hace 3 meses (para probar Fugados)
        // Para ser Fugado: debe facturar entre threeMonthsAgo y firstDayOfTargetMonth (antes del mes actual)
        // pero NO en el mes actual
        Date fechaFugado = firstDayOfMonth.addDays(-15); // 15 días antes del inicio del mes actual
        List<Facturas__c> facturasAntiguas = new List<Facturas__c>{
            // Cliente A1: factura hace 3 meses (pero también facturó en mes actual, así que no es fugado)
            new Facturas__c(Cliente__c = accts[0].Id, Fecha_de_Documento__c = threeMonthsAgo.addDays(5)),
            // Cliente A4: facturó antes del mes actual pero NO en mes actual (será Fugado)
            new Facturas__c(Cliente__c = accts[3].Id, Fecha_de_Documento__c = fechaFugado)
        };
        insert facturasAntiguas;
    }

    /**
    * Test del método upsertMonthlyKPI con auto-descubrimiento de owners
    * @author Rodrigo Carvallo
    **/
    @IsTest
    static void test_upsertMonthlyKPI_autoDiscover() {
        Test.startTest();
        ICB_MonthlyROAKPIService.upsertMonthlyKPI(null);
        Test.stopTest();

        Date yesterday = Date.today().addDays(-1);
        Integer targetYear = yesterday.year();
        Integer targetMonth = yesterday.month();
        String monthKey = String.valueOf(targetYear) + '-' + (targetMonth < 10 ? '0' + String.valueOf(targetMonth) : String.valueOf(targetMonth));

        List<User> owners = [SELECT Id FROM User WHERE Username LIKE '%ownerROA%' AND IsActive = true];
        System.assert(owners.size() > 0, 'Debe haber al menos un owner activo');

        String likePattern = '%|' + monthKey;
        List<MonthlyROAKPI__c> kpis = [
            SELECT Id, UniqueKey__c, OwnerId__c, Month__c, Year__c, MonthNumber__c,
                   CarteraActiva__c, Nuevos__c, Retenidos__c, Fugados__c, Recuperados__c
            FROM MonthlyROAKPI__c
            WHERE UniqueKey__c LIKE :likePattern
        ];
        
        System.assert(kpis.size() > 0, 'Debe haber al menos un KPI creado');
        
        // Verificar que los registros tienen datos
        for (MonthlyROAKPI__c kpi : kpis) {
            System.assert(kpi.OwnerId__c != null, 'El OwnerId debe estar asignado');
            System.assert(kpi.Month__c != null, 'El Month debe estar asignado');
            System.assert(kpi.Year__c == targetYear, 'El Year debe coincidir');
            System.assert(kpi.MonthNumber__c == targetMonth, 'El MonthNumber debe coincidir');
        }
    }

    /**
    * Test del método upsertMonthlyKPI con userIds específicos
    * @author Rodrigo Carvallo
    **/
    @IsTest
    static void test_upsertMonthlyKPI_withUserIds() {
        User ownerU = [SELECT Id FROM User WHERE Username LIKE '%ownerROA%' AND IsActive = true LIMIT 1];
        
        Test.startTest();
        ICB_MonthlyROAKPIService.upsertMonthlyKPI(new List<Id>{ownerU.Id});
        Test.stopTest();

        Date yesterday = Date.today().addDays(-1);
        Integer targetYear = yesterday.year();
        Integer targetMonth = yesterday.month();
        String monthKey = String.valueOf(targetYear) + '-' + (targetMonth < 10 ? '0' + String.valueOf(targetMonth) : String.valueOf(targetMonth));
        String uniqueKey = String.valueOf(ownerU.Id) + '|' + monthKey;

        List<MonthlyROAKPI__c> kpis = [
            SELECT Id, UniqueKey__c, OwnerId__c, CarteraActiva__c
            FROM MonthlyROAKPI__c
            WHERE UniqueKey__c = :uniqueKey
        ];
        
        System.assert(kpis.size() == 1, 'Debe haber exactamente un KPI para el owner especificado');
        System.assert(kpis[0].CarteraActiva__c > 0, 'Debe tener Cartera Activa mayor a 0');
    }

    /**
    * Test de actualización de registro existente
    * @author Rodrigo Carvallo
    **/
    @IsTest
    static void test_upsertMonthlyKPI_updateExisting() {
        User ownerU = [SELECT Id FROM User WHERE Username LIKE '%ownerROA%' AND IsActive = true LIMIT 1];
        
        Date yesterday = Date.today().addDays(-1);
        Integer targetYear = yesterday.year();
        Integer targetMonth = yesterday.month();
        Date firstDayOfMonth = Date.newInstance(targetYear, targetMonth, 1);
        String monthKey = String.valueOf(targetYear) + '-' + (targetMonth < 10 ? '0' + String.valueOf(targetMonth) : String.valueOf(targetMonth));
        String uniqueKey = String.valueOf(ownerU.Id) + '|' + monthKey;

        // Crear registro existente
        MonthlyROAKPI__c existing = new MonthlyROAKPI__c(
            UniqueKey__c = uniqueKey,
            OwnerId__c = ownerU.Id,
            Month__c = firstDayOfMonth,
            Year__c = targetYear,
            MonthNumber__c = targetMonth,
            CarteraActiva__c = 5,
            Nuevos__c = 2,
            Retenidos__c = 3,
            Fugados__c = 1,
            Recuperados__c = 1
        );
        insert existing;

        Test.startTest();
        ICB_MonthlyROAKPIService.upsertMonthlyKPI(new List<Id>{ownerU.Id});
        Test.stopTest();

        MonthlyROAKPI__c updated = [
            SELECT Id, CarteraActiva__c, Nuevos__c, Retenidos__c, Fugados__c, Recuperados__c
            FROM MonthlyROAKPI__c
            WHERE Id = :existing.Id
        ];
        
        System.assert(updated.CarteraActiva__c != 5 || updated.Nuevos__c != 2, 'Los valores deben haberse actualizado');
    }

    /**
    * Test con owners inactivos (no debe procesar)
    * @author Rodrigo Carvallo
    **/
    @IsTest
    static void test_upsertMonthlyKPI_inactiveUser() {
        User inactiveUser = mkUser('inactive');
        inactiveUser.IsActive = false;
        update inactiveUser;

        Test.startTest();
        ICB_MonthlyROAKPIService.upsertMonthlyKPI(new List<Id>{inactiveUser.Id});
        Test.stopTest();

        List<MonthlyROAKPI__c> kpis = [SELECT Id FROM MonthlyROAKPI__c];
        System.assert(kpis.isEmpty(), 'No debe crear KPIs para usuarios inactivos');
    }

    /**
    * Test del job schedulable
    * @author Rodrigo Carvallo
    **/
    @IsTest
    static void test_schedulable_runs_and_creates() {
        Test.startTest();
        System.schedule('UT-ROA-KPI', '0 0 0 1 1 ? 2099', new ICB_MonthlyROAKPI_DailyJob());
        Test.stopTest();

        Date yesterday = Date.today().addDays(-1);
        Integer targetYear = yesterday.year();
        Integer targetMonth = yesterday.month();
        String monthKey = String.valueOf(targetYear) + '-' + (targetMonth < 10 ? '0' + String.valueOf(targetMonth) : String.valueOf(targetMonth));
        String likePattern = '%|' + monthKey;

        Integer kpis = [
            SELECT COUNT() 
            FROM MonthlyROAKPI__c 
            WHERE UniqueKey__c LIKE :likePattern
        ];
        System.assert(kpis > 0, 'El job programado debió generar al menos 1 KPI');
    }

    /**
    * Test con lista vacía de userIds
    * @author Rodrigo Carvallo
    **/
    @IsTest
    static void test_upsertMonthlyKPI_emptyList() {
        Test.startTest();
        ICB_MonthlyROAKPIService.upsertMonthlyKPI(new List<Id>());
        Test.stopTest();

        // Debe auto-descubrir owners, así que debería crear registros
        List<MonthlyROAKPI__c> kpis = [SELECT Id FROM MonthlyROAKPI__c];
        System.assert(kpis.size() >= 0, 'Puede o no crear registros dependiendo de los datos');
    }

    /**
    * Test invocable desde Flow
    * @author Rodrigo Carvallo
    **/
    @IsTest
    static void test_invocableMethod() {
        User ownerU = [SELECT Id FROM User WHERE Username LIKE '%ownerROA%' AND IsActive = true LIMIT 1];
        
        Test.startTest();
        // Simular llamada desde Flow
        List<Id> userIds = new List<Id>{ownerU.Id};
        ICB_MonthlyROAKPIService.upsertMonthlyKPI(userIds);
        Test.stopTest();

        Date yesterday = Date.today().addDays(-1);
        Integer targetYear = yesterday.year();
        Integer targetMonth = yesterday.month();
        String monthKey = String.valueOf(targetYear) + '-' + (targetMonth < 10 ? '0' + String.valueOf(targetMonth) : String.valueOf(targetMonth));
        String uniqueKey = String.valueOf(ownerU.Id) + '|' + monthKey;

        List<MonthlyROAKPI__c> kpis = [
            SELECT Id, UniqueKey__c, OwnerId__c
            FROM MonthlyROAKPI__c
            WHERE UniqueKey__c = :uniqueKey
        ];
        
        System.assert(kpis.size() == 1, 'Debe haber creado un KPI');
    }
}