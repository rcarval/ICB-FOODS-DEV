/**********************************************************************************
 * ICB_AccountSII_IntegrationQueueable
 * Ejecuta validación, armado de payload y futuro callout a SII en contexto asíncrono.
 * Ticket: 00025935 — SEIDOR
 * El callout real se delegará a ICB_CalloutAPI_SII cuando el método esté disponible.
 **********************************************************************************/
public with sharing class ICB_AccountSII_IntegrationQueueable implements Queueable, Database.AllowsCallouts {

    private final List<Id> accountIds;

    public ICB_AccountSII_IntegrationQueueable(List<Id> accountIds) {
        this.accountIds = accountIds != null ? accountIds : new List<Id>();
    }

    public void execute(QueueableContext context) {
        Set<Id> idSet = new Set<Id>();
        for (Id aid : accountIds) {
            if (aid != null) {
                idSet.add(aid);
            }
        }
        if (idSet.isEmpty()) {
            return;
        }

        List<Account> accounts = ICB_AccountSII_IntegrationService.queryAccountsForSII(idSet);
        Map<Id, Account> byId = new Map<Id, Account>(accounts);

        for (Id aid : idSet) {
            Account acc = byId.get(aid);
            if (acc == null) {
                ICB_AccountSII_IntegrationService.ValidationResult vr =
                    new ICB_AccountSII_IntegrationService.ValidationResult();
                vr.isComplete = false;
                vr.missingFields.add('Account no encontrado');
                ICB_AccountSII_ResponseHandler.applyValidationFailure(aid, vr);
                continue;
            }

            ICB_AccountSII_IntegrationService.ValidationResult vr =
                ICB_AccountSII_IntegrationService.validateAccountForSII(acc);
            if (!vr.isComplete) {
                ICB_AccountSII_ResponseHandler.applyValidationFailure(acc.Id, vr);
                continue;
            }

            String payloadJson = ICB_AccountSII_IntegrationService.buildRequestJson(acc);

            /*
             * Cuando ICB_CalloutAPI_SII exponga un método estático (ej. enviarCuenta(String json, Id accountId)),
             * reemplazar el bloque siguiente:
             *
             * HttpResponse res = ICB_CalloutAPI_SII.enviarCuenta(payloadJson, acc.Id);
             * ICB_AccountSII_ResponseHandler.applyHttpResponse(acc.Id, res, payloadJson);
             */
            HttpResponse res = null;
            ICB_AccountSII_ResponseHandler.applyHttpResponse(acc.Id, res, payloadJson);
        }
    }
}