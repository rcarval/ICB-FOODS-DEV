/**********************************************************************************
Desarrollado por: SEIDOR
Autor: Rodrigo Carvallo (RCG)
Proyecto: Maestra de Precios - Perfomance
Descripción: Clase Repository para consultas SOQL de Maestra de Precios
Test: ICB_MaestraPreciosRepository_Test

---------------------------------------------------------------------------------
No. Fecha                Autor                     Descripción
------ ---------- ---------------------------------------------------------------
1.0 08-10-2025            RCG                Creación de la clase.
**********************************************************************************/
public class ICB_MaestraPreciosRepository {
    
    /**
    * Método para obtener datos básicos de Account por ID
    * @author Rodrigo Carvallo
    * @param Id accountId - ID del cliente
    * @return Account - Cuenta con campos necesarios
    **/
    public static Account getAccountById(Id accountId) {
        return [SELECT Id, Name, Sucursal__c, Centro_de_Abastecimiento__c 
                FROM Account 
                WHERE Id = :accountId 
                LIMIT 1];
    }

    /**
    * Método para obtener PricebookEntries con paginación y búsqueda
    * @author Rodrigo Carvallo
    * @param Id pricebookId - ID del pricebook
    * @param Integer queryLimit - Límite de registros
    * @param Integer queryOffset - Offset para paginación
    * @param String searchTerm - Término de búsqueda
    * @return List<PricebookEntry> - Lista de entries de pricebook
    **/
    public static List<PricebookEntry> getPricebookEntries(Id pricebookId, Integer queryLimit, Integer queryOffset, String searchTerm) {
        String likeSearchTerm = '%' + searchTerm + '%';
        
        if (searchTerm != null && searchTerm != '') {
            return [
                SELECT Id, Product2Id, Product2.Codigo__c, Product2.TextoUMV__c, Product2.Name, 
                       UnitPrice, Product2.Peso__c, Product2.Descuento_Autonomo_de_Asesor__c, 
                       Product2.Fecha_maxima_de_descuento__c
                FROM PricebookEntry
                WHERE Pricebook2Id = :pricebookId
                AND IsActive = true 
                AND (Product2.Name LIKE :likeSearchTerm 
                    OR Product2.Codigo__c LIKE :likeSearchTerm 
                    OR Product2.TextoUMV__c LIKE :likeSearchTerm)
                ORDER BY Product2.Name
                LIMIT :queryLimit
                OFFSET :queryOffset
            ];
        } else {
            return [
                SELECT Id, Product2Id, Product2.Codigo__c, Product2.TextoUMV__c, Product2.Name, 
                       UnitPrice, Product2.Peso__c, Product2.Descuento_Autonomo_de_Asesor__c, 
                       Product2.Fecha_maxima_de_descuento__c
                FROM PricebookEntry 
                WHERE Pricebook2Id = :pricebookId
                AND IsActive = true 
                ORDER BY Product2.Name
                LIMIT :queryLimit
                OFFSET :queryOffset
            ];
        }
    }

    /**
    * Método para obtener un PricebookEntry específico por ID
    * @author Rodrigo Carvallo
    * @param Id pricebookId - ID del pricebook
    * @param Id pricebookEntryId - ID del pricebook entry
    * @return List<PricebookEntry> - Lista con el entry específico
    **/
    public static List<PricebookEntry> getPricebookEntryById(Id pricebookId, Id pricebookEntryId) {
        return [
            SELECT Id, Product2Id, Product2.Codigo__c, Product2.TextoUMV__c, Product2.Name, 
                   UnitPrice, Product2.Peso__c, Product2.Descuento_Autonomo_de_Asesor__c, 
                   Product2.Fecha_maxima_de_descuento__c
            FROM PricebookEntry
            WHERE Pricebook2Id = :pricebookId
            AND Id = :pricebookEntryId
            AND IsActive = true 
            ORDER BY Product2.Name
            LIMIT 1
        ];
    }

    /**
    * Método para contar el total de PricebookEntries
    * @author Rodrigo Carvallo
    * @param Id pricebookId - ID del pricebook
    * @param String searchTerm - Término de búsqueda
    * @return Integer - Número total de entries
    **/
    public static Integer countPricebookEntries(Id pricebookId, String searchTerm) {
        String likeSearchTerm = '%' + searchTerm + '%';
        
        if (searchTerm != null && searchTerm != '') {
            return [
                SELECT COUNT() 
                FROM PricebookEntry 
                WHERE Pricebook2Id = :pricebookId
                AND (Product2.Name LIKE :likeSearchTerm 
                    OR Product2.Codigo__c LIKE :likeSearchTerm 
                    OR Product2.TextoUMV__c LIKE :likeSearchTerm)
                AND IsActive = true
            ];
        } else {
            return [
                SELECT COUNT() 
                FROM PricebookEntry 
                WHERE Pricebook2Id = :pricebookId 
                AND IsActive = true
            ];
        }
    }

