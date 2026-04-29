/**********************************************************************************
Desarrollado por: SEIDOR
Autor: Rodrigo Carvallo (RCG)
Proyecto: Maestra de Precios - Perfomance
Descripción: Clase de servicio para gestión de recargos en Maestra de Precios
Test: ICB_RecargoService_Test

---------------------------------------------------------------------------------
No. Fecha                Autor                     Descripción
------ ---------- ---------------------------------------------------------------
1.0 07-10-2025            RCG                Creación de la clase.
**********************************************************************************/
public class ICB_RecargoServiceImpl{

    /**
    * Método para calcular recargos aplicados a compras del cliente
    * @author Rodrigo Carvallo
    * @param List<Detalle_Factura__c> comprasMaestradePrecios - Lista de compras a aplicar recargos
    **/
    public static void calcularRecargosparaCompras(List<Detalle_Factura__c> comprasMaestradePrecios) {
        // Descuento_Cliente__r nunca tuvo valores, por lo que no se pueden aplicar recargos
        // El método solo asegura que Valor_Neto__c tenga un valor válido
        for (Detalle_Factura__c detalle : comprasMaestradePrecios) {
            // Si Valor_Neto__c es nulo, se asigna 0
            if (detalle.Valor_Neto__c == null) {
                detalle.Valor_Neto__c = 0; // Asegurarse de que tenga un valor inicial
            }
            System.debug('Detalle ' + detalle.Id + ': Valor Neto = ' + detalle.Valor_Neto__c);
        }
    }

    /**
    * Método para calcular recargos aplicados a descuentos del cliente
    * @author Rodrigo Carvallo
    * @param List<Descuento_Cliente__c> descuentosClienteMaestradePrecios - Lista de descuentos a aplicar recargos
    **/
    public static void calcularRecargosParaDescuentos(List<Descuento_Cliente__c> descuentosClienteMaestradePrecios) {
        // Lista de Descuento_Cliente__c cargada en la variable descuentosCliente
        for (Descuento_Cliente__c descuento : descuentosClienteMaestradePrecios) {
            // Asegurarse de que se haya calculado el Valor_Neto__c previamente
            // Si Valor_Neto__c es nulo, se asigna 0
            if (descuento.Valor_Neto__c == null) {
                descuento.Valor_Neto__c = 0; // Asegurarse de que tenga un valor inicial
            }
            // Obtener el valor neto (que ya se asegura que no sea nulo)
            Decimal valorNeto = descuento.Valor_Neto__c;
            // Calcular recargos solo si el campo Es_recargo__c es verdadero
            if (Boolean.valueOf(descuento.Es_recargo__c) == true &&
                descuento.Descuento_gestionado__c != null) {
                    // Aplicar el porcentaje de recargo
                    Decimal porcentajeRecargo = descuento.Descuento_gestionado__c;
                    // Calcular el recargo
                    Decimal valorRecargo = (porcentajeRecargo / 100) * valorNeto;
                    // Sumar el recargo al valor neto
                    descuento.Valor_Neto__c += valorRecargo;
                    System.debug('Descuento ' + descuento.Id + ': Valor Neto = ' + valorNeto + ', Recargo = ' + valorRecargo + ', Nuevo Valor Neto = ' + descuento.Valor_Neto__c);
                }
            
            // Asignar el valor calculado a Precio_Final__c
            descuento.Precio_Final__c = descuento.Valor_Neto__c;
            // Si Es_recargo__c es false, simplemente mantendremos el Valor_Neto__c
            System.debug('Descuento ' + descuento.Id + ': Precio Final = ' + descuento.Precio_Final__c);
        }
    }
}