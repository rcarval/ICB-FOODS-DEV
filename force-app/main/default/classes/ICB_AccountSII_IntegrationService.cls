/**********************************************************************************
 * ICB_AccountSII_IntegrationService
 * Consulta Account, armado de payload JSON y validación de datos para integración SII.
 * Ticket: 00025935 — SEIDOR
 * Nota: Contrato HTTP final se definirá cuando ICB_CalloutAPI_SII esté listo.
 **********************************************************************************/
public with sharing class ICB_AccountSII_IntegrationService {

    /** Campos mínimos para considerar la cuenta lista (ajustar cuando exista spec del SII). */
    private static final Set<String> REQUIRED_BILLING_FIELDS = new Set<String>{
        'BillingCity',
        'BillingCountry'
    };

    /**
     * DTO de solicitud hacia el servicio (esqueleto; ampliar según API real).
     */
    public class AccountSIIRequestDto {
        public String salesforceAccountId;
        public String name;
        public String phone;
        public String industry;
        public String website;
        public BillingDto billing;
    }

    public class BillingDto {
        public String street;
        public String city;
        public String state;
        public String postalCode;
        public String country;
    }

    public class ValidationResult {
        public Boolean isComplete;
        public List<String> missingFields;

        public ValidationResult() {
            this.isComplete = true;
            this.missingFields = new List<String>();
        }
    }

    /**
     * Cuentas por Id para el flujo principal (IDs que envía el Flow).
     */
    public static List<Account> queryAccountsForSII(Set<Id> accountIds) {
        if (accountIds == null || accountIds.isEmpty()) {
            return new List<Account>();
        }
        return [
            SELECT
                Id,
                Name,
                Phone,
                Industry,
                Website,
                BillingStreet,
                BillingCity,
                BillingState,
                BillingPostalCode,
                BillingCountry,
                ParentId
            FROM Account
            WHERE Id IN :accountIds
        ];
    }

    /*
     * Ejemplo futuro: cuentas relacionadas (jerarquía, sucursales, etc.).
     * Descomentar y ajustar SOQL cuando negocio lo defina.
     *
     * public static List<Account> queryRelatedAccounts(Id rootAccountId) {
     *     return [
     *         SELECT Id, Name, ParentId
     *         FROM Account
     *         WHERE ParentId = :rootAccountId OR Id = :rootAccountId
     *     ];
     * }
     */

    public static ValidationResult validateAccountForSII(Account acc) {
        ValidationResult vr = new ValidationResult();
        if (acc == null) {
            vr.isComplete = false;
            vr.missingFields.add('Account');
            return vr;
        }
        if (String.isBlank(acc.Name)) {
            vr.isComplete = false;
            vr.missingFields.add('Name');
        }
        for (String f : REQUIRED_BILLING_FIELDS) {
            Object val = acc.get(f);
            if (val == null || (val instanceof String && String.isBlank((String) val))) {
                vr.isComplete = false;
                vr.missingFields.add(f);
            }
        }
        return vr;
    }

    public static String buildRequestJson(Account acc) {
        AccountSIIRequestDto dto = new AccountSIIRequestDto();
        dto.salesforceAccountId = acc.Id != null ? String.valueOf(acc.Id) : null;
        dto.name = acc.Name;
        dto.phone = acc.Phone;
        dto.industry = acc.Industry;
        dto.website = acc.Website;
        dto.billing = new BillingDto();
        dto.billing.street = acc.BillingStreet;
        dto.billing.city = acc.BillingCity;
        dto.billing.state = acc.BillingState;
        dto.billing.postalCode = acc.BillingPostalCode;
        dto.billing.country = acc.BillingCountry;
        return JSON.serialize(dto);
    }
}