    /**
    * Método para obtener costos de productos por centro de abastecimiento
    * @author Rodrigo Carvallo
    * @param Set<Id> productoIds - IDs de productos
    * @param String centroAbastecimiento - Centro de abastecimiento
    * @return List<Costo__c> - Lista de costos encontrados
    **/
    public static List<Costo__c> getCostosByProductos(Set<Id> productoIds, String centroAbastecimiento) {
        return [
            SELECT Id, Codigo_del_Producto__c, Centro_de_Abastecimiento__c, CostoProducto__c
            FROM Costo__c
            WHERE Centro_de_Abastecimiento__c = :centroAbastecimiento
            AND Codigo_del_Producto__c IN :productoIds
        ];
    }

    /**
    * Método para obtener datos básicos de Account por ID (versión simplificada)
    * @author Rodrigo Carvallo
    * @param Id accountId - ID del cliente
    * @return Account - Cuenta solo con sucursal
    **/
    public static Account getAccountSucursal(Id accountId) {
        return [SELECT Sucursal__c FROM Account WHERE Id = :accountId LIMIT 1];
    }

    /**
    * Método para obtener datos completos de Account por ID
    * @author Rodrigo Carvallo
    * @param Id accountId - ID del cliente
    * @return Account - Cuenta con todos los campos necesarios
    **/
    public static Account getAccountFullData(Id accountId) {
        return [
            SELECT Id, Sucursal__c, Centro_de_Abastecimiento__c 
            FROM Account 
            WHERE Id = :accountId 
            LIMIT 1
        ];
    }

    /**
    * Método para obtener costos de productos por IDs y centros de abastecimiento
    * @author Rodrigo Carvallo
    * @param Set<Id> productoIds - IDs de productos a buscar
    * @param Set<String> centrosAbastecimiento - Centros de abastecimiento para filtrar
    * @return List<Costo__c> - Lista de costos encontrados
    **/
    public static List<Costo__c> getCostosByProductosAndCentros(Set<Id> productoIds, Set<String> centrosAbastecimiento) {
        return [
            SELECT Codigo_del_Producto__c, Centro_de_Abastecimiento__c, CostoProducto__c
            FROM Costo__c
            WHERE Codigo_del_Producto__c IN :productoIds
            AND Centro_de_Abastecimiento__c IN :centrosAbastecimiento
        ];
    }

    /**
    * Método para obtener rappels vigentes por cliente y fecha
    * @author Rodrigo Carvallo
    * @param Id accountId - ID del cliente
    * @param Date fecha - Fecha para validar vigencia
    * @return List<Rappel__c> - Lista de rappels vigentes
    **/
    public static List<Rappel__c> getRappelsVigentesByCliente(Id accountId, Date fecha) {
        return [
            SELECT Rappel__c, Cliente__c, Product__c, Fecha_Vigencia_Desde__c, Fecha_Vigencia_Hasta__c
            FROM Rappel__c
            WHERE Cliente__c = :accountId
            AND Fecha_Vigencia_Desde__c <= :fecha
            AND Fecha_Vigencia_Hasta__c >= :fecha
        ];
    }

    /**
    * Método para obtener detalles de compras por cliente y fecha
    * @author Rodrigo Carvallo
    * @param Id accountId - ID del cliente
    * @param Date fechaDesde - Fecha desde para filtrar compras
    * @return List<Detalle_Factura__c> - Lista de detalles de compras
    **/
    public static List<Detalle_Factura__c> getDetallesComprasByCliente(Id accountId, Date fechaDesde) {
        return [
            SELECT Id, SKU__c, Unidad_de_Medida__c, Descripcion__c, Valor_Neto__c,
                Product__r.Peso__c, Product__r.Name, Product__r.Descuento_Autonomo_de_Asesor__c, Product__r.Fecha_maxima_de_descuento__c,
                Factura__r.Cliente__c, Factura__r.Fecha_de_Documento__c,
                Product__c,
                Factura__r.Cliente__r.Centro_de_Abastecimiento__c
            FROM Detalle_Factura__c
            WHERE Factura__r.Cliente__c = :accountId
            AND Factura__r.Fecha_de_Documento__c >= :fechaDesde
        ];
    }

    /**
    * Obtiene la última fecha de compra por producto para un cliente en la ventana desde fechaDesde.
    * Usado para calcular si un producto está "fugado" (dejó de comprarse en mes actual y anterior).
    * @param Id accountId - ID del cliente
    * @param Date fechaDesde - Fecha desde (ej. hace 3 meses)
    * @return Map<Id, Date> - Product__c -> última Fecha_de_Documento__c de factura
    **/
    public static Map<Id, Date> getUltimaFechaCompraPorProducto(Id accountId, Date fechaDesde) {
        List<Detalle_Factura__c> detalles = [
            SELECT Product__c, Factura__r.Fecha_de_Documento__c
            FROM Detalle_Factura__c
            WHERE Factura__r.Cliente__c = :accountId
            AND Factura__r.Fecha_de_Documento__c >= :fechaDesde
        ];
        Map<Id, Date> productToLastDate = new Map<Id, Date>();
        for (Detalle_Factura__c d : detalles) {
            if (d.Product__c == null || d.Factura__r == null || d.Factura__r.Fecha_de_Documento__c == null) continue;
            Date fd = d.Factura__r.Fecha_de_Documento__c;
            if (!productToLastDate.containsKey(d.Product__c) || productToLastDate.get(d.Product__c) < fd) {
                productToLastDate.put(d.Product__c, fd);
            }
        }
        return productToLastDate;
    }

