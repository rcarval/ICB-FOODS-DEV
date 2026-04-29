/**********************************************************************************
Desarrollado por: SEIDOR
Autor: Rodrigo Carvallo (RCG)
Proyecto: Maestra de Precios - Perfomance
Descripción: Clase wrapper para unificar registros de diferentes objetos en Maestra de Precios

---------------------------------------------------------------------------------
No. Fecha                Autor                     Descripción
------ ---------- ---------------------------------------------------------------
1.0 08-10-2025            RCG                Creación de la clase.
**********************************************************************************/
public class ICB_RegistroUnificadoWrapper {
    @AuraEnabled public String id { get; set; }
        @AuraEnabled public String productId { get; set; }
        @AuraEnabled public String sku { get; set; }
        @AuraEnabled public String umv { get; set; }
        @AuraEnabled public String descripcion { get; set; }
        @AuraEnabled public String sObjectName { get; set; }
        @AuraEnabled public Decimal listaPrecio { get; set; }
        @AuraEnabled public Decimal descuento { get; set; }
        @AuraEnabled public Decimal precioClienteNeto { get; set; }
        @AuraEnabled public Decimal rappel { get; set; }
        @AuraEnabled public Decimal margen { get; set; }
        @AuraEnabled public Decimal descuentoAutonomo { get; set; }
        @AuraEnabled public Decimal margenContribucionKilo { get; set; }
        @AuraEnabled public Decimal precioFinal { get; set; }
        @AuraEnabled public Decimal costo { get; set; }
        @AuraEnabled public Decimal peso { get; set; }
        @AuraEnabled public Boolean tieneCosto { get; set; }
        @AuraEnabled public Date fechaVencimientoDescuento { get; set; }
        @AuraEnabled public Date fechaMaximaOriginal { get; set; } // Atributo usado para comparar fechas al ajustarse la fechaVencimientoDescuento
        @AuraEnabled public Date fechaDesde { get; set; }
        @AuraEnabled public Date fechaHasta { get; set; }
        @AuraEnabled public Boolean fugado { get; set; }
        @AuraEnabled public String motivoFuga { get; set; }
        @AuraEnabled public String comentarioFuga { get; set; }

        public ICB_RegistroUnificadoWrapper() {
            // No initialization needed, this is just for JSON deserialization.
        }

        // Constructor para objetos tipo "Detalle_Factura"
        public ICB_RegistroUnificadoWrapper(Detalle_Factura__c detalle, Decimal costo) {
            this.id = detalle.Id;
            this.productId = detalle.Product__c;
            this.sku = detalle.SKU__c;
            this.umv = detalle.Unidad_de_Medida__c;
            this.descripcion = (detalle.Product__r != null && String.isNotBlank(detalle.Product__r.Name)) ? detalle.Product__r.Name : (detalle.SKU__c != null ? detalle.SKU__c : '—');
            this.listaPrecio = detalle.Valor_Neto__c;
            // Descuento_Cliente__r nunca tuvo valores, establecer descuento = 0
            this.descuento = 0;
            // Precio_Cliente_Neto__c nunca tuvo valor, usar Valor_Neto__c
            this.precioClienteNeto = detalle.Valor_Neto__c != null ? detalle.Valor_Neto__c : 0;
            // Relacion_Rappel_Detalle__r nunca tuvo valores, establecer rappel = 0
            this.rappel = 0;
            // Margen_Producto__c nunca tuvo valor, establecer margen = 0
            this.margen = 0;
            this.descuentoAutonomo = detalle.Product__r.Descuento_Autonomo_de_Asesor__c;
            // Margen_de_Contribucion_por_Kilo__c nunca tuvo valor, establecer = 0
            this.margenContribucionKilo = 0;
            // Descuento_Cliente__r nunca tuvo valores, usar solo Product__r.Fecha_maxima_de_descuento__c
            this.fechaVencimientoDescuento = detalle.Product__r.Fecha_maxima_de_descuento__c;
            this.fechaMaximaOriginal = detalle.Product__r.Fecha_maxima_de_descuento__c;
            // Descuento_Cliente__r nunca tuvo valores, establecer fechaDesde = null
            this.fechaDesde = null;
            // Descuento_Cliente__r nunca tuvo valores, usar fechaVencimientoDescuento o null
            this.fechaHasta = detalle.Product__r.Fecha_maxima_de_descuento__c;
            // Precio_Final__c nunca tuvo valor, usar Valor_Neto__c
            this.precioFinal = detalle.Valor_Neto__c != null ? detalle.Valor_Neto__c : 0;
            // Tiene_Costo__c nunca tuvo valor, calcular basado en costo > 0
            this.tieneCosto = costo != null && costo > 0;
            this.costo = costo;
            this.sObjectName = 'Detalle_Factura__c';
            this.peso = detalle.Product__r.Peso__c;
        }
    
