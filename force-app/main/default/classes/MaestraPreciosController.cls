/**********************************************************************************
Desarrollado por: SEIDOR
Autor: Rodrigo Carvallo (RCG)
Proyecto: Maestra de Precios - Perfomance
Descripción: Clase controladora principal para Maestra de Precios - Gestiona la lógica de negocio y coordinación entre servicios
Test: MaestraPreciosController_Test

---------------------------------------------------------------------------------
No. Fecha                Autor                     Descripción
------ ---------- ---------------------------------------------------------------
1.0 11-09-2025            RCG                Creación de la clase.
**********************************************************************************/
public class MaestraPreciosController {
    public Account acc { get; set; }
    public List<Detalle_Factura__c> comprasMaestradePrecios { get; set; }
    public List<Descuento_Cliente__c> descuentosClienteMaestradePrecios { get; set; }
    public Detalle_Factura__c newComprasMaestraPrecio { get; set; }
    public Descuento_cliente__c newDescuentosMaestraPrecio { get; set; }
    public Map<Id, Decimal> preciosClienteNeto { get; set; }
    public Map<Id, Decimal> precioFinal { get; set; }
    public Map<Id, Decimal> margenProductoMap { get; set; }
    public Map<Id, Decimal> margenContribucionKiloMap { get; set; }
    public Map<Id, Id> pricebookEntriesMap { get; set; }
    public String encabezado { get; set; }
    public Pricebook2 clientePricebook { get; set; }
    public List<PricebookEntry> allPricebookEntries { get; set; }
    public String pageTitle { get; set; }
    public Set<Id> productIds { get; set; }
    public Map<Id, Decimal> costosProductosMap { get; set; }
    public Map<Id, String> errorMargenMap { get; set; }

    /**
    * Constructor principal - Inicializa todos los datos y servicios para la Maestra de Precios
    * @author Rodrigo Carvallo
    * @param ApexPages.StandardController controller - Controlador estándar de la página
    **/
    public MaestraPreciosController(ApexPages.StandardController controller) {
        System.debug('MaestraPreciosController - Controlador - INICIO');
        acc = [SELECT Id, Name, Sucursal__c, Centro_de_Abastecimiento__c FROM Account WHERE Id = :controller.getId() LIMIT 1];
        Id accountId = controller.getId();
        errorMargenMap = new Map<Id, String>();
        costosProductosMap = new Map<Id, Decimal>();
        // Priorizar match con Detalle_Factura: cargar primero compras, luego descuentos solo para productos sin compra
        Set<Id> productosExistentes = new Set<Id>();
        this.comprasMaestradePrecios = ICB_PrecioServiceImpl.getComprasMaestraPrecios(acc.Id, productosExistentes);
        this.descuentosClienteMaestradePrecios = ICB_DescuentoServiceImpl.getDescuentosMaestraPrecios(acc.Id, productosExistentes);
        ICB_CostoServiceImpl.buscarCostosParaProductos(costosProductosMap, comprasMaestradePrecios, descuentosClienteMaestradePrecios);
        this.newComprasMaestraPrecio = new Detalle_Factura__c();
        this.newDescuentosMaestraPrecio = new Descuento_Cliente__c();
        this.preciosClienteNeto = new Map<Id, Decimal>();
        this.precioFinal = new Map<Id, Decimal>();
        this.margenProductoMap = new Map<Id, Decimal>();
        this.margenContribucionKiloMap = new Map<Id, Decimal>();
        this.encabezado = ICB_UtilsServiceImpl.generarEncabezado();
        this.productIds = new Set<Id>();
        
        // Calcular precios y lógica
        clientePricebook = ICB_PricebookServiceImpl.buscarPricebookCliente(acc.Sucursal__c);
        productIds = ICB_ProductServiceImpl.cargarProductIds(comprasMaestradePrecios, descuentosClienteMaestradePrecios);
        allPricebookEntries = ICB_PricebookServiceImpl.cargarTodosLosPricebookEntries(clientePricebook);
        pricebookEntriesMap = ICB_PricebookServiceImpl.cargarPricebookEntries(productIds, descuentosClienteMaestradePrecios, comprasMaestradePrecios, clientePricebook, costosProductosMap);
        ICB_PrecioServiceImpl.calcularPreciosCompras(acc.Sucursal__c, comprasMaestradePrecios);
        ICB_DescuentoServiceImpl.calcularPreciosDescuento(acc.Sucursal__c, descuentosClienteMaestradePrecios);        
        ICB_RecargoServiceImpl.calcularRecargosparaCompras(comprasMaestradePrecios);
        ICB_RecargoServiceImpl.calcularRecargosParaDescuentos(descuentosClienteMaestradePrecios);  
        ICB_RappelServiceImpl.calcularPrecioClienteNetoConRappelCompras(acc.Id, comprasMaestradePrecios, preciosClienteNeto);
        ICB_PrecioServiceImpl.calcularPrecioClienteNetoConRappelDescuentos(descuentosClienteMaestradePrecios, acc.Id, preciosClienteNeto);
        ICB_MargenServiceImpl.calcularMargenPorcentajeCompras(comprasMaestradePrecios, margenProductoMap, costosProductosMap);
        ICB_MargenServiceImpl.calcularMargenPorcentajeDescuento(descuentosClienteMaestradePrecios, costosProductosMap, margenProductoMap);
        ICB_MargenServiceImpl.calcularMargenPorPesoCompras(comprasMaestradePrecios, costosProductosMap, margenContribucionKiloMap);
        ICB_MargenServiceImpl.calcularMargenPorPesoDescuentos(descuentosClienteMaestradePrecios, costosProductosMap, margenContribucionKiloMap);
        ICB_UtilsServiceImpl.formatearFechas(comprasMaestradePrecios);
        pageTitle = ICB_UtilsServiceImpl.generarEncabezado();
        System.debug('MaestraPreciosController - Controlador - FIN');
    }
            
