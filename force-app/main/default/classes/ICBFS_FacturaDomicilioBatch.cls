/**
* @File Name : ICBFS_FacturaDomicilioBatch.cls
* @Description :
* @Author : Sebastian Albornoz
* @Last Modified By :
* @Last Modified On : October 20, 2025
* @Modification Log :
*==============================================================================
* Ver | Date       | Author           | Modification
*==============================================================================
* 1.0 | October 20, 2025 |                | Initial Version
* 1.1 | <fecha>          | <tu-nombre>      | Agregada comparación explícita Direccion__c == Cliente_Despacho__c
**/
public with sharing class ICBFS_FacturaDomicilioBatch implements Database.Batchable<SObject>, Database.Stateful {
    private final Set<Id> facturaIdFilter;
    private Integer totalProcessed = 0;
    private Integer totalUpdated   = 0;
    private Integer totalNoMatch   = 0;

    public ICBFS_FacturaDomicilioBatch(Set<Id> facturaIds) {
        this.facturaIdFilter = (facturaIds != null && !facturaIds.isEmpty()) ? facturaIds : null;
        System.debug(LoggingLevel.INFO, 'ICBFS_FacturaDomicilioBatch.constructor – facturaIdFilter = ' + facturaIdFilter);
    }

    public Database.QueryLocator start(Database.BatchableContext bc) {
        String baseQuery = 'SELECT Id, Direccion__c, Domicilio_Cliente__c ' +
                           'FROM Facturas__c ' +
                           'WHERE Direccion__c != null';
        if (facturaIdFilter != null) {
            baseQuery += ' AND Id IN :facturaIdFilter';
        }
        System.debug(LoggingLevel.INFO, 'ICBFS_FacturaDomicilioBatch.start – SOQL = ' + baseQuery);
        return Database.getQueryLocator(baseQuery);
    }

    public void execute(Database.BatchableContext bc, List<SObject> scope) {
        List<Facturas__c> facturas = (List<Facturas__c>) scope;
        System.debug(LoggingLevel.INFO, 'ICBFS_FacturaDomicilioBatch.execute – Received ' + facturas.size() + ' facturas in this batch');

        // Normalizar las direcciones de facturas
        Map<String, List<Facturas__c>> mapDireccionNormToFacturas = new Map<String, List<Facturas__c>>();
        for (Facturas__c f : facturas) {
            if (f.Direccion__c != null) {
                String dNorm = f.Direccion__c.trim().toLowerCase();
                if (!String.isBlank(dNorm)) {
                    if (!mapDireccionNormToFacturas.containsKey(dNorm)) {
                        mapDireccionNormToFacturas.put(dNorm, new List<Facturas__c>());
                    }
                    mapDireccionNormToFacturas.get(dNorm).add(f);
                }
            }
        }
        System.debug(LoggingLevel.DEBUG, 'Normalized direction groups count = ' + mapDireccionNormToFacturas.size());
        System.debug(LoggingLevel.DEBUG, 'Direction keys sample = ' + mapDireccionNormToFacturas.keySet());

        if (mapDireccionNormToFacturas.isEmpty()) {
            System.debug(LoggingLevel.INFO, 'No valid normalized directions found in this batch – skipping further processing');
            return;
        }

        // Obtener todos los domicilios que podrían coincidir
        List<Domicilio_de_Cliente__c> domicilios = [
            SELECT Id, Cliente_Despacho__c
            FROM Domicilio_de_Cliente__c
            WHERE Cliente_Despacho__c != null
        ];
        System.debug(LoggingLevel.INFO, 'Fetched ' + domicilios.size() + ' domicilios for matching');

        // Mapear la clave normalizada a domicilio
        Map<String, Domicilio_de_Cliente__c> mapNormDirToDomicilio = new Map<String, Domicilio_de_Cliente__c>();
        for (Domicilio_de_Cliente__c dom : domicilios) {
            String clave = dom.Cliente_Despacho__c.trim().toLowerCase();
            if (!String.isBlank(clave)) {
                if (!mapNormDirToDomicilio.containsKey(clave)) {
                    mapNormDirToDomicilio.put(clave, dom);
                }
            }
        }
        System.debug(LoggingLevel.DEBUG, 'Normalized domicilios map size = ' + mapNormDirToDomicilio.size());
        System.debug(LoggingLevel.DEBUG, 'Domicilio keys sample = ' + mapNormDirToDomicilio.keySet());

        // Preparar la lista de facturas a actualizar
        List<Facturas__c> toUpdate = new List<Facturas__c>();

        for (String dNorm : mapDireccionNormToFacturas.keySet()) {
            List<Facturas__c> factList = mapDireccionNormToFacturas.get(dNorm);
        
            if (mapNormDirToDomicilio.containsKey(dNorm)) {
                Domicilio_de_Cliente__c dom = mapNormDirToDomicilio.get(dNorm);
                String domicilioDirNorm = dom.Cliente_Despacho__c.trim().toLowerCase();
        
                for (Facturas__c f : factList) {
                    totalProcessed++;
                    String facturaDirNorm = f.Direccion__c.trim().toLowerCase();
                    System.debug(LoggingLevel.DEBUG, 'Factura Id: ' + f.Id + ' – facturaDirNorm="' + facturaDirNorm + '", domicilioDirNorm="' + domicilioDirNorm + '"');
        
                    if (facturaDirNorm == domicilioDirNorm) {
                        // Coinciden
                        if (f.Domicilio_Cliente__c == null || f.Domicilio_Cliente__c != dom.Id) {
                            System.debug(LoggingLevel.INFO, 'Factura Id: ' + f.Id + ' – actualizar domicilio de "' + f.Domicilio_Cliente__c + '" a "' + dom.Id + '"');
                            f.Domicilio_Cliente__c = dom.Id;
                            // si cambio domicilio => marcar procesada
                        } else {
                            System.debug(LoggingLevel.DEBUG, 'Factura Id: ' + f.Id + ' – ya tenía domicilio correcto (' + f.Domicilio_Cliente__c + '), pero se marca como procesada para no volver a revisar');
                            // no cambio domicilio pero igual la vamos a marcar procesada
                        }
                        // En todos los casos de coincidencia, marcar procesada
                        f.Ya_procesada__c = true;
                        toUpdate.add(f);
                        totalUpdated++; // aquí podemos considerar que “actualizada” también incluye “marcada procesada aunque no cambió domicilio”
                    } else {
                        System.debug(LoggingLevel.INFO, 'Factura Id: ' + f.Id + ' – no coincide dirección: facturaDir="' + facturaDirNorm + '", domicilioDir="' + domicilioDirNorm + '"');
                        // No coincide domicilio, pero aún la podrías querer marcar como procesada?
                        // Si quieres que también se marque para no volver a procesar, hazlo acá:
                        f.Ya_procesada__c = true;
                        toUpdate.add(f);
                        totalNoMatch++;
                    }
                }
            } else {
                System.debug(LoggingLevel.INFO, 'No domicilio encontrado para la clave "' + dNorm + '" – facturas implicadas: ' + factList.size());
                for (Facturas__c f : factList) {
                    totalProcessed++;
                    // No domicilio que coincida → marcar como procesada si así lo deseas
                    f.Ya_procesada__c = true;
                    toUpdate.add(f);
                    totalNoMatch++;
                }
            }
        }

        if (!toUpdate.isEmpty()) {
            try {
                System.debug(LoggingLevel.INFO, 'About to update ' + toUpdate.size() + ' facturas');
                update toUpdate;
                System.debug(LoggingLevel.INFO, 'Update successful for ' + toUpdate.size() + ' facturas');
            } catch (DmlException e) {
                System.debug(LoggingLevel.ERROR, 'Error during update to facturas: ' + e.getMessage());
                throw e;
            }
        } else {
            System.debug(LoggingLevel.INFO, 'No facturas to update in this batch');
        }
    }

    public void finish(Database.BatchableContext bc) {
        String msg = 'Batch FacturaDomicilio finished. Processed: ' + totalProcessed +
                     ', Updated: ' + totalUpdated +
                     ', No domicile match: ' + totalNoMatch;
        System.debug(LoggingLevel.INFO, msg);
        System.debug(LoggingLevel.INFO, 'ICBFS_FacturaDomicilioBatch.finish – Total actualizados correctamente = ' + totalUpdated);
    }
}