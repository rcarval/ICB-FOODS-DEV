/**********************************************************************************
Desarrollado por: SEIDOR
Autor: Rodrigo Carvallo (RCG)
Proyecto: Maestra de Precios - Perfomance
Descripción: Clase de servicio para gestión de costos en Maestra de Precios
Test: ICB_CostoService_Test

---------------------------------------------------------------------------------
No. Fecha                Autor                     Descripción
------ ---------- ---------------------------------------------------------------
1.0 08-10-2025            RCG                Creación de la clase.
**********************************************************************************/
public class ICB_CostoServiceImpl{

    /**
    * Método para buscar costos de productos filtrados por centro de abastecimiento
    * @author Rodrigo Carvallo
    * @param Map<Id, Decimal> costosProductosMap - Mapa para almacenar costos encontrados
    * @param List<Detalle_Factura__c> comprasMaestradePrecios - Lista de compras para obtener productos
    * @param List<Descuento_Cliente__c> descuentosClienteMaestradePrecios - Lista de descuentos para obtener productos
    **/
    public static void buscarCostosParaProductos(Map<Id, Decimal> costosProductosMap, List<Detalle_Factura__c> comprasMaestradePrecios, List<Descuento_Cliente__c> descuentosClienteMaestradePrecios) {
        Set<Id> productoIds = new Set<Id>();
        Map<Id, String> centrosAbastecimientoPorProducto = new Map<Id, String>();
        
        // Obtener los productos y el centro de abastecimiento de compras
        for (Detalle_Factura__c detalle : comprasMaestradePrecios) {
            if (detalle.Product__c != null && detalle.Factura__r.Cliente__r.Centro_de_Abastecimiento__c != null) {
                productoIds.add(detalle.Product__c);
                // Solo almacenar los primeros 4 caracteres del centro de abastecimiento para el filtro
                System.debug(detalle.Factura__r.Cliente__r.Centro_de_Abastecimiento__c.substring(0, 4));
                centrosAbastecimientoPorProducto.put(detalle.Product__c, 
                                                     detalle.Factura__r.Cliente__r.Centro_de_Abastecimiento__c.substring(0, 4));
                System.debug(centrosAbastecimientoPorProducto.values());                                                     
            }
        }
        
        // Obtener los productos y el centro de abastecimiento de descuentos
        for (Descuento_Cliente__c descuento : descuentosClienteMaestradePrecios) {
            if (descuento.Producto__c != null && descuento.Cliente__r.Centro_de_Abastecimiento__c != null) {
                productoIds.add(descuento.Producto__c);
                // Solo almacenar los primeros 4 caracteres del centro de abastecimiento para el filtro
                System.debug(descuento.Cliente__r.Centro_de_Abastecimiento__c.substring(0, 4));
                centrosAbastecimientoPorProducto.put(descuento.Producto__c, 
                                                     descuento.Cliente__r.Centro_de_Abastecimiento__c.substring(0, 4));
                System.debug(centrosAbastecimientoPorProducto.values());                                                     
            }
        }
        
        // Construir la consulta de costos usando los productos y centros de abastecimiento específicos
        System.debug(productoIds);
        System.debug(centrosAbastecimientoPorProducto.values());
        
        // Obtener centros de abastecimiento únicos y usar Repository
        Set<String> centrosAbastecimientoUnicos = new Set<String>(centrosAbastecimientoPorProducto.values());
        List<Costo__c> costos = ICB_MaestraPreciosRepository.getCostosByProductosAndCentros(
            productoIds, 
            centrosAbastecimientoUnicos
        );
        
        // Asignar costos al mapa solo si coinciden tanto en producto como en centro de abastecimiento
        for (Costo__c costo : costos) {
            String centroAbastecimiento = centrosAbastecimientoPorProducto.get(costo.Codigo_del_Producto__c);
            if (centroAbastecimiento != null && centroAbastecimiento == costo.Centro_de_Abastecimiento__c) {
                costosProductosMap.put(costo.Codigo_del_Producto__c, costo.CostoProducto__c);
            }
        }
        
        // Depuración para verificar los costos encontrados
        for (Id productoId : costosProductosMap.keySet()) {
            System.debug('Producto ID ' + productoId + ': Costo encontrado = ' + costosProductosMap.get(productoId));
        }
    }
    
    
    /**
    * Método para obtener el costo de un producto específico desde el mapa
    * @author Rodrigo Carvallo
    * @param Id productoId - ID del producto a consultar
    * @param Map<Id, Decimal> costosProductosMap - Mapa con los costos de productos
    * @return Decimal - Costo del producto o 0 si no se encuentra
    **/
    public static Decimal obtenerCostoProducto(Id productoId, Map<Id, Decimal> costosProductosMap) {
        return costosProductosMap.containsKey(productoId) ? costosProductosMap.get(productoId) : 0;
    }
}