    /**
    * Método para redirigir a la página PaneldeSeteo
    * @author Rodrigo Carvallo
    * @return PageReference - Referencia a la página PaneldeSeteo
    **/
    public PageReference redirectToOtherPage() {
        System.debug('redirectToOtherPage - INICIO');
        // Obtener el Id de la cuenta actual desde los parámetros de la página
        String accountId = ApexPages.currentPage().getParameters().get('id');
        
        // Verificar si el Id de la cuenta no es nulo ni vacío
        if (accountId != null && accountId != '') {
            // Redirigir a la otra página pasando el Id de la cuenta en el URL
            return new PageReference('/apex/PaneldeSeteo?id=' + accountId);
        } else {
            // Manejar el caso donde no hay un Id de cuenta presente
            ApexPages.addMessage(new ApexPages.Message(ApexPages.Severity.ERROR, 'No se encontró la cuenta.'));
            return null;
        }
    }

    /**
    * Método para obtener registros unificados de compras, descuentos y pricebook entries
    * @author Rodrigo Carvallo
    * @param Id accountId - ID del cliente
    * @return List<ICB_RegistroUnificadoWrapper> - Lista de registros unificados
    **/
    @AuraEnabled
    public static List<ICB_RegistroUnificadoWrapper> obtenerRegistrosUnificados(Id accountId) {
        System.debug('obtenerRegistrosUnificados - INICIO');
        
        // Validar que accountId no sea null
        if (accountId == null) {
            System.debug('ERROR: accountId es null.');
            throw new AuraHandledException('No se puede cargar la maestra de precios: El cliente no está definido.');
        }
        
        // Validar que el cliente tenga Sucursal__c definida
        Account acc = [SELECT Id, Name, Sucursal__c FROM Account WHERE Id = :accountId LIMIT 1];
        if (String.isBlank(acc.Sucursal__c)) {
            System.debug('ERROR: El cliente ' + acc.Name + ' (ID: ' + acc.Id + ') no tiene Sucursal__c definida.');
            throw new AuraHandledException('No se puede cargar la maestra de precios: El cliente "' + acc.Name + '" no tiene una Sucursal asignada. Por favor, asigna una Sucursal al cliente antes de continuar.');
        }
        
        MaestraPreciosController instance = new MaestraPreciosController(new ApexPages.StandardController(new Account(Id = accountId)));
        Date today = Date.today();
        Date threeMonthsAgo = today.addMonths(-3);
        Date firstDayThisMonth = Date.newInstance(today.year(), today.month(), 1);
        Date firstDayPreviousMonth = firstDayThisMonth.addMonths(-1);
        Map<Id, Date> productToLastPurchaseDate = ICB_MaestraPreciosRepository.getUltimaFechaCompraPorProducto(accountId, threeMonthsAgo);

        List<ICB_RegistroUnificadoWrapper> registrosUnificados = new List<ICB_RegistroUnificadoWrapper>();
        for (Detalle_Factura__c detalle : instance.comprasMaestradePrecios) {
            Decimal costo = ICB_CostoServiceImpl.obtenerCostoProducto(detalle.Product__c, instance.costosProductosMap);
            ICB_RegistroUnificadoWrapper w = new ICB_RegistroUnificadoWrapper(detalle, costo);
            if (instance.margenProductoMap != null && instance.margenProductoMap.containsKey(detalle.Id)) {
                w.margen = instance.margenProductoMap.get(detalle.Id);
            }
            Date lastPurchase = productToLastPurchaseDate.get(detalle.Product__c);
            w.fugado = (lastPurchase != null && lastPurchase < firstDayPreviousMonth);
            registrosUnificados.add(w);
        }
        for (Descuento_Cliente__c descuento : instance.descuentosClienteMaestradePrecios) {
            // Solo incluir descuentos cuyo producto tenga al menos una compra en los últimos 3 meses
            if (!productToLastPurchaseDate.containsKey(descuento.Producto__c)) continue;
            descuento.Precio_Final__c = ICB_DescuentoServiceImpl.getPrecioFinalDescuento(descuento.Id, instance.descuentosClienteMaestradePrecios);
            Decimal costo = ICB_CostoServiceImpl.obtenerCostoProducto(descuento.Producto__c, instance.costosProductosMap);
            ICB_RegistroUnificadoWrapper w = new ICB_RegistroUnificadoWrapper(descuento, costo);
            Date lastPurchase = productToLastPurchaseDate.get(descuento.Producto__c);
            w.fugado = (lastPurchase != null && lastPurchase < firstDayPreviousMonth);
            registrosUnificados.add(w);
        }

        return registrosUnificados;
    }