    /**
    * Método para obtener precios vigentes por clientes y productos
    * @author Rodrigo Carvallo
    * @param Set<Id> clienteIds - IDs de clientes
    * @param Set<Id> productIds - IDs de productos
    * @param Date fecha - Fecha para validar vigencia
    * @return List<Precios__c> - Lista de precios vigentes
    **/
    public static List<Precios__c> getPreciosVigentesByClientesYProductos(Set<Id> clienteIds, Set<Id> productIds, Date fecha) {
        return [
            SELECT Id, Precio_de_lista__c, Detalle_de_producto__c, Cliente__c
            FROM Precios__c
            WHERE Cliente__c IN :clienteIds
            AND Detalle_de_producto__c IN :productIds
            AND Fecha_Vigencia_Desde__c <= :fecha
            AND Fecha_Vigencia_Hasta__c >= :fecha
        ];
    }

    /**
    * Método para obtener PricebookEntries por pricebook y productos
    * @author Rodrigo Carvallo
    * @param Id pricebookId - ID del pricebook
    * @param Set<Id> productIds - IDs de productos
    * @return List<PricebookEntry> - Lista de entries de pricebook
    **/
    public static List<PricebookEntry> getPricebookEntriesByProductos(Id pricebookId, Set<Id> productIds) {
        return [
            SELECT Product2Id, UnitPrice
            FROM PricebookEntry
            WHERE Pricebook2Id = :pricebookId
            AND Product2Id IN :productIds
        ];
    }

    /**
    * Método para obtener Pricebook por nombre
    * @author Rodrigo Carvallo
    * @param String nombrePricebook - Nombre del pricebook
    * @return Pricebook2 - Pricebook encontrado
    **/
    public static Pricebook2 getPricebookByName(String nombrePricebook) {
        List<Pricebook2> pricebooks = [
            SELECT Id , Name
            FROM Pricebook2 
            WHERE Name = :nombrePricebook 
            LIMIT 1
        ];
        return pricebooks.isEmpty() ? null : pricebooks[0];
    }

    /**
    * Método para obtener descuentos del cliente vigentes
    * @author Rodrigo Carvallo
    * @param Id accountId - ID del cliente
    * @param Date fecha - Fecha para validar vigencia
    * @return List<Descuento_Cliente__c> - Lista de descuentos vigentes
    **/
    public static List<Descuento_Cliente__c> getDescuentosVigentesByCliente(Id accountId, Date fecha) {
        return [
            SELECT Id, Producto__c, Producto__r.Name, Producto__r.Codigo__c, Producto__r.Descuento_Autonomo_de_Asesor__c,
                Cliente__c, Descuento_gestionado__c, Producto__r.UMV__c, Precio_con_Descuento__c, Es_recargo__c, 
                Margen_Producto__c, Margen_de_Contribucion_por_Kilo__c, Fecha_desde__c, Fecha_hasta__c, PrecioId__c, 
                IdPricebookentry__c, Valor_Neto__c, Precio_Final__c, Precio_Cliente_Neto__c, Producto__r.Fecha_maxima_de_descuento__c,
                Porcentaje_de_Rappel__c, Relacion_Rappel_Descuento__r.Rappel__c, Producto__r.Peso__c, UMV__c, 
                Cliente__r.Centro_de_Abastecimiento__c
            FROM Descuento_Cliente__c
            WHERE Cliente__c = :accountId
            AND Fecha_hasta__c >= :fecha
            ORDER BY CreatedDate DESC
        ];
    }

    /**
    * Método para obtener PricebookEntries activos por pricebook y productos
    * @author Rodrigo Carvallo
    * @param Id pricebookId - ID del pricebook
    * @param Set<Id> productIds - IDs de productos
    * @return List<PricebookEntry> - Lista de entries de pricebook activos
    **/
    public static List<PricebookEntry> getPricebookEntriesActivosByProductos(Id pricebookId, Set<Id> productIds) {
        return [
            SELECT Id, Product2Id, IsActive 
            FROM PricebookEntry 
            WHERE Pricebook2Id = :pricebookId 
            AND Product2Id IN :productIds
        ];
    }

    /**
    * Método para obtener todos los PricebookEntries por pricebook
    * @author Rodrigo Carvallo
    * @param Id pricebookId - ID del pricebook
    * @return List<PricebookEntry> - Lista de todos los entries del pricebook
    **/
    public static List<PricebookEntry> getPricebookEntriesByPricebook(Id pricebookId) {
        return [
            SELECT Id, Product2Id 
            FROM PricebookEntry 
            WHERE Pricebook2Id = :pricebookId
        ];
    }

}