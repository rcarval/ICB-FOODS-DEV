@IsTest
private class ChurnKPI_AllTests {

    private static User mkUser(String alias) {
        Profile p = [SELECT Id FROM Profile WHERE Id = :UserInfo.getProfileId()];
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
            LanguageLocaleKey = 'es'
        );
        insert u;
        return u;
    }

    @testSetup
    static void data() {
        User ownerU = mkUser('schedJobU');

        List<Account> accts = new List<Account>{
            new Account(Name = 'A1', OwnerId = ownerU.Id),
            new Account(Name = 'A2', OwnerId = ownerU.Id),
            new Account(Name = 'A3', OwnerId = ownerU.Id),
            new Account(Name = 'A4', OwnerId = ownerU.Id),
            new Account(Name = 'A5', OwnerId = ownerU.Id)
        };
        insert accts;

        Date twoMonthsAgo = Date.today().addMonths(-2);
        Date lastMonth = Date.today().toStartOfMonth().addMonths(-1).addDays(15);
        Date firstDayThisMonth = Date.today().toStartOfMonth();
        Date fiveMonthsAgo = firstDayThisMonth.addMonths(-5);

        // A1: Retained
        insert new Facturas__c(Cliente__c = accts[0].Id, Fecha_de_Documento__c = twoMonthsAgo);
        insert new Facturas__c(Cliente__c = accts[0].Id, Fecha_de_Documento__c = firstDayThisMonth);

        // A2: Churned
        insert new Facturas__c(Cliente__c = accts[1].Id, Fecha_de_Documento__c = twoMonthsAgo);
        insert new Facturas__c(Cliente__c = accts[1].Id, Fecha_de_Documento__c = lastMonth);

        // A3: Recovered
        insert new Facturas__c(Cliente__c = accts[2].Id, Fecha_de_Documento__c = fiveMonthsAgo);
        insert new Facturas__c(Cliente__c = accts[2].Id, Fecha_de_Documento__c = firstDayThisMonth);

        // A4: New
        insert new Facturas__c(Cliente__c = accts[3].Id, Fecha_de_Documento__c = firstDayThisMonth);

        // A5
        insert new Facturas__c(Cliente__c = accts[4].Id, Fecha_de_Documento__c = twoMonthsAgo);

        // KPI por domicilio: mismas ventanas, con Domicilio_Cliente__c (cubre bloque dom en ChurnKPIService)
        List<Domicilio_de_Cliente__c> doms = new List<Domicilio_de_Cliente__c>{
            new Domicilio_de_Cliente__c(Cliente__c = accts[0].Id),
            new Domicilio_de_Cliente__c(Cliente__c = accts[1].Id),
            new Domicilio_de_Cliente__c(Cliente__c = accts[2].Id),
            new Domicilio_de_Cliente__c(Cliente__c = accts[3].Id),
            new Domicilio_de_Cliente__c(Cliente__c = accts[4].Id)
        };
        insert doms;

        List<Facturas__c> facDom = new List<Facturas__c>{
            new Facturas__c(
                Cliente__c = accts[0].Id,
                Domicilio_Cliente__c = doms[0].Id,
                Fecha_de_Documento__c = twoMonthsAgo
            ),
            new Facturas__c(
                Cliente__c = accts[0].Id,
                Domicilio_Cliente__c = doms[0].Id,
                Fecha_de_Documento__c = firstDayThisMonth
            ),
            new Facturas__c(
                Cliente__c = accts[1].Id,
                Domicilio_Cliente__c = doms[1].Id,
                Fecha_de_Documento__c = twoMonthsAgo
            ),
            new Facturas__c(
                Cliente__c = accts[1].Id,
                Domicilio_Cliente__c = doms[1].Id,
                Fecha_de_Documento__c = lastMonth
            ),
            new Facturas__c(
                Cliente__c = accts[2].Id,
                Domicilio_Cliente__c = doms[2].Id,
                Fecha_de_Documento__c = fiveMonthsAgo
            ),
            new Facturas__c(
                Cliente__c = accts[2].Id,
                Domicilio_Cliente__c = doms[2].Id,
                Fecha_de_Documento__c = firstDayThisMonth
            ),
            new Facturas__c(
                Cliente__c = accts[3].Id,
                Domicilio_Cliente__c = doms[3].Id,
                Fecha_de_Documento__c = firstDayThisMonth
            ),
            new Facturas__c(
                Cliente__c = accts[4].Id,
                Domicilio_Cliente__c = doms[4].Id,
                Fecha_de_Documento__c = twoMonthsAgo
            )
        };
        insert facDom;
    }

    @IsTest
    static void schedulable_runs_once_and_creates() {
        Test.startTest();
        System.schedule('UT-KPI', '0 0 0 1 1 ? 2099', new ChurnKPI_DailyJob());
        Test.stopTest();

        Integer kpis = [
            SELECT COUNT()
            FROM SalesKPI__c
            WHERE AsOfDate__c = :Date.today()
        ];
        System.assert(kpis > 0, 'El job programado debió generar al menos 1 KPI');
    }

    @IsTest
    static void test_upsertKPI_creates_sales_kpi() {
        User ownerU = [SELECT Id FROM User WHERE Email LIKE 'schedJobU%@t.icb' LIMIT 1];

        Test.startTest();
        ChurnKPIService.upsertKPI(new List<Id>{ ownerU.Id });
        Test.stopTest();

        List<SalesKPI__c> kpis = [
            SELECT
                Id,
                OwnerId,
                ActiveCount__c,
                ChurnedCount__c,
                RetainedCount__c,
                RecoveredCount__c,
                NewAccountCount__c,
                ChurnPct__c,
                RetainedPct__c
            FROM SalesKPI__c
            WHERE OwnerId = :ownerU.Id AND AsOfDate__c = :Date.today()
        ];

        System.assertEquals(1, kpis.size(), 'Debe existir un KPI para el owner');
        System.assert(kpis[0].ActiveCount__c > 0, 'Debe tener clientes activos');
        System.assert(kpis[0].RetainedCount__c > 0, 'Debe tener clientes retenidos');
        System.assert(kpis[0].RecoveredCount__c != null, 'RecoveredCount debe estar definido');
        System.assert(kpis[0].NewAccountCount__c > 0, 'Debe tener nuevas cuentas');
        System.assertNotEquals(null, kpis[0].ChurnPct__c, 'ChurnPct persistido');
        System.assertNotEquals(null, kpis[0].RetainedPct__c, 'RetainedPct persistido');
    }

    @IsTest
    static void test_upsertKPI_creates_domicilio_sales_kpi() {
        User ownerU = [SELECT Id FROM User WHERE Email LIKE 'schedJobU%@t.icb' LIMIT 1];

        Test.startTest();
        ChurnKPIService.upsertKPI(new List<Id>{ ownerU.Id });
        Test.stopTest();

        List<DomicilioSalesKPI__c> domRows = [
            SELECT
                ActiveCount__c,
                ChurnedCount__c,
                RetainedCount__c,
                RecoveredCount__c,
                NewAccountCount__c,
                ChurnPct__c,
                RetainedPct__c,
                UniqueKey__c
            FROM DomicilioSalesKPI__c
            WHERE OwnerId = :ownerU.Id AND AsOfDate__c = :Date.today()
        ];

        System.assertEquals(1, domRows.size(), 'Un snapshot domicilio por owner y fecha');
        DomicilioSalesKPI__c d = domRows[0];
        System.assertEquals(
            'DOM|' + String.valueOf(ownerU.Id) + '|' + String.valueOf(Date.today()),
            d.UniqueKey__c
        );
        System.assert(d.ActiveCount__c > 0, 'Cartera activa domicilio');
        System.assert(d.RetainedCount__c > 0, 'Retención domicilio');
        System.assert(d.ChurnedCount__c > 0, 'Fuga domicilio');
        System.assert(d.NewAccountCount__c > 0, 'Nuevos domicilio');
        System.assertNotEquals(null, d.RecoveredCount__c, 'Recuperados domicilio definido');
        System.assertNotEquals(null, d.ChurnPct__c, '% fuga domicilio');
        System.assertNotEquals(null, d.RetainedPct__c, '% retención domicilio');
    }

    @IsTest
    static void test_upsertKPI_on_first_day_creates_monthly_roa() {
        User ownerU = [SELECT Id FROM User WHERE Email LIKE 'schedJobU%@t.icb' LIMIT 1];

        Test.startTest();
        ChurnKPIService.upsertKPI(new List<Id>{ ownerU.Id });
        Test.stopTest();

        if (Date.today().day() == 1) {
            List<MonthlyROAKPI__c> monthlyKPIs = [
                SELECT Id, OwnerId__c, Month__c, Year__c, MonthNumber__c,
                    CarteraActiva__c, Nuevos__c, Retenidos__c, Fugados__c, Recuperados__c
                FROM MonthlyROAKPI__c
                WHERE OwnerId__c = :ownerU.Id
            ];

            System.assert(monthlyKPIs.size() > 0, 'Si es día 1, debe existir al menos un registro mensual');
        } else {
            Integer monthlyCount = [
                SELECT COUNT()
                FROM MonthlyROAKPI__c
                WHERE OwnerId__c = :ownerU.Id
            ];
            System.assertEquals(0, monthlyCount, 'Si no es día 1, no debe crear registro mensual');
        }
    }

    @IsTest
    static void test_upsertKPI_with_null_userIds() {
        Test.startTest();
        ChurnKPIService.upsertKPI(null);
        Test.stopTest();

        Integer kpiCount = [
            SELECT COUNT()
            FROM SalesKPI__c
            WHERE AsOfDate__c = :Date.today()
        ];
        System.assert(kpiCount > 0, 'Debe crear KPIs cuando userIds es null');
    }

    @IsTest
    static void test_upsertKPI_with_empty_userIds() {
        Test.startTest();
        ChurnKPIService.upsertKPI(new List<Id>());
        Test.stopTest();

        Integer kpiCount = [
            SELECT COUNT()
            FROM SalesKPI__c
            WHERE AsOfDate__c = :Date.today()
        ];
        System.assert(kpiCount > 0, 'Debe crear KPIs cuando userIds está vacío');
    }

    @IsTest
    static void test_upsertKPI_covers_all_metrics() {
        User ownerU = [SELECT Id FROM User WHERE Email LIKE 'schedJobU%@t.icb' LIMIT 1];
        Test.startTest();
        ChurnKPIService.upsertKPI(new List<Id>{ ownerU.Id });
        Test.stopTest();

        List<SalesKPI__c> kpis = [
            SELECT
                Id,
                OwnerId,
                ActiveCount__c,
                ChurnedCount__c,
                RetainedCount__c,
                RecoveredCount__c,
                NewAccountCount__c,
                ChurnPct__c,
                RetainedPct__c
            FROM SalesKPI__c
            WHERE OwnerId = :ownerU.Id AND AsOfDate__c = :Date.today()
        ];

        System.assertEquals(1, kpis.size(), 'Debe existir un KPI');
        SalesKPI__c kpi = kpis[0];

        System.assertNotEquals(null, kpi.ActiveCount__c, 'ActiveCount debe tener valor');
        System.assertNotEquals(null, kpi.ChurnedCount__c, 'ChurnedCount debe tener valor');
        System.assertNotEquals(null, kpi.RetainedCount__c, 'RetainedCount debe tener valor');
        System.assertNotEquals(null, kpi.RecoveredCount__c, 'RecoveredCount debe tener valor');
        System.assertNotEquals(null, kpi.NewAccountCount__c, 'NewAccountCount debe tener valor');
    }

    @IsTest
    static void upsertKPI_bogus_user_id_returns_without_error() {
        Id bogusUserId = (Id) '005000000000000AAA';

        Test.startTest();
        ChurnKPIService.upsertKPI(new List<Id>{ bogusUserId });
        Test.stopTest();

        List<User> found = [SELECT Id FROM User WHERE Id = :bogusUserId];
        System.assertEquals(0, found.size(), 'El Id ficticio no debe existir como User');
    }

    @IsTest
    static void upsertKPI_inactive_user_returns_early() {
        User inactiveOwner = mkUser('inactOwn');
        inactiveOwner.IsActive = false;
        update inactiveOwner;

        Test.startTest();
        ChurnKPIService.upsertKPI(new List<Id>{ inactiveOwner.Id });
        Test.stopTest();

        Integer kpiForInactive = [
            SELECT COUNT()
            FROM SalesKPI__c
            WHERE OwnerId = :inactiveOwner.Id AND AsOfDate__c = :Date.today()
        ];
        System.assertEquals(0, kpiForInactive, 'Usuario inactivo no debe generar KPI');
    }
}