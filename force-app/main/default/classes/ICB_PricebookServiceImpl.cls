/**********************************************************************************
Desarrollado por: SEIDOR
Autor: Rodrigo Carvallo (RCG)
Proyecto: Maestra de Precios - Perfomance
Descripción: Clase de Pricebook para Maestra de Precios
Test: ICB_PricebookService_Test

---------------------------------------------------------------------------------
No. Fecha                Autor                     Descripción
------ ---------- ---------------------------------------------------------------
1.0 08-10-2025            RCG                Creación de la clase.
**********************************************************************************/
public class ICB_PricebookServiceImpl{

    /**
    * Método para buscar la Pricebook basada en la Sucursal__c de la cuenta
    * @author Rodrigo Carvallo
    * @param String sucursal
    * @return Pricebook2
    **/
    public static Pricebook2 buscarPricebookCliente(String sucursal) {
        Pricebook2 clientePricebook;
        if (!String.isBlank(sucursal)) {
            // Se extrae el código de la sucursal antes del guion
            String codigoSucursal = sucursal.split(' - ')[0];  // Esto separa por el " - " y toma el primer elemento (el código)
            
            // Construcción del nombre de la Pricebook usando solo el código de la sucursal
            String nombrePricebook = 'Precios ' + codigoSucursal;  // Usamos solo el código como S001, S002, etc.
            
            // Usar Repository para obtener pricebook
            clientePricebook = ICB_MaestraPreciosRepository.getPricebookByName(nombrePricebook);
            
            if (clientePricebook != null) {
                System.debug('Pricebook encontrada: ' + clientePricebook.Name);
            } else {
                System.debug('No se encontró la Pricebook con el nombre: ' + nombrePricebook);
            }
        } else {
            System.debug('La cuenta no tiene una sucursal definida.');
        }
        return clientePricebook;
    }

    /**
    * Método que retorna un Map ProductId, PricebookEntry Id con todos los pricebookEntry activos para cada producto y limpia descuento de clientes y compras
    * @author Rodrigo Carvallo
    * @param Set<Id> productIds
    * @param List<Descuento_Cliente__c> descuentosClienteMaestradePrecios
    * @param List<Detalle_Factura__c> comprasMaestradePrecios
    * @param Pricebook2 clientePricebook
    * @param Map<Id, Decimal> costosProductosMap
    * @return Map<Id,Id>
    **/
    public static Map<Id,Id> cargarPricebookEntries(Set<Id> productIds, List<Descuento_Cliente__c> descuentosClienteMaestradePrecios, List<Detalle_Factura__c> comprasMaestradePrecios, Pricebook2 clientePricebook, Map<Id, Decimal> costosProductosMap) {
        Map<Id, Id> pricebookEntriesMap = new Map<Id, Id>();
        Map<Id,Id> pricebookEntriesDesactive = new Map<Id,Id>();
        if (clientePricebook != null) {
            // Usar Repository para obtener PricebookEntries
            List<PricebookEntry> pricebookEntries = ICB_MaestraPreciosRepository.getPricebookEntriesActivosByProductos(
                clientePricebook.Id, productIds
            );
            
            if (!pricebookEntries.isEmpty()) {
                for (PricebookEntry pricebookEntry : pricebookEntries) {
                    if(pricebookEntry.IsActive) {
                        pricebookEntriesMap.put(pricebookEntry.Product2Id, pricebookEntry.Id);
                    } else {
                        pricebookEntriesDesactive.put(pricebookEntry.Product2Id, pricebookEntry.Id); //agregamos a una lista los pricebookEntries desactivados
                    }
                }
            }
            if(pricebookEntriesDesactive.size()>0) {
                //metodo para borrar los pricebookEntries desactivados
                borrarPricebookEntriesDesactivados(pricebookEntriesDesactive, descuentosClienteMaestradePrecios, comprasMaestradePrecios, productIds, costosProductosMap);
            }
        } else {
            System.debug('No se encontró la Pricebook para cargar PricebookEntries.');
        }
        return pricebookEntriesMap;
    }