    /**
    * Método para crear una Quote con los registros unificados
    * @author Rodrigo Carvallo
    * @param String status - Estado de la quote
    * @param List<ICB_RegistroUnificadoWrapper> registrosUnificados - Lista de registros a incluir
    * @param Id accountId - ID del cliente
    * @param fugadosParaPersistir - Lista de fugados a crear/actualizar (Fugado Sí + no seleccionados + motivo ingresado)
    * @return Quote - Quote creada
    **/
    @AuraEnabled
    public static Quote crearQuote(String status, List<ICB_RegistroUnificadoWrapper> registrosUnificados, Id accountId, List<FugadoParaPersistirWrapper> fugadosParaPersistir){
        System.debug('crearQuote - INICIO');
        Integer EXPIRATION_DATE = 48;
        MaestraPreciosController maestraInstance = new MaestraPreciosController(new ApexPages.StandardController(new Account(Id = accountId)));
        try {
            Quote newQuote = new Quote(
                Name = maestraInstance.acc.Name + ' - ' + String.valueOf(System.today()),
                ClienteId__c = maestraInstance.acc.Id,
                //Status = status,
                ExpirationDate = System.today().addDays(EXPIRATION_DATE),
                Pricebook2Id = ICB_PricebookServiceImpl.getPricebookId(maestraInstance.clientePricebook)
            );
            insert newQuote;   
            
            List<QuoteLineItem> quoteLineItems = new List<QuoteLineItem>();

            for (ICB_RegistroUnificadoWrapper registroUnificado : registrosUnificados) {
                Id currentPricebookEntryId;
                if (registroUnificado.sObjectName == 'PricebookEntry') {
                    currentPricebookEntryId = registroUnificado.id;
                } else {
                    currentPricebookEntryId = ICB_PricebookServiceImpl.getPricebookEntryIdByProductId(registroUnificado.productId, maestraInstance.pricebookEntriesMap);
                }
                if (currentPricebookEntryId != null) {
                    QuoteLineItem qli = new QuoteLineItem(
                        QuoteId = newQuote.Id,
                        PricebookEntryId = currentPricebookEntryId,
                        UnitPrice = registroUnificado.listaPrecio,
                        Quantity = 1,
                        Costo__c = ICB_CostoServiceImpl.obtenerCostoProducto(registroUnificado.productId, maestraInstance.costosProductosMap),
                        SKU__c = registroUnificado.sku,
                        M_Desc_Aut_nomo__c = registroUnificado.descuentoAutonomo,
                        M_Fecha_max_descuento__c = registroUnificado.fechaVencimientoDescuento,
                        Fecha_desde__c = System.today(),
                        Fecha_hasta__c = registroUnificado.fechaVencimientoDescuento,
                        UMV_Panel__c = registroUnificado.umv,
                        M_PrecioListaUni__c = registroUnificado.precioFinal,
                        Discount = registroUnificado.descuento,
                        Rappel__c = registroUnificado.rappel,
                        M_Margen_producto__c = registroUnificado.margen,
                        M_Contribucion_Peso__c = registroUnificado.margenContribucionKilo,
                        M_Precio_Final__c = registroUnificado.precioFinal,
                        DescuentoModificado__c = true
                    );
                    quoteLineItems.add(qli);
                } else {
                    throw new AuraHandledException('No PricebookEntry encontrado para Product2Id en DetalleWrapper: ');
                }
            }
            if (!quoteLineItems.isEmpty()) {
                insert quoteLineItems;
                newQuote.Status = status;
                update newQuote; // Para disparar flow de Quote.
            }

            // Persistir Fugado__c solo para Fugado Sí + no seleccionados + motivo ingresado (fugadosParaPersistir)
            List<Fugado__c> toUpsert = new List<Fugado__c>();
            if (fugadosParaPersistir != null && !fugadosParaPersistir.isEmpty()) {
                Set<Id> productIdsFugados = new Set<Id>();
                for (FugadoParaPersistirWrapper r : fugadosParaPersistir) {
                    if (r.productId != null && String.isNotBlank(r.motivoFuga)) {
                        productIdsFugados.add(r.productId);
                    }
                }
                Map<String, Fugado__c> existingByClienteProducto = new Map<String, Fugado__c>();
                if (!productIdsFugados.isEmpty()) {
                    for (Fugado__c f : [SELECT Id, Cliente__c, Producto__c FROM Fugado__c WHERE Cliente__c = :accountId AND Producto__c IN :productIdsFugados]) {
                        existingByClienteProducto.put(String.valueOf(f.Cliente__c) + '_' + String.valueOf(f.Producto__c), f);
                    }
                }
                // Última compra por producto (Factura.Fecha_de_Documento__c) para Fecha_Sugerencia__c = día 1 del mismo mes, año siguiente
                Map<Id, Date> ultimaCompraPorProducto = ICB_MaestraPreciosRepository.getUltimaFechaCompraPorProducto(accountId, Date.today().addYears(-20));
                Datetime now = Datetime.now();
                for (FugadoParaPersistirWrapper r : fugadosParaPersistir) {
                    if (r.productId == null || String.isBlank(r.motivoFuga)) continue;
                    String key = String.valueOf(accountId) + '_' + String.valueOf(r.productId);
                    Fugado__c f;
                    if (existingByClienteProducto.containsKey(key)) {
                        f = existingByClienteProducto.get(key);
                    } else {
                        f = new Fugado__c(Cliente__c = accountId, Producto__c = r.productId);
                    }
                    f.Motivo__c = r.motivoFuga;
                    f.Comentarios__c = r.comentarioFuga;
                    f.Fecha_Registro__c = now;
                    if (r.motivoFuga == 'Fecha especial') {
                        Date ultimaCompra = ultimaCompraPorProducto != null ? ultimaCompraPorProducto.get(r.productId) : null;
                        if (ultimaCompra != null) {
                            f.Fecha_Sugerencia__c = Date.newInstance(ultimaCompra.year() + 1, ultimaCompra.month(), 1);
                        } else {
                            Date today = Date.today();
                            f.Fecha_Sugerencia__c = Date.newInstance(today.year() + 1, today.month(), 1);
                        }
                    }
                    toUpsert.add(f);
                }
                if (!toUpsert.isEmpty()) {
                    upsert toUpsert;
                }
            }

            return newQuote;
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }

    /**
    * Método para obtener entries de pricebook con paginación y búsqueda
    * @author Rodrigo Carvallo
    * @param Id accountId - ID del cliente
    * @param Integer queryLimit - Límite de registros
    * @param Integer queryOffset - Offset para paginación
    * @param String searchTerm - Término de búsqueda
    * @return List<ICB_RegistroUnificadoWrapper> - Lista de entries de pricebook
    **/
    @AuraEnabled(cacheable=true)
    public static List<ICB_RegistroUnificadoWrapper> fetchPricebookEntries(Id accountId, Integer queryLimit, Integer queryOffset, String searchTerm) {
        System.debug('fetchPricebookEntries - INICIO');
        
        // Validar que accountId no sea null
        if (accountId == null) {
            System.debug('ERROR: accountId es null. No se puede buscar PricebookEntries sin un cliente asociado.');
            throw new AuraHandledException('No se puede cargar productos: La cotización no tiene un cliente asociado.');
        }
        
        // 1. Obtener solo los datos necesarios de Account
        Account acc = ICB_MaestraPreciosRepository.getAccountById(accountId);

        // 2. Usar servicios existentes
        Pricebook2 clientePricebook = ICB_PricebookServiceImpl.buscarPricebookCliente(acc.Sucursal__c);
        String centroAbastecimiento = acc.Centro_de_Abastecimiento__c.substring(0, 4);

        // 3. Query principal optimizada
        String likeSearchTerm = '%' + searchTerm + '%';
        List<PricebookEntry> pricebookEntries = ICB_MaestraPreciosRepository.getPricebookEntries(
            clientePricebook.Id, queryLimit, queryOffset, searchTerm);

        // 4. Query de costos optimizada
        Set<Id> productoIds = new Set<Id>();
        for (PricebookEntry pbe : pricebookEntries) {
            productoIds.add(pbe.Product2Id);
        }

        List<Costo__c> costos = ICB_MaestraPreciosRepository.getCostosByProductos(
            productoIds, centroAbastecimiento);

        // 5. Mapeo costos
        Map<Id, Decimal> costosMap = new Map<Id, Decimal>();
        for (Costo__c costo : costos) {
            costosMap.put(costo.Codigo_del_Producto__c, costo.CostoProducto__c);
        }

        // 6. Construir resultados
        List<ICB_RegistroUnificadoWrapper> resultados = new List<ICB_RegistroUnificadoWrapper>();
        for (PricebookEntry entry : pricebookEntries) {
            Decimal costo = costosMap.get(entry.Product2Id) != null ? costosMap.get(entry.Product2Id) : 0;
            resultados.add(new ICB_RegistroUnificadoWrapper(entry, costo));
        }
        System.debug('fetchPricebookEntries - FIN');
        return resultados;

    }

    /**
    * Método para obtener un entry específico de pricebook por ID
    * @author Rodrigo Carvallo
    * @param Id accountId - ID del cliente
    * @param Id pricebookEntryId - ID del pricebook entry
    * @return List<ICB_RegistroUnificadoWrapper> - Lista con el entry específico
    **/
    @AuraEnabled(cacheable=true)
    public static List<ICB_RegistroUnificadoWrapper> fetchPricebookEntryById(Id accountId, Id pricebookEntryId) {
        System.debug('fetchPricebookEntryById - INICIO');
        MaestraPreciosController instance = new MaestraPreciosController(new ApexPages.StandardController(new Account(Id = accountId)));
        List<PricebookEntry> pricebookEntries = ICB_MaestraPreciosRepository.getPricebookEntryById(
            instance.clientePricebook.Id, pricebookEntryId);

        List<ICB_RegistroUnificadoWrapper> registrosUnificados = new List<ICB_RegistroUnificadoWrapper>();

        if (!pricebookEntries.isEmpty()) {
            for (PricebookEntry entry : pricebookEntries) {
                //entry.Precio_Final__c = instance.getPrecioFinalCompras(entry.Id);
                Decimal costo = ICB_CostoServiceImpl.obtenerCostoProducto(entry.Product2Id, instance.costosProductosMap);
                registrosUnificados.add(new ICB_RegistroUnificadoWrapper(entry, costo));
            }
        }

        return registrosUnificados;
    }

    /**
    * Método para obtener el número total de entries de pricebook
    * @author Rodrigo Carvallo
    * @param Id accountId - ID del cliente
    * @param String searchTerm - Término de búsqueda
    * @return Integer - Número total de entries
    **/
    @AuraEnabled
    public static Integer getTotalNumberOfPricebookEntries(Id accountId, String searchTerm) {
        System.debug('getTotalNumberOfPricebookEntries - INICIO');
        
        // Validar que accountId no sea null
        if (accountId == null) {
            System.debug('ERROR: accountId es null. No se puede buscar PricebookEntries sin un cliente asociado.');
            throw new AuraHandledException('No se puede cargar productos: La cotización no tiene un cliente asociado. Por favor, asocia un cliente a la cotización primero.');
        }
        
        Account acc = ICB_MaestraPreciosRepository.getAccountSucursal(accountId);
        Pricebook2 clientePricebook = ICB_PricebookServiceImpl.buscarPricebookCliente(acc.Sucursal__c);
        return ICB_MaestraPreciosRepository.countPricebookEntries(clientePricebook.Id, searchTerm);
    }

    /**
    * Método para obtener el ID del pricebook asociado al cliente
    * @author Rodrigo Carvallo
    * @param Id accountId - ID del cliente
    * @return Id - ID del pricebook
    **/
    @AuraEnabled
    public static Id getPricebookId(Id accountId){
        System.debug('getPricebookId - INICIO');
        try {
            Account acc = ICB_MaestraPreciosRepository.getAccountFullData(accountId);
            Pricebook2 clientePricebook = ICB_PricebookServiceImpl.buscarPricebookCliente(acc.Sucursal__c);
            return ICB_PricebookServiceImpl.getPricebookId(clientePricebook);
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }

    /**
    * Método para obtener QuoteLineItems de una Quote existente
    * @author Rodrigo Carvallo
    * @param Id quoteId - ID de la Quote
    * @return List<ICB_RegistroUnificadoWrapper> - Lista de QuoteLineItems en formato wrapper
    **/
    @AuraEnabled
    public static List<ICB_RegistroUnificadoWrapper> obtenerQuoteLineItems(Id quoteId) {
        System.debug('obtenerQuoteLineItems - INICIO');
        try {
            List<QuoteLineItem> quoteLineItems = [
                SELECT Id, Product2Id, Product2.Name, Product2.Peso__c, SKU__c, UMV_Panel__c, 
                       UnitPrice, Quantity, Discount, M_PrecioListaUni__c, M_Precio_Final__c,
                       M_Desc_Aut_nomo__c, M_Fecha_max_descuento__c, M_Margen_producto__c,
                       M_Contribucion_Peso__c, Rappel__c, Costo__c, 
                       Fecha_desde__c, Fecha_hasta__c
                FROM QuoteLineItem 
                WHERE QuoteId = :quoteId
                ORDER BY SKU__c ASC
            ];

            List<ICB_RegistroUnificadoWrapper> registrosUnificados = new List<ICB_RegistroUnificadoWrapper>();
            for (QuoteLineItem qli : quoteLineItems) {
                registrosUnificados.add(new ICB_RegistroUnificadoWrapper(qli));
            }

            System.debug('obtenerQuoteLineItems - FIN - Registros: ' + registrosUnificados.size());
            return registrosUnificados;
        } catch (Exception e) {
            System.debug('Error en obtenerQuoteLineItems: ' + e.getMessage());
            throw new AuraHandledException('Error al obtener QuoteLineItems: ' + e.getMessage());
        }
    }

    /**
    * Método para actualizar QuoteLineItems con nuevos descuentos y precios
    * @author Rodrigo Carvallo
    * @param Id quoteId - ID de la Quote
    * @param List<ICB_RegistroUnificadoWrapper> registrosUnificados - Lista de registros actualizados
    * @return String - Mensaje de éxito
    **/
    @AuraEnabled
    public static String actualizarQuoteLineItems(Id quoteId, List<ICB_RegistroUnificadoWrapper> registrosUnificados) {
        System.debug('actualizarQuoteLineItems - INICIO');
        System.debug('QuoteId: ' + quoteId);
        System.debug('Total registros: ' + registrosUnificados.size());
        
        try {
            List<QuoteLineItem> quoteLineItemsToUpdate = new List<QuoteLineItem>();
            List<QuoteLineItem> quoteLineItemsToInsert = new List<QuoteLineItem>();

            // Obtener información de la Quote para el Pricebook
            Quote quote = [SELECT Id, Pricebook2Id, ClienteId__c FROM Quote WHERE Id = :quoteId LIMIT 1];
            
            for (ICB_RegistroUnificadoWrapper registro : registrosUnificados) {
                System.debug('Procesando registro - sObjectName: ' + registro.sObjectName + ', ID: ' + registro.id);
                
                // Verificar si es un PricebookEntry (nuevo producto) o QuoteLineItem (existente)
                if (registro.sObjectName == 'PricebookEntry') {
                    // Es un producto NUEVO que viene del modal "Agregar Productos"
                    System.debug('Creando NUEVO QuoteLineItem para PricebookEntry: ' + registro.id);
                    
                    QuoteLineItem newQli = new QuoteLineItem(
                        QuoteId = quoteId,
                        PricebookEntryId = registro.id, // ID del PricebookEntry
                        Product2Id = registro.productId,
                        UnitPrice = registro.listaPrecio,
                        Quantity = 1,
                        Discount = registro.descuento != null ? registro.descuento : 0,
                        SKU__c = registro.sku,
                        UMV_Panel__c = registro.umv,
                        M_Desc_Aut_nomo__c = registro.descuentoAutonomo,
                        M_Fecha_max_descuento__c = registro.fechaVencimientoDescuento,
                        Fecha_desde__c = registro.fechaDesde != null ? registro.fechaDesde : System.today(),
                        Fecha_hasta__c = registro.fechaVencimientoDescuento,
                        M_Margen_producto__c = registro.margen,
                        M_Contribucion_Peso__c = registro.margenContribucionKilo,
                        M_Precio_Final__c = registro.precioFinal,
                        M_PrecioListaUni__c = registro.listaPrecio,
                        Costo__c = registro.costo,
                        DescuentoModificado__c = true
                    );
                    quoteLineItemsToInsert.add(newQli);
                    
                } else if (registro.sObjectName == 'QuoteLineItem') {
                    // Es un QuoteLineItem EXISTENTE que se está actualizando
                    System.debug('Actualizando QuoteLineItem existente: ' + registro.id);
                    
                    QuoteLineItem qli = new QuoteLineItem(
                        Id = registro.id, // ID del QuoteLineItem existente
                        UnitPrice = registro.precioClienteNeto,
                        Discount = registro.descuento != null ? registro.descuento : 0,
                        M_Margen_producto__c = registro.margen,
                        M_Contribucion_Peso__c = registro.margenContribucionKilo,
                        M_Fecha_max_descuento__c = registro.fechaVencimientoDescuento,
                        Fecha_hasta__c = registro.fechaVencimientoDescuento,
                        M_Precio_Final__c = registro.precioFinal,
                        DescuentoModificado__c = true
                    );
                    quoteLineItemsToUpdate.add(qli);
                }
            }

            Integer totalOperations = 0;
            
            // Insertar nuevos QuoteLineItems
            if (!quoteLineItemsToInsert.isEmpty()) {
                insert quoteLineItemsToInsert;
                totalOperations += quoteLineItemsToInsert.size();
                System.debug('QuoteLineItems INSERTADOS: ' + quoteLineItemsToInsert.size());
            }
            
            // Actualizar QuoteLineItems existentes
            if (!quoteLineItemsToUpdate.isEmpty()) {
                update quoteLineItemsToUpdate;
                totalOperations += quoteLineItemsToUpdate.size();
                System.debug('QuoteLineItems ACTUALIZADOS: ' + quoteLineItemsToUpdate.size());
            }

            System.debug('actualizarQuoteLineItems - FIN - Total operaciones: ' + totalOperations);
            
            if (totalOperations == 0) {
                return 'No hay items para actualizar';
            }
            
            return 'QuoteLineItems guardados exitosamente (' + totalOperations + ' items)';
            
        } catch (Exception e) {
            System.debug('Error en actualizarQuoteLineItems: ' + e.getMessage());
            System.debug('StackTrace: ' + e.getStackTraceString());
            throw new AuraHandledException('Error al guardar QuoteLineItems: ' + e.getMessage());
        }
    }

    /**
    * Método para obtener información de la Quote
    * @author Rodrigo Carvallo
    * @param Id quoteId - ID de la Quote
    * @return Map<String, Object> - Información de la Quote (Name, Account Name, etc.)
    **/
    @AuraEnabled
    public static Map<String, Object> obtenerInfoQuote(Id quoteId) {
        System.debug('obtenerInfoQuote - INICIO - quoteId: ' + quoteId);
        try {
            if (quoteId == null) {
                throw new AuraHandledException('El ID de la Quote no puede ser nulo');
            }

            Quote quote = [
                SELECT Id, Name, ClienteId__c, ClienteId__r.Name, AccountId, Account.Name, 
                       Status, ExpirationDate, Pricebook2Id
                FROM Quote 
                WHERE Id = :quoteId 
                LIMIT 1
            ];

            System.debug('Quote encontrada: ' + quote.Name);
            
            // Usar ClienteId__c si existe, sino usar AccountId estándar como fallback
            Id finalAccountId = quote.ClienteId__c != null ? quote.ClienteId__c : quote.AccountId;
            String finalAccountName = quote.ClienteId__c != null ? quote.ClienteId__r.Name : quote.Account?.Name;
            
            System.debug('ClienteId__c: ' + quote.ClienteId__c);
            System.debug('AccountId: ' + quote.AccountId);
            System.debug('Final AccountId usado: ' + finalAccountId);
            System.debug('Final Account Name: ' + finalAccountName);

            Map<String, Object> quoteInfo = new Map<String, Object>();
            quoteInfo.put('quoteName', quote.Name);
            quoteInfo.put('accountId', finalAccountId);
            quoteInfo.put('accountName', finalAccountName);
            quoteInfo.put('status', quote.Status);
            quoteInfo.put('expirationDate', quote.ExpirationDate);
            quoteInfo.put('pricebookId', quote.Pricebook2Id);

            System.debug('obtenerInfoQuote - FIN - Resultado: ' + quoteInfo);
            return quoteInfo;
        } catch (Exception e) {
            System.debug('ERROR en obtenerInfoQuote: ' + e.getMessage());
            System.debug('StackTrace: ' + e.getStackTraceString());
            throw new AuraHandledException('Error al obtener información de Quote: ' + e.getMessage());
        }
    }

    /**
     * Wrapper para ítem de sugerencia: incluye Id de Fugado__c y registro para el modal.
     */
    public class SugerenciaItemWrapper {
        @AuraEnabled public Id fugadoId;
        @AuraEnabled public ICB_RegistroUnificadoWrapper registro;
    }

    /** Wrapper para persistir Fugado__c: solo Fugado Sí + no seleccionado + motivo ingresado */
    public class FugadoParaPersistirWrapper {
        @AuraEnabled public Id productId { get; set; }
        @AuraEnabled public String motivoFuga { get; set; }
        @AuraEnabled public String comentarioFuga { get; set; }
    }

    /**
     * Obtiene sugerencias para el cliente: Fugado__c con Fecha_Sugerencia__c en el mes/año en curso
     * (ventana: mes anterior, actual y siguiente) y No_Volver_a_Sugerir__c = false.
     * Independiente del Motivo__c: si Fecha_Sugerencia__c coincide con el mes en curso, aparece la sugerencia.
     * Devuelve wrappers tipo PricebookEntry para poder agregar al Panel con el mismo flujo.
     */
    @AuraEnabled
    public static List<SugerenciaItemWrapper> getSugerencias(Id accountId) {
        System.debug('getSugerencias - INICIO - accountId: ' + accountId);
        if (accountId == null) return new List<SugerenciaItemWrapper>();
        Date today = Date.today();
        Date firstDayCurrentMonth = Date.newInstance(today.year(), today.month(), 1);
        Date firstDayPrevMonth = firstDayCurrentMonth.addMonths(-1);
        Date lastDayNextMonth = firstDayCurrentMonth.addMonths(2).addDays(-1);
        List<Fugado__c> fugados = [
            SELECT Id, Producto__c
            FROM Fugado__c
            WHERE Cliente__c = :accountId
            AND (No_Volver_a_Sugerir__c = false OR No_Volver_a_Sugerir__c = null)
            AND Fecha_Sugerencia__c >= :firstDayPrevMonth
            AND Fecha_Sugerencia__c <= :lastDayNextMonth
        ];
        if (fugados.isEmpty()) return new List<SugerenciaItemWrapper>();
        Set<Id> productIds = new Set<Id>();
        Map<Id, Id> productToFugadoId = new Map<Id, Id>();
        for (Fugado__c f : fugados) {
            if (f.Producto__c != null) {
                productIds.add(f.Producto__c);
                productToFugadoId.put(f.Producto__c, f.Id);
            }
        }
        System.debug('productIds: ' + productIds);
        if (productIds.isEmpty()) return new List<SugerenciaItemWrapper>();
        Account acc = ICB_MaestraPreciosRepository.getAccountFullData(accountId);
        Pricebook2 clientePricebook = ICB_PricebookServiceImpl.buscarPricebookCliente(acc.Sucursal__c);
        System.debug('clientePricebook: ' + clientePricebook);
        List<PricebookEntry> entries = [
            SELECT Id, Product2Id, Product2.Name, Product2.Codigo__c, Product2.TextoUMV__c, Product2.Peso__c,
                   Product2.Descuento_Autonomo_de_Asesor__c, Product2.Fecha_maxima_de_descuento__c, UnitPrice
            FROM PricebookEntry
            WHERE Pricebook2Id = :clientePricebook.Id
            AND Product2Id IN :productIds
            AND IsActive = true
        ];
        System.debug('entries: ' + entries);
        Map<Id, Decimal> costosMap = new Map<Id, Decimal>();
        if (!entries.isEmpty()) {
            String centroAbastecimiento = acc.Centro_de_Abastecimiento__c != null && acc.Centro_de_Abastecimiento__c.length() >= 4
                ? acc.Centro_de_Abastecimiento__c.substring(0, 4) : '';
            List<Costo__c> costos = ICB_MaestraPreciosRepository.getCostosByProductos(productIds, centroAbastecimiento);
            for (Costo__c c : costos) costosMap.put(c.Codigo_del_Producto__c, c.CostoProducto__c);
        }
        System.debug('costosMap: ' + costosMap);
        List<SugerenciaItemWrapper> result = new List<SugerenciaItemWrapper>();
        for (PricebookEntry entry : entries) {
            Decimal costo = costosMap.get(entry.Product2Id) != null ? costosMap.get(entry.Product2Id) : 0;
            SugerenciaItemWrapper w = new SugerenciaItemWrapper();
            w.fugadoId = productToFugadoId.get(entry.Product2Id);
            w.registro = new ICB_RegistroUnificadoWrapper(entry, costo);
            result.add(w);
        }

        System.debug('getSugerencias - FIN - result: ' + result);
        return result;
    }

    /**
     * Marca Fugado__c como No_Volver_a_Sugerir__c = true para los IDs indicados.
     */
    @AuraEnabled
    public static void updateNoVolverASugerir(List<Id> fugadoIds) {
        if (fugadoIds == null || fugadoIds.isEmpty()) return;
        List<Fugado__c> toUpdate = new List<Fugado__c>();
        for (Id fid : fugadoIds) {
            toUpdate.add(new Fugado__c(Id = fid, No_Volver_a_Sugerir__c = true));
        }
        update toUpdate;
    }
}