/**********************************************************************************
Desarrollado por: SEIDOR
Autor: Rodrigo Carvallo (RCG)
Proyecto: Exportación de Quote a Excel
Descripción: Clase de servicio para generación de archivos Excel desde Quotes
Test: ICB_QuoteExcelService_Test

---------------------------------------------------------------------------------
No. Fecha                Autor                     Descripción
------ ---------- ---------------------------------------------------------------
1.0 23-10-2025            RCG                Creación de la clase.
**********************************************************************************/
public with sharing class ICB_QuoteExcelService {

    /**
    * Método invocable para generar Excel desde Flow/Process Builder
    * @author Rodrigo Carvallo
    * @param List<Id> quoteIds - Lista de IDs de Quotes (Flow pasa como colección)
    * @return List<String> - Lista de IDs de archivos generados
    **/
    @InvocableMethod(label='Generar Excel desde Quote' 
                     description='Genera archivo Excel con QuoteLineItems y lo guarda en Files'
                     category='Quote')
    public static List<String> generateExcelFileFromFlow(List<Id> quoteIds) {
        List<String> fileIds = new List<String>();
        
        for (Id quoteId : quoteIds) {
            try {
                String fileId = generateExcelFile(quoteId);
                fileIds.add(fileId);
            } catch (Exception e) {
                // Log error pero continuar con otros records
                System.debug('Error generando Excel para Quote ' + quoteId + ': ' + e.getMessage());
                fileIds.add('ERROR: ' + e.getMessage());
            }
        }
        
        return fileIds;
    }

    /**
    * Método principal para generar Excel y guardar en Files
    * @author Rodrigo Carvallo
    * @param Id quoteId - ID de la Quote
    * @return String - ID del archivo Excel generado en Files
    **/
    public static String generateExcelFile(Id quoteId) {
        try {
            // Validar permisos antes de proceder
            if (!validateExportPermissions(quoteId)) {
                throw new AuraHandledException('No tiene permisos para exportar esta Quote');
            }
            
            // Obtener datos de la Quote y LineItems
            Quote quoteData = ICB_QuoteExcelRepository.getQuoteById(quoteId);
            List<QuoteLineItem> lineItems = ICB_QuoteExcelRepository.getQuoteLineItemsByQuoteId(quoteId);
            
            if (lineItems.isEmpty()) {
                throw new AuraHandledException('La Quote no tiene productos asociados');
            }
            
            // Generar contenido Excel
            String excelContent = generateExcelContent(quoteData, lineItems);
            
            // Crear y guardar archivo en Files
            String fileId = saveExcelToFiles(quoteData, excelContent);
            
            return fileId;
            
        } catch (Exception e) {
            throw new AuraHandledException('Error generando archivo Excel: ' + e.getMessage());
        }
    }

    /**
    * Método para generar el contenido del archivo Excel en formato XML Excel
    * @author Rodrigo Carvallo
    * @param Quote quoteData - Objeto Quote
    * @param List<QuoteLineItem> lineItems - Lista de QuoteLineItems
    * @return String - Contenido del archivo Excel en formato XML
    **/
    private static String generateExcelContent(Quote quoteData, List<QuoteLineItem> lineItems) {
        String xmlContent = '';
        
        // Inicio del documento Excel XML
        xmlContent += '<?xml version="1.0" encoding="UTF-8"?>\n';
        xmlContent += '<Workbook xmlns="urn:schemas-microsoft-com:office:spreadsheet"\n';
        xmlContent += ' xmlns:o="urn:schemas-microsoft-com:office:office"\n';
        xmlContent += ' xmlns:x="urn:schemas-microsoft-com:office:excel"\n';
        xmlContent += ' xmlns:ss="urn:schemas-microsoft-com:office:spreadsheet"\n';
        xmlContent += ' xmlns:html="http://www.w3.org/TR/REC-html40">\n';
        
        // Estilos
        xmlContent += '<Styles>\n';
        xmlContent += '<Style ss:ID="Header">\n';
        xmlContent += '<Font ss:Bold="1"/>\n';
        xmlContent += '<Interior ss:Color="#D3D3D3" ss:Pattern="Solid"/>\n';
        xmlContent += '<Borders>\n';
        xmlContent += '<Border ss:Position="Bottom" ss:LineStyle="Continuous" ss:Weight="1"/>\n';
        xmlContent += '<Border ss:Position="Left" ss:LineStyle="Continuous" ss:Weight="1"/>\n';
        xmlContent += '<Border ss:Position="Right" ss:LineStyle="Continuous" ss:Weight="1"/>\n';
        xmlContent += '<Border ss:Position="Top" ss:LineStyle="Continuous" ss:Weight="1"/>\n';
        xmlContent += '</Borders>\n';
        xmlContent += '</Style>\n';
        xmlContent += '<Style ss:ID="Data">\n';
        xmlContent += '<Borders>\n';
        xmlContent += '<Border ss:Position="Bottom" ss:LineStyle="Continuous" ss:Weight="1"/>\n';
        xmlContent += '<Border ss:Position="Left" ss:LineStyle="Continuous" ss:Weight="1"/>\n';
        xmlContent += '<Border ss:Position="Right" ss:LineStyle="Continuous" ss:Weight="1"/>\n';
        xmlContent += '<Border ss:Position="Top" ss:LineStyle="Continuous" ss:Weight="1"/>\n';
        xmlContent += '</Borders>\n';
        xmlContent += '</Style>\n';
        xmlContent += '</Styles>\n';
        
        // Hoja de trabajo
        xmlContent += '<Worksheet ss:Name="Cotización">\n';
        xmlContent += '<Table>\n';
        
        // Definir ancho de columnas
        xmlContent += '<Column ss:Index="1" ss:Width="300"/>\n'; // Producto
        xmlContent += '<Column ss:Index="2" ss:Width="100"/>\n'; // Código Producto
        xmlContent += '<Column ss:Index="3" ss:Width="60"/>\n';  // Cantidad
        xmlContent += '<Column ss:Index="4" ss:Width="100"/>\n'; // Precio Unitario
        xmlContent += '<Column ss:Index="5" ss:Width="100"/>\n'; // Precio Lista
        xmlContent += '<Column ss:Index="6" ss:Width="90"/>\n';  // Descuento (%)
        xmlContent += '<Column ss:Index="7" ss:Width="100"/>\n'; // Precio Total
        xmlContent += '<Column ss:Index="8" ss:Width="300"/>\n'; // Descripción
        xmlContent += '<Column ss:Index="9" ss:Width="120"/>\n'; // Fecha Servicio
        
        // Header de la tabla
        xmlContent += '<Row>\n';
        xmlContent += '<Cell ss:StyleID="Header"><Data ss:Type="String">Producto</Data></Cell>\n';
        xmlContent += '<Cell ss:StyleID="Header"><Data ss:Type="String">Código Producto</Data></Cell>\n';
        xmlContent += '<Cell ss:StyleID="Header"><Data ss:Type="String">Cantidad</Data></Cell>\n';
        xmlContent += '<Cell ss:StyleID="Header"><Data ss:Type="String">Precio Unitario</Data></Cell>\n';
        xmlContent += '<Cell ss:StyleID="Header"><Data ss:Type="String">Precio Lista</Data></Cell>\n';
        xmlContent += '<Cell ss:StyleID="Header"><Data ss:Type="String">Descuento (%)</Data></Cell>\n';
        xmlContent += '<Cell ss:StyleID="Header"><Data ss:Type="String">Precio Total</Data></Cell>\n';
        xmlContent += '<Cell ss:StyleID="Header"><Data ss:Type="String">Descripción</Data></Cell>\n';
        xmlContent += '<Cell ss:StyleID="Header"><Data ss:Type="String">Fecha Servicio</Data></Cell>\n';
        xmlContent += '</Row>\n';
        
        // Datos de los productos
        for (QuoteLineItem item : lineItems) {
            String productName = item.Product2?.Name != null ? escapeXml(item.Product2.Name) : '';
            String productCode = item.Product2?.ProductCode != null ? escapeXml(item.Product2.ProductCode) : '';
            String quantity = item.Quantity != null ? String.valueOf(item.Quantity) : '0';
            String unitPrice = item.UnitPrice != null ? String.valueOf(item.UnitPrice) : '0';
            String listPrice = item.ListPrice != null ? String.valueOf(item.ListPrice) : '0';
            String discount = item.Discount != null ? String.valueOf(item.Discount) : '0';
            String totalPrice = item.TotalPrice != null ? String.valueOf(item.TotalPrice) : '0';
            String description = item.Description != null ? escapeXml(item.Description) : '';
            String serviceDate = item.ServiceDate != null ? String.valueOf(item.ServiceDate) : '';
            
            xmlContent += '<Row>\n';
            xmlContent += '<Cell ss:StyleID="Data"><Data ss:Type="String">' + productName + '</Data></Cell>\n';
            xmlContent += '<Cell ss:StyleID="Data"><Data ss:Type="String">' + productCode + '</Data></Cell>\n';
            xmlContent += '<Cell ss:StyleID="Data"><Data ss:Type="Number">' + quantity + '</Data></Cell>\n';
            xmlContent += '<Cell ss:StyleID="Data"><Data ss:Type="Number">' + unitPrice + '</Data></Cell>\n';
            xmlContent += '<Cell ss:StyleID="Data"><Data ss:Type="Number">' + listPrice + '</Data></Cell>\n';
            xmlContent += '<Cell ss:StyleID="Data"><Data ss:Type="Number">' + discount + '</Data></Cell>\n';
            xmlContent += '<Cell ss:StyleID="Data"><Data ss:Type="Number">' + totalPrice + '</Data></Cell>\n';
            xmlContent += '<Cell ss:StyleID="Data"><Data ss:Type="String">' + description + '</Data></Cell>\n';
            xmlContent += '<Cell ss:StyleID="Data"><Data ss:Type="String">' + serviceDate + '</Data></Cell>\n';
            xmlContent += '</Row>\n';
        }
        
        xmlContent += '</Table>\n';
        xmlContent += '</Worksheet>\n';
        xmlContent += '</Workbook>';
        
        return xmlContent;
    }
    
    /**
    * Método para escapar caracteres XML
    * @author Rodrigo Carvallo
    * @param String input - Texto a escapar
    * @return String - Texto escapado
    **/
    private static String escapeXml(String input) {
        if (input == null) return '';
        return input.replace('&', '&amp;')
                   .replace('<', '&lt;')
                   .replace('>', '&gt;')
                   .replace('"', '&quot;')
                   .replace('\'', '&apos;');
    }
    

    /**
    * Método para guardar el archivo Excel en Salesforce Files
    * @author Rodrigo Carvallo
    * @param Quote quoteData - Objeto Quote
    * @param String excelContent - Contenido del archivo Excel
    * @return String - ID del archivo creado
    **/
    private static String saveExcelToFiles(Quote quoteData, String excelContent) {
        try {
            // Crear ContentVersion (Files)
            ContentVersion contentVersion = new ContentVersion();
            contentVersion.Title = 'Cotización_' + quoteData.QuoteNumber + '_' + Datetime.now().format('yyyy-MM-dd_HHmmss') + '.xls';
            contentVersion.PathOnClient = contentVersion.Title;
            
            // Convertir el contenido XML Excel a Blob con encoding UTF-8
            Blob excelBlob = Blob.valueOf(excelContent);
            contentVersion.VersionData = excelBlob;
            contentVersion.FirstPublishLocationId = quoteData.Id; // Relacionar directamente con la Quote
            
            insert contentVersion;
            
            // Obtener el ContentDocumentId para retornar
            contentVersion = [SELECT ContentDocumentId FROM ContentVersion WHERE Id = :contentVersion.Id];
            
            return contentVersion.ContentDocumentId;
            
        } catch (Exception e) {
            throw new AuraHandledException('Error guardando archivo Excel: ' + e.getMessage());
        }
    }

    /**
    * Método para validar permisos de exportación
    * @author Rodrigo Carvallo
    * @param Id quoteId - ID de la Quote
    * @return Boolean - True si tiene permisos, False si no
    **/
    private static Boolean validateExportPermissions(Id quoteId) {
        try {
            // Verificar acceso a objetos
            if (!Schema.sObjectType.Quote.isAccessible() || 
                !Schema.sObjectType.QuoteLineItem.isAccessible() ||
                !Schema.sObjectType.ContentVersion.isCreateable()) {
                return false;
            }
            
            // Verificar que el usuario tenga acceso a esta Quote específica
            List<Quote> accessibleQuotes = ICB_QuoteExcelRepository.getQuoteByIdList(new List<Id>{quoteId});
            return !accessibleQuotes.isEmpty();
            
        } catch (Exception e) {
            System.debug('Error validando permisos: ' + e.getMessage());
            return false;
        }
    }
}