trigger SyncVisibleAndActive on Product2 (before insert, before update) {
    for (Product2 p : Trigger.new) {
        if (p.Visible_For_Sales__c!= p.isActive) {
            p.isActive = p.Visible_For_Sales__c; // Sincroniza Active__c con VisibleForSales__c
        }
    }
}