public with sharing class ResultsService {

    public class Results {
        @AuraEnabled public Decimal pointsAvailable { get; set; }
        @AuraEnabled public List<ResultWrapper> resultRows { get; set; }
    }

    public class ResultWrapper {
        @AuraEnabled public String nickname { get; set; }
        @AuraEnabled public Decimal pointsScored { get; set; }
        @AuraEnabled public Decimal winPercentage { get; set; }

        public ResultWrapper(String nickname, Decimal pointsScored, Decimal winPercentage) {
            this.nickname = nickname;
            this.pointsScored = pointsScored;
            this.winPercentage = winPercentage;
        }
    }

    @AuraEnabled(cacheable=true)
    public static Results getWeeklyResults(String week) {
        AggregateResult[] ar = [
            SELECT SUM(Points__c) pointsAvailable
            FROM Game__c
            WHERE Week__c = :week AND Final__c = true
        ];
        Decimal pointsAvailable = (Decimal) ar[0].get('pointsAvailable');

        List<Weekly_Result__c> wrList = [
            SELECT Id, Name, Week__c, Player__r.Nickname__c,
                Total_Points__c, Total_Points_Available__c, Win_Percentage__c
            FROM Weekly_Result__c
            WHERE Week__c = :week
            ORDER BY Total_Points__c DESC
        ];

        Results r = new Results();
        r.pointsAvailable = pointsAvailable;
        r.resultRows = new List<ResultWrapper>();
        for (Weekly_Result__c wr : wrList) {
            r.resultRows.add(new ResultWrapper(
                wr.Player__r.Nickname__c,
                wr.Total_Points__c,
                wr.Win_Percentage__c
            ));
        }
        return r;
    }

    @AuraEnabled(cacheable=true)
    public static Results getSeasonalResults() {
        AggregateResult[] ar = [
            SELECT SUM(Points__c) pointsAvailable
            FROM Game__c
            WHERE Final__c = true
        ];
        Decimal pointsAvailable = (Decimal) ar[0].get('pointsAvailable');

        List<Player__c> pList = [
            SELECT Id, Nickname__c, Total_Points__c,
                Total_Points_Available__c, Win_Percentage__c
            FROM Player__c
            WHERE User__r.IsActive = true
            ORDER BY Total_Points__c DESC
        ];

        Results r = new Results();
        r.pointsAvailable = pointsAvailable;
        r.resultRows = new List<ResultWrapper>();
        for (Player__c p : pList) {
            r.resultRows.add(new ResultWrapper(
                p.Nickname__c,
                p.Total_Points__c,
                p.Win_Percentage__c
            ));
        }
        return r;
    }
}
