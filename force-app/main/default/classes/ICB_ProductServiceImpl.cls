/**********************************************************************************
Desarrollado por: SEIDOR
Autor: Rodrigo Carvallo (RCG)
Proyecto: Maestra de Precios - Perfomance
Descripción: Clase de Product para Maestra de Precios
Test: ICB_ProductService_Test

---------------------------------------------------------------------------------
No. Fecha                Autor                     Descripción
------ ---------- ---------------------------------------------------------------
1.0 11-09-2025            RCG                Creación de la clase.
**********************************************************************************/
public class ICB_ProductServiceImpl{

    /**
    * Retorna una lista de Id de Product2 en base al detalle de compras y los descuento de Maestra de Precios
    * @author Rodrigo Carvallo
    * @param List<Detalle_Factura__c> comprasMaestradePrecios
    * @return Set<Id>
    **/
    public static Set<Id> cargarProductIds(List<Detalle_Factura__c> comprasMaestradePrecios, List<Descuento_Cliente__c> descuentosClienteMaestradePrecios) {
        Set<Id> productIds = new Set<Id>();
        // Cargar los Product2 Ids en productIds desde las compras (Detalle_Factura__c)
        for (Detalle_Factura__c detalle : comprasMaestradePrecios) {
            if (detalle.Product__c != null) {
                productIds.add(detalle.Product__c);
            }
        }
        
        // Cargar los Product2 Ids en productIds desde los descuentos (Descuento_Cliente__c)
        for (Descuento_Cliente__c descuento : descuentosClienteMaestradePrecios) {
            if (descuento.Producto__c != null) {
                productIds.add(descuento.Producto__c);
            }
        }
        return productIds;
    }

}