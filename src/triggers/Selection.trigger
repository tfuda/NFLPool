trigger Selection on Selection__c (after insert, after update, after delete, after undelete) {
    // Get Sets containing the weeks of the Games, and Players referenced by these selections
    Set<String> weeks = new Set<String>();
    Set<Id> players = new Set<Id>();
    if (Trigger.isInsert || Trigger.isUpdate || Trigger.isUndelete) {
        for (Selection__c selection : Trigger.new) {
            weeks.add(selection.Game__r.Week__c);
            players.add(selection.Player__c);
        }
    } else if (Trigger.isDelete) {
        for (Selection__c selection : Trigger.old) {
            weeks.add(selection.Game__r.Week__c);
            players.add(selection.Player__c);
        }
    }

    // Aggregate the total points available, grouped by week.
    AggregateResult[] gameAggr = [SELECT SUM(Points__c) pointsAvailable, Week__c week
        FROM Game__c WHERE Week__c IN :weeks AND Final__c = true
        GROUP BY Week__c ORDER BY Week__c ASC];
    // Map these by week
    Map<String, AggregateResult> gameAggrMap = new Map<String, AggregateResult>();
    for (AggregateResult ar : gameAggr) {
        gameAggrMap.put((String) ar.get('week'), ar);
    }

    // Aggregate the total points scored by each player, grouped by week
    AggregateResult[] selectionAggr = [SELECT SUM(Points__c) pointsScored, Player__c pid, Game__r.Week__c week
        FROM Selection__c WHERE Game__r.Week__c IN :weeks AND Game__r.Final__c = true
        GROUP BY Game__r.Week__c, Player__c
        ORDER BY Game__r.Week__c ASC];
    // Map these by week, and player Id
    Map<String, Map<Id, AggregateResult>> selectionAggrMap = new Map<String, Map<Id, AggregateResult>>();
    for (AggregateResult ar : selectionAggr) {
        String week = (String) ar.get('week');
        Id pid = (Id) ar.get('pid');
        Map<Id, AggregateResult> playerMapForWeek = selectionAggrMap.get(week);
        if (playerMapForWeek == null) {
            playerMapForWeek = new Map<Id, AggregateResult>();
            selectionAggrMap.put(week, playerMapForWeek);
        }
        playerMapForWeek.put(pid, ar);
    }

}