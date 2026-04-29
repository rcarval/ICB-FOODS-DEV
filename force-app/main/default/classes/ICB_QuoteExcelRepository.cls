/**********************************************************************************
Desarrollado por: SEIDOR
Autor: Rodrigo Carvallo (RCG)
Proyecto: Exportación de Quote a Excel
Descripción: Clase repositorio para queries de Quote y QuoteLineItems
Test: ICB_QuoteExcelRepository_Test

---------------------------------------------------------------------------------
No. Fecha                Autor                     Descripción
------ ---------- ---------------------------------------------------------------
1.0 23-10-2025            RCG                Creación de la clase.
**********************************************************************************/
public with sharing class ICB_QuoteExcelRepository {

    /**
    * Método para obtener QuoteLineItems por ID de Quote
    * @author Rodrigo Carvallo
    * @param Id quoteId - ID de la Quote
    * @return List<QuoteLineItem> - Lista de QuoteLineItems
    **/
    public static List<QuoteLineItem> getQuoteLineItemsByQuoteId(Id quoteId) {
        return [
            SELECT Id, Product2.Name, Product2.ProductCode, 
                   Quantity, ListPrice, UnitPrice, Discount, 
                   TotalPrice, Description, ServiceDate
            FROM QuoteLineItem 
            WHERE QuoteId = :quoteId 
            ORDER BY CreatedDate
        ];
    }

    /**
    * Método para obtener Quote por ID
    * @author Rodrigo Carvallo
    * @param Id quoteId - ID de la Quote
    * @return Quote - Objeto Quote
    **/
    public static Quote getQuoteById(Id quoteId) {
        return [
            SELECT Id, Name, QuoteNumber, Account.Name, 
                   Opportunity.Name, GrandTotal, ExpirationDate,
                   Status, CreatedDate
            FROM Quote 
            WHERE Id = :quoteId 
            LIMIT 1
        ];
    }

    /**
    * Método para obtener múltiples Quotes por lista de IDs
    * @author Rodrigo Carvallo
    * @param List<Id> quoteIds - Lista de IDs de Quotes
    * @return List<Quote> - Lista de Quotes
    **/
    public static List<Quote> getQuoteByIdList(List<Id> quoteIds) {
        return [
            SELECT Id, Name, QuoteNumber
            FROM Quote 
            WHERE Id IN :quoteIds
        ];
    }
}