public with sharing class SoslInvocableMethod {

    @InvocableMethod
    public static List<Result> execute(List<Request> requestList) {
        List<Result> response = new List<Result>();

        for (Request req : requestList) {
            
            // 1. Sanitize, Escape, and Quote each individual query term
            List<String> formattedQueries = new List<String>();
            
            // Handle edge case where queries list might be null
            if(req.queries != null) {
                for (String query : req.queries) {
                    if (String.isNotBlank(query)) {
                        String escaped = escapeSoslReservedChars(query);
                        escaped = String.escapeSingleQuotes(escaped);
                        // Wrap the individual term in quotes so logical operators work between them
                        formattedQueries.add('\'' + escaped + '\''); 
                    }
                }
            }

            // 2. Join them with the OR operator
            // Result looks like: 'Term1' OR 'Term2'
            String queryString = String.join(formattedQueries, ' OR ');

            // 3. Build SOSL
            // Result looks like: FIND {'Term1' OR 'Term2'} ...
            String sosl = String.format('FIND {0}{1} RETURNING {2}(Id{3})', new String[]{
                queryString,
                String.isNotBlank(req.scope) ? ' IN ' + req.scope : '',
                req.objectAPIName,
                String.isNotBlank(req.whereClause) ? ' WHERE ' + req.whereClause : ''
            });

            System.debug('### SoslInvocableMethod execute sosl >>>' + sosl);

            // 4. Execute Search
            Search.SearchResults searchResults = Search.find(sosl);
            List<Search.SearchResult> recordList = searchResults.get(req.objectAPIName);

            Result res = new Result();
            res.recordIds = new List<Id>();
            for (Search.SearchResult searchResult : recordList) {
                SObject record = searchResult.getSObject();
                res.recordIds.add(record.Id);
            } 

            response.add(res);
        }

        return response;
    }

    @TestVisible
    private static String escapeSoslReservedChars(String input) {
        if (String.isBlank(input)) {
            return input;
        } 
        return input
            .replace('\\', '\\\\')
            .replace('?', '\\?')
            .replace('*', '\\*')
            .replace('&', '\\&')
            .replace('|', '\\|')
            .replace('!', '\\!')
            .replace('{', '\\{')
            .replace('}', '\\}')
            .replace('[', '\\[')
            .replace(']', '\\]')
            .replace('(', '\\(')
            .replace(')', '\\)')
            .replace(':', '\\:')
            .replace('^', '\\^')
            .replace('~', '\\~')
            .replace('"', '\\"');
    }

    public class Request {
        @InvocableVariable(label='SObjectType' required=true)
        public String objectAPIName;
        @InvocableVariable(label='Queries' required=true)
        public List<String> queries;
        @InvocableVariable(label='Scope')
        public String scope;
        @InvocableVariable(label='Where Clause')
        public String whereClause;
    }

    public class Result {
        @InvocableVariable(label='Record Ids')
        public List<Id> recordIds;
    }
}