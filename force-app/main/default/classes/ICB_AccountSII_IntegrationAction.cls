/**********************************************************************************
 * ICB_AccountSII_IntegrationAction
 * Acción invocable desde Flow: obtiene Accounts por Id y encola integración SII.
 * Ticket: 00025935 — SEIDOR
 **********************************************************************************/
public with sharing class ICB_AccountSII_IntegrationAction {

    public class InvocableInput {
        @InvocableVariable(label='Ids de Account' description='Ids de cuenta a integrar (colección desde el Flow)')
        public List<Id> accountIds;
    }

    public class InvocableOutput {
        @InvocableVariable(label='Trabajo encolado')
        public Boolean queued;
        @InvocableVariable(label='Id del job asíncrono (Queueable)')
        public String asyncJobId;
        @InvocableVariable(label='Mensaje')
        public String message;
    }

    @InvocableMethod(
        label='Integrar Account con SII (encolar)'
        description='Consulta cuentas por Id y encola el proceso asíncrono hacia el servicio SII.'
        category='Account'
    )
    public static List<InvocableOutput> enqueueAccountSIIIntegration(List<InvocableInput> inputs) {
        List<InvocableOutput> outputs = new List<InvocableOutput>();
        if (inputs == null || inputs.isEmpty()) {
            return outputs;
        }

        Set<Id> allIds = new Set<Id>();
        for (InvocableInput row : inputs) {
            if (row != null && row.accountIds != null) {
                for (Id aid : row.accountIds) {
                    if (aid != null) {
                        allIds.add(aid);
                    }
                }
            }
        }

        String jobIdStr;
        Boolean queued = false;
        String message;
        if (allIds.isEmpty()) {
            message = 'No se recibieron Ids de Account válidos.';
        } else {
            List<Account> found = ICB_AccountSII_IntegrationService.queryAccountsForSII(allIds);
            if (found.isEmpty()) {
                message = 'No existen registros de Account para los Ids indicados.';
            } else {
                List<Id> toQueue = new List<Id>();
                for (Account a : found) {
                    toQueue.add(a.Id);
                }
                jobIdStr = System.enqueueJob(new ICB_AccountSII_IntegrationQueueable(toQueue));
                queued = true;
                message = 'Integración encolada.';
            }
        }

        for (Integer i = 0; i < inputs.size(); i++) {
            InvocableOutput o = new InvocableOutput();
            o.queued = queued;
            o.asyncJobId = jobIdStr;
            o.message = message;
            outputs.add(o);
        }
        return outputs;
    }
}