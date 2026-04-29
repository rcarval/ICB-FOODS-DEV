/**********************************************************************************
Desarrollado por: SEIDOR
Autor: Rodrigo Carvallo (RCG)
Proyecto: Maestra de Precios - Perfomance
Descripción: Clase de servicio para cálculo de márgenes en Maestra de Precios
Test: ICB_MargenService_Test

---------------------------------------------------------------------------------
No. Fecha                Autor                     Descripción
------ ---------- ---------------------------------------------------------------
1.0 08-10-2025            RCG                Creación de la clase.
**********************************************************************************/
public class ICB_MargenServiceImpl{

    /**
    * Método para calcular margen porcentual de producto en compras
    * @author Rodrigo Carvallo
    * @param List<Detalle_Factura__c> comprasMaestradePrecios - Lista de compras a calcular márgenes
    * @param Map<Id, Decimal> margenProductoMap - Mapa para almacenar márgenes calculados
    * @param Map<Id, Decimal> costosProductosMap - Mapa con costos de productos
    **/
    public static void calcularMargenPorcentajeCompras(List<Detalle_Factura__c> comprasMaestradePrecios, Map<Id, Decimal> margenProductoMap, Map<Id, Decimal> costosProductosMap) {
        System.debug('Iniciando el cálculo de Margen de % Producto para Compras');

        for (Detalle_Factura__c detalle : comprasMaestradePrecios) {
            // Obtener el costo del producto desde costosProductosMap
           Decimal costoBase = ICB_CostoServiceImpl.obtenerCostoProducto(detalle.Product__c, costosProductosMap);
            System.debug('Costo base obtenido para el producto ' + detalle.Product__c + ': ' + costoBase);
            
            // Verificar si el costo es nulo o cero
            if (costoBase == null || costoBase == 0) {
                // No asignar a campos que nunca tuvieron valores, solo continuar
                continue; // Pasar al siguiente detalle
            }
            
            // Precio_Cliente_Neto__c nunca tuvo valor, usar Valor_Neto__c
            Decimal precioClienteNeto = (detalle.Valor_Neto__c != null) ? detalle.Valor_Neto__c : 0;
            System.debug('Precio Cliente Neto obtenido: ' + precioClienteNeto);
            
            // Porcentaje_de_Rappel__c nunca tuvo valor, usar 0
            Decimal porcentajeRappel = 0;
            Decimal rappelAplicado = precioClienteNeto * (porcentajeRappel / 100);
            Decimal precioConRappel = precioClienteNeto + rappelAplicado;
            System.debug('Precio con Rappel aplicado: ' + precioConRappel);
            
            // Calcular el margen de producto usando el precio con rappel
            Decimal margenCalculado = 0;
            if (precioConRappel != 0) {
                margenCalculado = ((precioConRappel - costoBase) / precioConRappel) * 100;
            }
            
            // Guardar en el mapa (no asignar a campos que nunca tuvieron valores)
            margenProductoMap.put(detalle.Id, margenCalculado);
            System.debug('Producto ' + detalle.Id + ': Margen calculado = ' + margenCalculado + '%');
        }
    }

