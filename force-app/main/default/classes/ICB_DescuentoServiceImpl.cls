/**********************************************************************************
Desarrollado por: SEIDOR
Autor: Rodrigo Carvallo (RCG)
Proyecto: Maestra de Precios - Perfomance
Descripción: Clase de servicio para gestión de descuentos en Maestra de Precios
Test: ICB_DescuentoService_Test

---------------------------------------------------------------------------------
No. Fecha                Autor                     Descripción
------ ---------- ---------------------------------------------------------------
1.0 08-10-2025            RCG                Creación de la clase.
**********************************************************************************/
public class ICB_DescuentoServiceImpl{

    /**
    * Método para obtener los descuentos del cliente filtrados por productos existentes
    * @author Rodrigo Carvallo
    * @param Id accountId - ID del cliente
    * @param Set<Id> productosExistentes - Conjunto de IDs de productos ya existentes
    * @return List<Descuento_Cliente__c> - Lista de descuentos vigentes sin duplicados
    **/
    public static List<Descuento_Cliente__c> getDescuentosMaestraPrecios(Id accountId, Set<Id> productosExistentes) {
        Date today = Date.today();
        
        List<Descuento_Cliente__c> descuentos = ICB_MaestraPreciosRepository.getDescuentosVigentesByCliente(accountId, today);
        
        List<Descuento_Cliente__c> descuentosFiltrados = new List<Descuento_Cliente__c>();
        
        // Filtrar duplicados basados en Producto__c
       for (Descuento_Cliente__c descuento : descuentos) {
            if (!productosExistentes.contains(descuento.Producto__c)) {
                descuentosFiltrados.add(descuento);
                productosExistentes.add(descuento.Producto__c);
            }
        }

        //no se eliminan duplicados 
       return descuentosFiltrados;
    }

    /**
    * Método para calcular precios en descuentos considerando pricebooks y precios especiales
    * @author Rodrigo Carvallo
    * @param String sucursal - Sucursal del cliente para identificar pricebook
    * @param List<Descuento_Cliente__c> descuentosClienteMaestradePrecios - Lista de descuentos a procesar
    **/
    public static void calcularPreciosDescuento(String sucursal, List<Descuento_Cliente__c> descuentosClienteMaestradePrecios) {
        // Extraer la  sucursal
        String codigoSucursal = sucursal.split(' ')[0];
        // Construir el nombre de la Pricebook
        String nombrePricebook = 'Precios ' + codigoSucursal;
        
        // Buscar la Pricebook correspondiente
        Pricebook2 clientePricebook = ICB_MaestraPreciosRepository.getPricebookByName(nombrePricebook);
        
        
        if (descuentosClienteMaestradePrecios != null && !descuentosClienteMaestradePrecios.isEmpty()) {
            // Obtener los IDs de todos los productos y clientes
            Set<Id> productIds = new Set<Id>();
            Set<Id> clienteIds = new Set<Id>();
            for (Descuento_Cliente__c descuento : descuentosClienteMaestradePrecios) {
                if (descuento.Producto__c != null) {
                    productIds.add(descuento.Producto__c);
                }
                if (descuento.Cliente__c != null) {
                    clienteIds.add(descuento.Cliente__c);
                }
            }
            
            // Consulta de precios fuera del for
            Map<Id, Map<Id, Precios__c>> preciosPorClienteYProducto = new Map<Id, Map<Id, Precios__c>>();
            List<Precios__c> preciosList = ICB_MaestraPreciosRepository.getPreciosVigentesByClientesYProductos(
                clienteIds, productIds, Date.today());
            
            for (Precios__c precio : preciosList) {
                if (!preciosPorClienteYProducto.containsKey(precio.Cliente__c)) {
                    preciosPorClienteYProducto.put(precio.Cliente__c, new Map<Id, Precios__c>());
                }
                preciosPorClienteYProducto.get(precio.Cliente__c).put(precio.Detalle_de_producto__c, precio);
            }
            
            // Consulta de PricebookEntry fuera del for
            Map<Id, Decimal> pricebookEntriesMap = new Map<Id, Decimal>();
            if (clientePricebook != null) {
                List<PricebookEntry> pbeList = ICB_MaestraPreciosRepository.getPricebookEntriesByProductos(
                    clientePricebook.Id, productIds
                );
                for (PricebookEntry pbe : pbeList) {
                    pricebookEntriesMap.put(pbe.Product2Id, pbe.UnitPrice);
                }
            }
            
            // Procesar descuentos con las consultas previas
            for (Descuento_Cliente__c descuento : descuentosClienteMaestradePrecios) {
                // Inicializa el valor neto a 0 como valor por defecto
                descuento.Valor_Neto__c = 0;
                descuento.Error_Precio__c = '';  // Limpiar cualquier mensaje de error previo
                
                // Verificar si hay un precio en el mapa por cliente y producto
                Boolean precioEncontrado = false;
                if (preciosPorClienteYProducto.containsKey(descuento.Cliente__c) &&
                    preciosPorClienteYProducto.get(descuento.Cliente__c).containsKey(descuento.Producto__c)) {
                        // Asignar el valor del Precio_de_lista__c encontrado en el mapa
                        descuento.Valor_Neto__c = (Integer.valueOf(preciosPorClienteYProducto
                                                                   .get(descuento.Cliente__c)
                                                                   .get(descuento.Producto__c)
                                                                   .Precio_de_lista__c));
                        precioEncontrado = true;
                    } else if (pricebookEntriesMap.containsKey(descuento.Producto__c)) {
                        // Si no se encontró en `Precios__c`, verificar en `PricebookEntry`
                        descuento.Valor_Neto__c = (Integer.valueOf(pricebookEntriesMap.get(descuento.Producto__c)));
                        precioEncontrado = true;
                    }
                
                // Si no se encontró ningún precio, marcar error
                if (!precioEncontrado) {
                    descuento.Valor_Neto__c = 0;
                    descuento.Error_Precio__c = 'No existe precio para este producto';
                }
            }
        } else {
            System.debug('La lista de descuentos está vacía o es nula.');
        }
    }

    /**
    * Método para obtener el precio final de un descuento específico
    * @author Rodrigo Carvallo
    * @param Id descuentoId - ID del descuento a consultar
    * @param List<Descuento_Cliente__c> descuentosClienteMaestradePrecios - Lista donde buscar el descuento
    * @return Decimal - Precio final del descuento o 0 si no se encuentra
    **/
    public static Decimal getPrecioFinalDescuento(Id descuentoId, List<Descuento_Cliente__c> descuentosClienteMaestradePrecios) {
        for (Descuento_Cliente__c descuento : descuentosClienteMaestradePrecios) {
            if (descuento.Id == descuentoId) {
                return descuento.Precio_Final__c != null ? descuento.Precio_Final__c : 0;
            }
        }
        return 0; // Retorna 0 si no se encuentra el registro
    }

}