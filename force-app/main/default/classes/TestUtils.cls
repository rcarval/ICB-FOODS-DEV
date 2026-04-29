public without sharing class TestUtils {
    public static void makeTestData(){
        Comuna__c comuna = new Comuna__c(
            Name = 'PROVIDENCIA',
            Condici_n_de_expedici_n__c = 'SN',
            Incoterms__c = 'SN',
            Region__c = '13',
            RegionCompleta__c = '13 - Región Metropolitana'
        );
        insert comuna;

        // Generar RUT único y válido (formato xxxxxxxx-x con dígito verificador correcto para icbfs_RutValidator)
        String timestamp = String.valueOf(Datetime.now().getTime());
        Integer randomNum = Integer.valueOf(Math.random() * 9999);
        String rutBase = (timestamp.right(8) + String.valueOf(randomNum).leftPad(4, '0')).left(8);
        Integer cuerpo = Integer.valueOf(rutBase);
        String dv = calcularDvRutChileno(cuerpo);
        String rutUnico = rutBase + '-' + dv;
        
        Account testAccount = new Account(
            Name = 'Test Account ' + timestamp.right(8),
            //Phone = '123-456-7890',
            Sucursal__c = 'S001 - Suc Santiago',
            Centro_de_Abastecimiento__c = 'FS00 - Santiago Maulén',
            RecordTypeId = Schema.SObjectType.Account.getRecordTypeInfosByDeveloperName().get('Negocio').getRecordTypeId(),
            Nombre_de_contacto__c = 'Juan Carlos Del Valle',
            Email__c = 'testaccount' + timestamp.right(8) + '@test.com',
            ShippingStreet = 'Calle Los Leones',
            ShippingCity = 'Temblayork',
            BillingStreet = 'Calle Los Leones',
            BillingCity = 'Temblayork',
            RUT__c = rutUnico,
            Region_Despacho__c = '13 - Región Metropolitana',
            Region__c = '13 - Región Metropolitana',
            Comuna_Facturaci_n__c = comuna.Id,
            Comuna_Despacho__c = comuna.Id
        );
        
        // Intentar insertar, si falla por duplicado, buscar el existente
        try {
            insert testAccount;
        } catch (DmlException e) {
            if (e.getMessage().contains('DUPLICATES_DETECTED')) {
                // Si hay duplicado, buscar el Account existente
                List<Account> existingAccounts = [SELECT Id FROM Account WHERE RUT__c = :rutUnico LIMIT 1];
                if (!existingAccounts.isEmpty()) {
                    testAccount = existingAccounts[0];
                } else {
                    // Si no se encuentra, generar nuevo RUT y reintentar
                    Integer newRandomNum = Integer.valueOf(Math.random() * 9999);
                    String newRutBase = (timestamp.right(8) + String.valueOf(newRandomNum).leftPad(4, '0')).left(8);
                    Integer cuerpoRetry = Integer.valueOf(newRutBase);
                    rutUnico = newRutBase + '-' + calcularDvRutChileno(cuerpoRetry);
                    testAccount.RUT__c = rutUnico;
                    testAccount.Name = 'Test Account ' + timestamp.right(8) + ' ' + String.valueOf(newRandomNum);
                    testAccount.Email__c = 'testaccount' + timestamp.right(8) + String.valueOf(newRandomNum) + '@test.com';
                    insert testAccount;
                }
            } else {
                throw e;
            }
        }

        // Create a Custom Pricebook - El nombre debe ser fijo para que ICB_PricebookServiceImpl lo encuentre
        Pricebook2 customPricebook = new Pricebook2(
            Name = 'Precios S001',
            IsActive = true
        );
        insert customPricebook;
        
        // Crear Categoria con nombre único
        Categoria__c categoria = new Categoria__c(
            Name = 'Categoria Test ' + timestamp,
            Descripcion__c = 'Categoria Test ' + timestamp
        );
        insert categoria;

        // Crear Familia con nombre único
        Familia__c familia = new Familia__c(
            Name = 'FS342 TEST ' + timestamp,
            Descripcion__c = 'FS342 TEST ' + timestamp
        );
        insert familia;

        // Crear UMV
        Unidad_de_Medida__c umv = new Unidad_de_Medida__c(
            Name = 'Unidad de Medida Test ' + String.valueOf(Datetime.now().getTime()).right(6)
            //Name = 'PFTest'
        );
        insert umv;
        System.debug('UMV creada***: ' + umv);

        // Crear Productos
        List<Product2> products = new List<Product2>();
        for (Integer i = 0; i < 30; i++) {
            String codigo = i + '00000000';
            Product2 product = new Product2(
                Name = 'Test Product ' + i,
                IsActive = true,
                Categoria__c = categoria.Id,
                Codigo_Identificador__c = codigo + 'PF',
                Codigo__c = codigo,
                TextoUMV__c = 'PF',
                Descuento_Autonomo_SubGerente__c = 50,
                Descuento_Autonomo_de_Asesor__c = 7.5,
                Descuento_Autonomo_de_Mediocampo__c = 10.5,
                Familia__c = familia.Id,
                Marca__c = 'ACME',
                Peso__c = 350,
                Sub_gerente_de_categoria_responsable__c = 'F8 María de los Ángeles Quiróz',
                Temperatura__c = 'Seco',
                UMV__c = umv.Id,
                Fecha_maxima_de_descuento__c = Date.today().addMonths(1)
            );
            products.add(product);
        }
        insert products;

        // Create Pricebook Entries for both Standard and Custom Pricebooks
        List<PricebookEntry> pricebookEntries = new List<PricebookEntry>();
        List<PricebookEntry> standardPricebookEntries = new List<PricebookEntry>();
            for (Product2 product : products) {
                // Pricebook Entry for Standard Pricebook
                PricebookEntry standardPbe = new PricebookEntry(
                    Pricebook2Id = Test.getStandardPricebookId(),
                    Product2Id = product.Id,
                    UnitPrice = Math.round(Math.random() * 100 + 50), // Random price between 50 and 150
                    IsActive = false
                );
                standardPricebookEntries.add(standardPbe);
        
                // Pricebook Entry for Custom Pricebook
                PricebookEntry customPbe = new PricebookEntry(
                    Pricebook2Id = customPricebook.Id,
                    Product2Id = product.Id,
                    UnitPrice = Math.round(Math.random() * 100 + 50), // Random price between 50 and 150
                    IsActive = true
                );
                pricebookEntries.add(customPbe);
            }
        insert standardPricebookEntries;
        insert pricebookEntries;

        if (!pricebookEntries.isEmpty()) {
            Integer toFlip = Math.min(2, pricebookEntries.size());
            List<PricebookEntry> toUpdate = new List<PricebookEntry>();
            for (Integer j = 0; j < toFlip; j++) {
                PricebookEntry p = pricebookEntries[j];
                p.IsActive = false;
                toUpdate.add(p);
            }
            if (!toUpdate.isEmpty()) {
                update toUpdate;
            }
        }

        // Create Descuento_Cliente__c records
        List<Descuento_Cliente__c> descuentos = new List<Descuento_Cliente__c>();
        for (Integer i = 0; i < 15; i++) {
            Product2 relatedProduct = products[i];
            PricebookEntry relatedPricebookEntry = pricebookEntries[i];

            Descuento_Cliente__c descuento = new Descuento_Cliente__c(
                Es_recargo__c = true,
                Descuento_gestionado__c = 15,
                Fecha_desde__c = Date.today().addDays(-10),
                Fecha_hasta__c = Date.today().addDays(60),
                Producto__c = relatedProduct.Id,
                Cliente__c = testAccount.Id
            );
            descuentos.add(descuento);
        }
        insert descuentos;

        // Create Costo__c records
        List<Costo__c> costos = new List<Costo__c>();
        for (Product2 product : products) {
            Costo__c costo = new Costo__c(
                CostoProducto__c = 500,
                Codigo_del_Producto__c = product.Id,
                Centro_de_Abastecimiento__c = 'FS00',
                TextoUMV__c = product.TextoUMV__c,
                TextoSKU__c = product.Codigo__c
            );
            costos.add(costo);
        }
        insert costos;

        // Create Relacion_Rappel_Detalle__c records
        List<Rappel__c> rappels = new List<Rappel__c>();
        for (Integer i = 0; i < 10; i++) {
            Rappel__c rappelDetalle = new Rappel__c(
                Cliente__c = testAccount.Id,
                Product__c = products[i].Id,
                Rappel__c = 5 + i,
                Fecha_Vigencia_Desde__c = Date.today().addDays(-20),
                Fecha_Vigencia_Hasta__c = Date.today().addDays(20)
            );
            rappels.add(rappelDetalle);
        }
        insert rappels;

        // Crear Domicilio_de_Cliente__c asociado a la cuenta (requerido por validación en Facturas__c)
        Domicilio_de_Cliente__c domicilio = new Domicilio_de_Cliente__c(
            Cliente__c = testAccount.Id,
            Cliente_Despacho__c = 'Calle Los Leones 123',
            Region__c = '13 - Región Metropolitana',
            Comuna_Despacho__c = comuna.Id
        );
        insert domicilio;

        // Crear Facturas__c (el objeto se llama Facturas__c con 's')
        // El campo lookup en Detalle_Factura__c es Factura__c (sin 's') y es MasterDetail (requerido)
        List<SObject> facturas = new List<SObject>();
        Schema.SObjectType facturaType = Schema.getGlobalDescribe().get('Facturas__c');
        if (facturaType != null) {
            for (Integer i = 0; i < 10; i++) {
                SObject factura = facturaType.newSObject();
                factura.put('Cliente__c', testAccount.Id);
                factura.put('Fecha_de_Documento__c', Date.today().addDays(-5));
                factura.put('Domicilio_Cliente__c', domicilio.Id); // Asociar el domicilio creado
                facturas.add(factura);
            }
            insert facturas;
        }

        // Create Detalle_Factura__c records
        // El campo Factura__c es MasterDetail y es requerido
        List<Detalle_Factura__c> detalles = new List<Detalle_Factura__c>();
        for (Integer i = 0; i < 10; i++) {
            Product2 product = products[i];
            Id facturaId = facturas.isEmpty() ? null : (Id)facturas[i].get('Id');
            
            if (facturaId != null) {
                Detalle_Factura__c detalle = new Detalle_Factura__c(
                    SKU__c = product.Codigo__c,
                    Unidad_de_Medida__c = product.TextoUMV__c,
                    Descripcion__c = 'Detalle description ' + i,
                    Valor_Neto__c = 100,
                    Product__c = product.Id,
                    Factura__c = facturaId // Campo MasterDetail requerido
                );
                detalles.add(detalle);
            }
        }
        if (!detalles.isEmpty()) {
            insert detalles;
        }

        // Create Detalle_Factura__c records without Descuento
        List<Detalle_Factura__c> detallesSinDescuento = new List<Detalle_Factura__c>();
        for (Integer i = 15; i < 20; i++) {
            Product2 product = products[i];
            Id facturaId = facturas.isEmpty() ? null : (Id)facturas[Math.mod(i, facturas.size())].get('Id');
            
            if (facturaId != null) {
                Detalle_Factura__c detalle = new Detalle_Factura__c(
                    SKU__c = product.Codigo__c,
                    Unidad_de_Medida__c = product.TextoUMV__c,
                    Descripcion__c = 'Detalle description ' + i,
                    Valor_Neto__c = 100 + i,
                    Product__c = product.Id,
                    Factura__c = facturaId // Campo MasterDetail requerido
                );
                detallesSinDescuento.add(detalle);
            }
        }
        if (!detallesSinDescuento.isEmpty()) {
            insert detallesSinDescuento;
        }
    }

    /**
     * Calcula el dígito verificador de un RUT chileno (módulo 11).
     * Compatible con validación icbfs_RutValidator (formato 7-8 dígitos + guión + 0-9 o K).
     */
    private static String calcularDvRutChileno(Integer cuerpo) {
        Integer sum = 0;
        Integer mul = 2;
        Integer n = cuerpo;
        while (n > 0) {
            Integer dig = Math.mod(n, 10);
            sum += dig * mul;
            mul = (mul == 7) ? 2 : (mul + 1);
            n = n / 10;
        }
        Integer res = 11 - Math.mod(sum, 11);
        if (res == 11) return '0';
        if (res == 10) return 'K';
        return String.valueOf(res);
    }
}