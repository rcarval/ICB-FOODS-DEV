/**********************************************************************************
Desarrollado por: SEIDOR
Autor: Rodrigo Carvallo (RCG)
Proyecto: Maestra de Precios - Perfomance
Descripción: Clase de servicio para gestión de precios y cálculos en Maestra de Precios
Test: ICB_PrecioService_Test

---------------------------------------------------------------------------------
No. Fecha                Autor                     Descripción
------ ---------- ---------------------------------------------------------------
1.0 09-10-2025            RCG                Creación de la clase.
**********************************************************************************/
public class ICB_PrecioServiceImpl{


    /**
    * Método para obtener compras del cliente filtradas por productos existentes
    * @author Rodrigo Carvallo
    * @param Id accountId - ID del cliente
    * @param Set<Id> productosExistentes - Conjunto de IDs de productos ya existentes
    * @return List<Detalle_Factura__c> - Lista de compras de los últimos 3 meses sin duplicados
    **/
    public static List<Detalle_Factura__c> getComprasMaestraPrecios(Id accountId, Set<Id> productosExistentes){
        Date today = Date.today();
        Date threeMonthsAgo = today.addMonths(-3);
        
        // Set para almacenar los IDs de los Detalle_Factura__c y evitar duplicados
        Map<Id, Detalle_Factura__c> detallesPorVentaMap = new Map<Id, Detalle_Factura__c>();
        
        //REPOSITORY
        List<Detalle_Factura__c> detallesPorVenta = ICB_MaestraPreciosRepository.getDetallesComprasByCliente(accountId, threeMonthsAgo);
        
        List<Detalle_Factura__c> comprasFiltradas = new List<Detalle_Factura__c>();
        
        // Filtrar duplicados basados en Product__c
        for (Detalle_Factura__c detalle : detallesPorVenta) {
            if (!productosExistentes.contains(detalle.Product__c)) {
                comprasFiltradas.add(detalle);
                productosExistentes.add(detalle.Product__c);
            }
        }
        return comprasFiltradas;
    }

    /**
    * Método para calcular precios de compras considerando pricebooks y precios especiales
    * @author Rodrigo Carvallo
    * @param String sucursal - Sucursal del cliente para identificar pricebook
    * @param List<Detalle_Factura__c> comprasMaestradePrecios - Lista de compras a procesar
    **/
    public static void calcularPreciosCompras(String sucursal, List<Detalle_Factura__c> comprasMaestradePrecios){
        // Extraer la parte relevante de la sucursal
        String codigoSucursal = sucursal.split(' ')[0];
        // Construir el nombre de la Pricebook
        String nombrePricebook = 'Precios ' + codigoSucursal;
        
        // Buscar la Pricebook correspondiente
        Pricebook2 clientePricebook = ICB_MaestraPreciosRepository.getPricebookByName(nombrePricebook);
        
        // Obtener los IDs de todos los productos y clientes de las compras
        Set<Id> productIds = new Set<Id>();
        Set<Id> clienteIds = new Set<Id>();
        
        for (Detalle_Factura__c detalle : comprasMaestradePrecios) {
            if (detalle.Product__c != null) {
                productIds.add(detalle.Product__c);
            }
            if (detalle.Factura__r.Cliente__c != null) {
                clienteIds.add(detalle.Factura__r.Cliente__c);
            }
        }
        
        // Query para obtener los precios antes del loop
        Map<Id, Map<Id, Precios__c>> preciosPorClienteYProducto = new Map<Id, Map<Id, Precios__c>>();
        List<Precios__c> preciosList = ICB_MaestraPreciosRepository.getPreciosVigentesByClientesYProductos(
            clienteIds, productIds, Date.today());
        
        for (Precios__c precio : preciosList) {
            if (!preciosPorClienteYProducto.containsKey(precio.Cliente__c)) {
                preciosPorClienteYProducto.put(precio.Cliente__c, new Map<Id, Precios__c>());
            }
            preciosPorClienteYProducto.get(precio.Cliente__c).put(precio.Detalle_de_producto__c, precio);
        }
        
        // Query para obtener PricebookEntry
        Map<Id, Decimal> pricebookEntriesMap = new Map<Id, Decimal>();
        if (clientePricebook != null) {
            List<PricebookEntry> pbeList = ICB_MaestraPreciosRepository.getPricebookEntriesByProductos(
                clientePricebook.Id, productIds);
            for (PricebookEntry pbe : pbeList) {
                pricebookEntriesMap.put(pbe.Product2Id, pbe.UnitPrice);
            }
        }
        
        
        for (Detalle_Factura__c detalle : comprasMaestradePrecios) {
            // Inicializa el valor neto a 0 como valor por defecto
            detalle.Valor_Neto__c = 0;
            // Error_Precio__c no existe en Detalle_Factura__c, campo eliminado
            
            // Verificar si hay un precio en el mapa por cliente y producto
            Boolean precioEncontrado = false;
            if (preciosPorClienteYProducto.containsKey(detalle.Factura__r.Cliente__c) &&
                preciosPorClienteYProducto.get(detalle.Factura__r.Cliente__c).containsKey(detalle.Product__c)) {
                    // Asignar el valor del Precio_de_lista__c encontrado en el mapa
                    detalle.Valor_Neto__c = (Integer.valueOf(preciosPorClienteYProducto
                                                             .get(detalle.Factura__r.Cliente__c)
                                                             .get(detalle.Product__c)
                                                             .Precio_de_lista__c));
                    precioEncontrado = true;
                } else if (pricebookEntriesMap.containsKey(detalle.Product__c)) {
                    // Si no se encontró en `Precios__c`, se verifica en el `PricebookEntry`
                    detalle.Valor_Neto__c = (Integer.valueOf(pricebookEntriesMap.get(detalle.Product__c)));
                    precioEncontrado = true;
                }
            
            // Si no se encontró precio, mantener Valor_Neto__c en 0
            if (!precioEncontrado) {
                detalle.Valor_Neto__c = 0;
                // Error_Precio__c no existe en Detalle_Factura__c, campo eliminado
            }
        }
    }