        // Constructor para registros tipo "Descuento"
        public ICB_RegistroUnificadoWrapper(Descuento_Cliente__c descuento, Decimal costo) {
            this.id = descuento.Id;
            this.productId = descuento.Producto__c;
            this.sku = descuento.Producto__r.Codigo__c;
            this.umv = descuento.UMV__c;
            this.descripcion = (descuento.Producto__r != null && String.isNotBlank(descuento.Producto__r.Name)) ? descuento.Producto__r.Name : (descuento.Producto__r != null && descuento.Producto__r.Codigo__c != null ? descuento.Producto__r.Codigo__c : '—');
            this.listaPrecio = descuento.Valor_Neto__c;
            //this.listaCliente = descuento.Precio_Final__c;
            this.descuento = (descuento.Descuento_gestionado__c != null && !descuento.Es_recargo__c)? descuento.Descuento_gestionado__c : 0;
            this.precioClienteNeto = descuento.Precio_Cliente_Neto__c;
            this.rappel = descuento.Relacion_Rappel_Descuento__r.Rappel__c;
            this.margen = descuento.Margen_Producto__c;
            this.descuentoAutonomo = descuento.Producto__r.Descuento_Autonomo_de_Asesor__c;
            this.margenContribucionKilo = descuento.Margen_de_Contribucion_por_Kilo__c;
            this.fechaVencimientoDescuento = descuento.Fecha_Hasta__c != null ? descuento.Fecha_Hasta__c : descuento.Producto__r.Fecha_maxima_de_descuento__c; 
            this.fechaMaximaOriginal = descuento.Fecha_Hasta__c != null ? descuento.Fecha_Hasta__c : descuento.Producto__r.Fecha_maxima_de_descuento__c; 
            this.fechaDesde = descuento.Fecha_desde__c;
            this.fechaHasta = descuento.Fecha_hasta__c;
            this.precioFinal = descuento.Precio_Final__c;
            this.tieneCosto = descuento.Tiene_Costo__c;
            this.costo = costo;
            this.sObjectName = 'Descuento_Cliente__c';
            this.peso = descuento.Producto__r.Peso__c;
        }

        // Constructor para registros tipo "PricebookEntry"
        public ICB_RegistroUnificadoWrapper(PricebookEntry entry, Decimal costo) {
            this.id = entry.Id;
            this.productId = entry.Product2Id;
            this.sku = entry.Product2.Codigo__c;
            this.umv = entry.Product2.TextoUMV__c;
            this.descripcion = entry.Product2.Name;
            this.listaPrecio = entry.UnitPrice;
            this.costo = costo;
            this.peso = entry.Product2.Peso__c;
            this.descuentoAutonomo = entry.Product2.Descuento_Autonomo_de_Asesor__c;
            this.fechaVencimientoDescuento = entry.Product2.Fecha_maxima_de_descuento__c;
            this.fechaMaximaOriginal = entry.Product2.Fecha_maxima_de_descuento__c;
            this.sObjectName = 'PricebookEntry';
            //this.listaCliente = entry.Precio_Final__c;
            //this.entry = entry.entry_gestionado__c != null ? entry.entry_gestionado__c : 0;
            //this.precioClienteNeto = entry.Precio_Cliente_Neto__c;
            //this.rappel = entry.Relacion_Rappel_entry__r.Rappel__c;
            //this.margen = entry.Margen_Producto__c;
            //this.entryAutonomo = entry.Producto__r.entry_Autonomo_de_Asesor__c;
            //this.margenContribucionKilo = entry.Margen_de_Contribucion_por_Kilo__c;
            //this.fechaDesde = entry.Fecha_desde__c;
            //this.fechaHasta = entry.Fecha_hasta__c;
            //this.precioFinal = entry.Precio_Final__c;
            //this.tieneCosto = entry.Tiene_Costo__c;
        }

        // Constructor para registros tipo "QuoteLineItem"
        public ICB_RegistroUnificadoWrapper(QuoteLineItem qli) {
            this.id = qli.Id;
            this.productId = qli.Product2Id;
            this.sku = qli.SKU__c;
            this.umv = qli.UMV_Panel__c;
            this.descripcion = qli.Product2.Name;
            this.listaPrecio = qli.M_PrecioListaUni__c != null ? qli.M_PrecioListaUni__c : qli.UnitPrice;
            this.descuento = qli.Discount != null ? qli.Discount : 0;
            this.precioClienteNeto = qli.UnitPrice;
            this.rappel = qli.Rappel__c;
            this.margen = qli.M_Margen_producto__c;
            this.descuentoAutonomo = qli.M_Desc_Aut_nomo__c;
            this.margenContribucionKilo = qli.M_Contribucion_Peso__c;
            this.fechaVencimientoDescuento = qli.M_Fecha_max_descuento__c;
            this.fechaMaximaOriginal = qli.M_Fecha_max_descuento__c;
            this.fechaDesde = qli.Fecha_desde__c;
            this.fechaHasta = qli.Fecha_hasta__c;
            this.precioFinal = qli.M_Precio_Final__c;
            this.costo = qli.Costo__c;
            this.tieneCosto = qli.Costo__c != null && qli.Costo__c > 0;
            this.sObjectName = 'QuoteLineItem';
            this.peso = qli.Product2.Peso__c;
        }
}