    /**
    * Método que  limpia descuento de clientes, compras y productos con pricebookEntry desactivado
    * @author Rodrigo Carvallo
    * @param Map<Id,Id> pricebookEntriesDesactive
    * @param List<Descuento_Cliente__c> descuentosClienteMaestradePrecios
    * @param List<Detalle_Factura__c> comprasMaestradePrecios
    * @param Set<Id> productIds
    **/
    private static void borrarPricebookEntriesDesactivados(Map<Id,Id> pricebookEntriesDesactive, List<Descuento_Cliente__c> descuentosClienteMaestradePrecios, List<Detalle_Factura__c> comprasMaestradePrecios, Set<Id> productIds, Map<Id, Decimal> costosProductosMap){
        
        List<Descuento_Cliente__c> listaDescuentoTemporal = new List<Descuento_Cliente__c>();
        List<Detalle_Factura__c> listaComprasTemporal = new List<Detalle_Factura__c>();
        Set<Id> idProductosTemporal = new Set<Id>();
        
        //Elimino de los descuentos el producto que tiene el pricebook desactivado
        for(Descuento_Cliente__c descuento : descuentosClienteMaestradePrecios) {
            if(!pricebookEntriesDesactive.containsKey(descuento.Producto__c)) {
                listaDescuentoTemporal.add(descuento);
            }
        }

        //pasar la lista temporal a la lista original
        descuentosClienteMaestradePrecios = listaDescuentoTemporal;

        //Elimino de las compras el producto que tiene el pricebook desactivado
        for(Detalle_Factura__c detalle : comprasMaestradePrecios) {
            if(!pricebookEntriesDesactive.containsKey(detalle.Product__c)) {
                listaComprasTemporal.add(detalle);
            }
        }

        //pasar la lista temporal a la lista original
        comprasMaestradePrecios = listaComprasTemporal;

        //borrar el producto del mapa de costosMap
        for(Id key : pricebookEntriesDesactive.keySet()) {
            costosProductosMap.remove(key);
        }
        
        //borrar los productos del Set de productos
        for(Id idsProducto: productIds) {
            if(!pricebookEntriesDesactive.containsKey(idsProducto)) {
                idProductosTemporal.add(idsProducto);
            }
        }
        
        //pasar el set temporal al set original
        productIds = idProductosTemporal;
    }

    /**
    * Método que retorna todos los pricebook Entry mediante el pricebook
    * @author Rodrigo Carvallo
    * @param Pricebook2 pricebook
    * @return List<PricebookEntry>
    **/
    public static List<PricebookEntry> cargarTodosLosPricebookEntries(Pricebook2 pricebook) {
        List<PricebookEntry> allPricebookEntries;
        if (pricebook != null) {
            // Usar Repository para obtener todos los PricebookEntries
            allPricebookEntries = ICB_MaestraPreciosRepository.getPricebookEntriesByPricebook(pricebook.Id);
        } else {
            System.debug('No se encontró la Pricebook para cargar PricebookEntries.');
        }
        return allPricebookEntries;
    }
    
    /**
    * Método para obtener el PricebookEntryId dado un Product2Id
    * @author Rodrigo Carvallo
    * @param Id productId
    * @param Map<Id, Id> pricebookEntriesMap
    * @return Id
    **/
    public static Id getPricebookEntryIdByProductId(Id productId, Map<Id, Id> pricebookEntriesMap) {
        return pricebookEntriesMap.containsKey(productId) ? pricebookEntriesMap.get(productId) : null;
    }

    /**
    * Método para obtener el Id del Pricebook asociado al cliente
    * @author Rodrigo Carvallo
    * @param Id productId
    * @param Map<Id, Id> pricebookEntriesMap
    * @return Id
    **/
    public static Id getPricebookId(Pricebook2 clientePricebook) {
        return (clientePricebook != null) ? clientePricebook.Id : null;
    }
}