    /**
    * Método para obtener el precio final de una compra específica
    * @author Rodrigo Carvallo
    * @param Id detalleId - ID del detalle de compra a consultar
    * @param List<Detalle_Factura__c> comprasMaestradePrecios - Lista donde buscar la compra
    * @return Decimal - Precio final de la compra o 0 si no se encuentra
    **/
    public static Decimal getPrecioFinalCompras(Id detalleId, List<Detalle_Factura__c> comprasMaestradePrecios){
        for (Detalle_Factura__c detalle : comprasMaestradePrecios) {
            if (detalle.Id == detalleId) {
                // Precio_Final__c nunca tuvo valor, usar Valor_Neto__c
                return detalle.Valor_Neto__c != null ? detalle.Valor_Neto__c : 0;
            }
        }
        return 0; // Retorna 0 si no se encuentra el registro
    }


    /**
    * Método para calcular precio cliente neto con aplicación de rappels en descuentos
    * @author Rodrigo Carvallo
    * @param List<Descuento_Cliente__c> descuentosClienteMaestradePrecios - Lista de descuentos a procesar
    * @param Id accountId - ID del cliente para buscar rappels
    * @param Map<Id, Decimal> preciosClienteNeto - Mapa para almacenar precios netos calculados
    **/
    public static void calcularPrecioClienteNetoConRappelDescuentos(List<Descuento_Cliente__c> descuentosClienteMaestradePrecios, Id accountId, Map<Id, Decimal> preciosClienteNeto){
        Date today = Date.today(); // Obtener la fecha actual
        
        // Crear un mapa de rappels por cliente y producto
        Map<Id, Map<Id, Rappel__c>> rappelsPorClienteYProducto = new Map<Id, Map<Id, Rappel__c>>();
        
        // Consulta de rappels
        List<Rappel__c> rappelList = ICB_MaestraPreciosRepository.getRappelsVigentesByCliente(accountId, today);
        
        // Organizar los rappels en un mapa por cliente y producto
        for (Rappel__c rappel : rappelList) {
            if (!rappelsPorClienteYProducto.containsKey(rappel.Cliente__c)) {
                rappelsPorClienteYProducto.put(rappel.Cliente__c, new Map<Id, Rappel__c>());
            }
            rappelsPorClienteYProducto.get(rappel.Cliente__c).put(rappel.Product__c, rappel);
        }
        
        // Procesar cada descuento en descuentosClienteMaestradePrecios
        for (Descuento_Cliente__c descuentoCliente : descuentosClienteMaestradePrecios) {
            Decimal precioFinal = Integer.valueOf(descuentoCliente.Precio_Final__c);
            Decimal descuento = descuentoCliente.Descuento_gestionado__c;
            
            // Calcular el precio después del descuento
            Decimal precioDespuesDescuento = (descuento != null)
                ? Integer.valueOf(precioFinal - (precioFinal * descuento / 100))
                : precioFinal;
            
            // Inicializa el porcentaje de rappel
            Decimal porcentajeRappel = 0;
            Boolean rappelVigenteEncontrado = false;
            
            // Verificar si hay un rappel para el cliente y producto en el mapa
            if (rappelsPorClienteYProducto.containsKey(descuentoCliente.Cliente__c) &&
                rappelsPorClienteYProducto.get(descuentoCliente.Cliente__c).containsKey(descuentoCliente.Producto__c)) {
                    Rappel__c rappel = rappelsPorClienteYProducto.get(descuentoCliente.Cliente__c).get(descuentoCliente.Producto__c);
                    porcentajeRappel = rappel.Rappel__c;
                    rappelVigenteEncontrado = true;
                }
            
            // Si se encontró un rappel vigente, se aplica al precio después del descuento
            if (rappelVigenteEncontrado) {
                System.debug('Rappel vigente encontrado: ' + porcentajeRappel + '% para el producto: ' + descuentoCliente.Producto__c);
                precioDespuesDescuento += Integer.valueOf(precioDespuesDescuento * (porcentajeRappel / 100));
                descuentoCliente.Porcentaje_de_Rappel__c = porcentajeRappel; // Guardar el porcentaje en el detalle
            } else {
                System.debug('No se encontró rappel vigente para el producto: ' + descuentoCliente.Producto__c);
            }
            
            // Asignar el precio cliente neto final
            descuentoCliente.Precio_Cliente_Neto__c = precioDespuesDescuento;
            preciosClienteNeto.put(descuentoCliente.Id, descuentoCliente.Precio_Cliente_Neto__c); // Guardar el valor en el mapa
        }
    }
    
}