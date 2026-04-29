/**
 * @description       : Contoller for LWC customLookup
**/
 
public without sharing class LookupController {
 
    @AuraEnabled(Cacheable=true)
    public static List<SObject> search(String searchTerm, String myObject, String filter, Map<String, List<String>> fieldValues, Integer offset) {
        String myQuery = null;
        String whereConditions1 = '';
        String whereConditions2 = '';
        Boolean paramAdded = false;
 
        for(String fieldName : fieldValues.keySet()) {
            if(!fieldValues.isEmpty()) {
                if (String.valueOf(fieldValues.get(fieldName)).toLowerCase().contains('select')) {
                    whereConditions2 += (paramAdded ? ' AND ' : '') + fieldName + ' in ' + fieldValues.get(fieldName);
                } else if(fieldValues.get(fieldName).contains('true') || fieldValues.get(fieldName).contains('false')) {
                    whereConditions2 += (paramAdded ? ' AND ' : '') + fieldName + ' = ' + fieldValues.get(fieldName).get(0);
                } else {
                    whereConditions2 += (paramAdded ? ' AND ' : '') + fieldName + ' in (\'' + joinEscaped(fieldValues.get(fieldName), '\',\'') + '\')';
                }
                paramAdded = true;
                filter = whereConditions2;
            }else {
                whereConditions2 += (paramAdded ? ' AND ' : '') + fieldName +  ' = null ';
            }
        }
        if(filter != null && filter != '') {
            if(searchTerm instanceof Id){
                myQuery = 'SELECT Id, Name FROM ' + myObject + ' WHERE Id = \'' + searchTerm + '\' AND ' + whereConditions2 + 'ORDER BY Name ASC LIMIT  5 ' + 'OFFSET ' +offset;
            } else {
                myQuery = 'SELECT Id, Name FROM ' + myObject + ' WHERE Name LIKE  \'%' + searchTerm + '%\' AND ' + whereConditions2 + 'ORDER BY Name ASC LIMIT  5 ' + 'OFFSET ' +offset;
            }
        }else {
            if(searchTerm == null || searchTerm == ''){
                if(searchTerm instanceof Id){
                    myQuery = 'SELECT Id, Name FROM ' + myObject + ' WHERE Id = \'' + searchTerm + '\'';
                }else{
                    myQuery = 'SELECT Id, Name FROM ' + myObject + ' WHERE LastViewedDate != NULL ORDER BY LastViewedDate DESC LIMIT 5 '+ 'OFFSET ' +offset;
                }
            } else {
                myQuery = 'SELECT Id, Name FROM '+myObject+' WHERE Name LIKE  \'%' + searchTerm + '%\'ORDER BY Name ASC LIMIT  5 '+ 'OFFSET ' +offset;
            }
        }
 
        List<SObject> lookUpList = Database.query(myQuery);
        lookUpList.sort();
        return lookUpList;
    }

    private static String joinEscaped(List<String> values, String separator){
        String result='';
        for (Integer i = 0; i < values.size(); ++i){
            result += (i > 0 ? separator : '') + (values[i]!= null ? String.escapeSingleQuotes(values[i]) : 'null');
        }
        return result;
    }
}