    /**
    * Método para calcular margen porcentual de producto en descuentos
    * @author Rodrigo Carvallo
    * @param List<Descuento_Cliente__c> descuentosClienteMaestradePrecios - Lista de descuentos a calcular márgenes
    * @param Map<Id, Decimal> costosProductosMap - Mapa con costos de productos
    * @param Map<Id, Decimal> margenProductoMap - Mapa para almacenar márgenes calculados
    **/
    public static void calcularMargenPorcentajeDescuento(List<Descuento_Cliente__c> descuentosClienteMaestradePrecios, Map<Id, Decimal> costosProductosMap, Map<Id, Decimal> margenProductoMap) {
        System.debug('Iniciando el cálculo de Margen de % Producto para Descuentos');
        
        for (Descuento_Cliente__c descuento : descuentosClienteMaestradePrecios) {
            // Obtener el costo del producto desde costosProductosMap
            Decimal costoBase = ICB_CostoServiceImpl.obtenerCostoProducto(descuento.Producto__c, costosProductosMap);
            System.debug('Costo base obtenido para el producto ' + descuento.Producto__c + ': ' + costoBase);
            
            // Verificar si el costo es nulo o cero
            if (costoBase == null || costoBase == 0) {
                descuento.Tiene_Costo__c = false;
                descuento.Error_Margen__c = 'El producto no tiene costo';
                descuento.Margen_Producto__c = null; // No calcular el margen
                continue; // Pasar al siguiente detalle
            } else {
                descuento.Tiene_Costo__c = true;
                descuento.Error_Margen__c = ''; // Limpia el mensaje de error si hay costo
            }
            
            
            // Obtener el precio cliente neto, asegurándose de que no sea nulo
            Decimal precioClienteNeto = (descuento.Precio_Cliente_Neto__c != null) ? descuento.Precio_Cliente_Neto__c : 0;
            System.debug('Precio Cliente Neto obtenido: ' + precioClienteNeto);
            
            // Aplicar el porcentaje de rappel sobre el precio cliente neto
            Decimal porcentajeRappel = descuento.Porcentaje_de_Rappel__c != null ? descuento.Porcentaje_de_Rappel__c : 0;
            Decimal rappelAplicado = precioClienteNeto * (porcentajeRappel / 100);
            Decimal precioConRappel = precioClienteNeto + rappelAplicado;
            System.debug('Precio con Rappel aplicado: ' + precioConRappel);
            
            // Calcular el margen de producto usando el precio con rappel
            if (precioConRappel != 0) {
                descuento.Margen_Producto__c = ((precioConRappel - costoBase) / precioConRappel) * 100;
            } else {
                descuento.Margen_Producto__c = 0;
            }
            
            margenProductoMap.put(descuento.Id, descuento.Margen_Producto__c);
            System.debug('Descuento ' + descuento.Id + ': Margen calculado = ' + descuento.Margen_Producto__c + '%');
        }
    }
    
    
    /**
    * Método para calcular margen de contribución por kilo en compras
    * @author Rodrigo Carvallo
    * @param List<Detalle_Factura__c> comprasMaestradePrecios - Lista de compras a calcular márgenes
    * @param Map<Id, Decimal> costosProductosMap - Mapa con costos de productos
    * @param Map<Id, Decimal> margenContribucionKiloMap - Mapa para almacenar márgenes por kilo
    **/
    public static void calcularMargenPorPesoCompras(List<Detalle_Factura__c> comprasMaestradePrecios, Map<Id, Decimal> costosProductosMap, Map<Id, Decimal> margenContribucionKiloMap) {
        System.debug('Iniciando el cálculo de Margen de Contribución por Kilo para Compras');
        
        for (Detalle_Factura__c detalle : comprasMaestradePrecios) {
            // Obtener el costo base del producto desde costosProductosMap
            Decimal costoBase = costosProductosMap.containsKey(detalle.Product__c) ? costosProductosMap.get(detalle.Product__c) : 0;
            System.debug('Costo base obtenido para el producto ' + detalle.Product__c + ': ' + costoBase);
            
            // Verificar si el costo es nulo o cero
            if (costoBase == null || costoBase == 0) {
                // No asignar a campos que nunca tuvieron valores, solo continuar
                continue; // Pasar al siguiente detalle
            }
            
            // Precio_Cliente_Neto__c nunca tuvo valor, usar Valor_Neto__c
            Decimal precioClienteNeto = (detalle.Valor_Neto__c != null) ? detalle.Valor_Neto__c : 0;
            System.debug('Precio Cliente Neto obtenido: ' + precioClienteNeto);
            
            // Porcentaje_de_Rappel__c nunca tuvo valor, usar 0
            Decimal porcentajeRappel = 0;
            Decimal rappelAplicado = precioClienteNeto * (porcentajeRappel / 100);
            Decimal costoTotal = costoBase + rappelAplicado;
            
            // Calcular el margen de contribución por kilo
            Decimal pesoProducto = (detalle.Product__r.Peso__c != null) ? detalle.Product__r.Peso__c : 0;
            Decimal margenPorKilo = 0;
            if (pesoProducto != 0) {
                margenPorKilo = (precioClienteNeto - costoTotal) / pesoProducto;
            }
            
            // Guardar en el mapa (no asignar a campos que nunca tuvieron valores)
            margenContribucionKiloMap.put(detalle.Id, margenPorKilo);
            System.debug('Producto ' + detalle.Id + ': Costo Total = ' + costoTotal + ', Precio Cliente Neto = ' + precioClienteNeto + ', Margen por Kilo = ' + margenPorKilo);
        }
    }
    
    /**
    * Método para calcular margen de contribución por kilo en descuentos
    * @author Rodrigo Carvallo
    * @param List<Descuento_Cliente__c> descuentosClienteMaestradePrecios - Lista de descuentos a calcular márgenes
    * @param Map<Id, Decimal> costosProductosMap - Mapa con costos de productos
    * @param Map<Id, Decimal> margenContribucionKiloMap - Mapa para almacenar márgenes por kilo
    **/
    public static void calcularMargenPorPesoDescuentos(List<Descuento_Cliente__c> descuentosClienteMaestradePrecios, Map<Id, Decimal> costosProductosMap, Map<Id, Decimal> margenContribucionKiloMap) {
        System.debug('Iniciando el cálculo de Margen de Contribución por Kilo para Descuentos');
        
        for (Descuento_Cliente__c descuento : descuentosClienteMaestradePrecios) {
            // Obtener el costo base del producto desde costosProductosMap
            Decimal costoBase = costosProductosMap.containsKey(descuento.Producto__c) ? costosProductosMap.get(descuento.Producto__c) : 0;
            System.debug('Costo base obtenido para el producto ' + descuento.Producto__c + ': ' + costoBase);
            
            // Verificar si el costo es nulo o cero
            if (costoBase == null || costoBase == 0) {
                descuento.Tiene_Costo__c = false;
                descuento.Error_Margen__c = 'El producto no tiene costo';
                descuento.Margen_Producto__c = null; // No calcular el margen
                continue; // Pasar al siguiente
            } else {
                descuento.Tiene_Costo__c = true;
                descuento.Error_Margen__c = ''; // Limpia el mensaje de error si hay costo
            }
            
            
            // Obtener el precio cliente neto, asegurándose de que no sea nulo
            Decimal precioClienteNeto = (descuento.Precio_Cliente_Neto__c != null) ? descuento.Precio_Cliente_Neto__c : 0;
            System.debug('Precio Cliente Neto obtenido: ' + precioClienteNeto);
            
            // Aplicar el porcentaje de rappel sobre el precio cliente neto
            Decimal porcentajeRappel = descuento.Porcentaje_de_Rappel__c != null ? descuento.Porcentaje_de_Rappel__c : 0;
            Decimal rappelAplicado = precioClienteNeto * (porcentajeRappel / 100);
            Decimal costoTotal = costoBase + rappelAplicado;
            
            // Calcular el margen de contribución por kilo
            Decimal pesoProducto = (descuento.Producto__r.Peso__c != null) ? descuento.Producto__r.Peso__c : 0;
            if (pesoProducto != 0) {
                descuento.Margen_de_Contribucion_por_Kilo__c = (precioClienteNeto - costoTotal) / pesoProducto;
            } else {
                descuento.Margen_de_Contribucion_por_Kilo__c = 0;
            }
            
            margenContribucionKiloMap.put(descuento.Id, descuento.Margen_de_Contribucion_por_Kilo__c);
            System.debug('Descuento ' + descuento.Id + ': Costo Total = ' + costoTotal + ', Precio Cliente Neto = ' + precioClienteNeto + ', Margen por Kilo = ' + descuento.Margen_de_Contribucion_por_Kilo__c);
        }
    }

}