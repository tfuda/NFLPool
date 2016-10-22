trigger Selection on Selection__c (after insert, after update, after delete, after undelete) {
    // Get Sets containing the Ids of the Games, and Players referenced by these selections
    Set<Id> playerIds = new Set<Id>();
    Set<Id> gameIds = new Set<Id>();
    if (Trigger.isInsert || Trigger.isUpdate || Trigger.isUndelete) {
        for (Selection__c selection : Trigger.new) {
            gameIds.add(selection.Game__c);
            playerIds.add(selection.Player__c);
        }
    } else if (Trigger.isDelete) {
        for (Selection__c selection : Trigger.old) {
            gameIds.add(selection.Game__c);
            playerIds.add(selection.Player__c);
        }
    }
    // Run a query to get the weeks of the affected games
    Set<String> weeks = new Set<String>();
    List<Game__c> gameList = [SELECT Id, Week__c FROM Game__c WHERE Id IN :gameIds];
    for (Game__c game : gameList) {
        weeks.add(game.Week__c);
    }

    // Aggregate the total points available, grouped by week.
    AggregateResult[] gameAggrList = [SELECT SUM(Points__c) pointsAvailable, Week__c week
        FROM Game__c WHERE Week__c IN :weeks AND Final__c = true
        GROUP BY Week__c ORDER BY Week__c ASC];
    // Map these by week
    Map<String, AggregateResult> gameAggrMap = new Map<String, AggregateResult>();
    for (AggregateResult gameAggr : gameAggrList) {
        gameAggrMap.put((String) gameAggr.get('week'), gameAggr);
    }

    // Aggregate the total points scored by each player, grouped by week
    AggregateResult[] selectionAggrList = [SELECT SUM(Points__c) pointsScored, Player__c pid, Game__r.Week__c week
        FROM Selection__c WHERE Game__r.Week__c IN :weeks AND Player__c IN :playerIds AND Game__r.Final__c = true
        GROUP BY Game__r.Week__c, Player__c
        ORDER BY Game__r.Week__c ASC];
    // Map these by week, and player Id
    Map<String, Map<Id, AggregateResult>> selectionAggrMap = new Map<String, Map<Id, AggregateResult>>();
    for (AggregateResult selectionAggr : selectionAggrList) {
        String week = (String) selectionAggr.get('week');
        Id pid = (Id) selectionAggr.get('pid');
        Map<Id, AggregateResult> selectionAggrMapForWeek = selectionAggrMap.get(week);
        if (selectionAggrMapForWeek == null) {
            selectionAggrMapForWeek = new Map<Id, AggregateResult>();
            selectionAggrMap.put(week, selectionAggrMapForWeek);
        }
        selectionAggrMapForWeek.put(pid, selectionAggr);
    }

    // Get existing Weekly Result objects for the weeks and players affected by the selection changes
    List<Weekly_Result__c> wrList = [SELECT Id, Week__c, Player__c, Total_Points__c, Total_Points_Available__c, Win_Percentage__c
        FROM Weekly_Result__c WHERE Week__c IN :weeks and Player__c IN :playerIds];
    // Map these by week and player Id too
    Map<String, Map<Id, Weekly_Result__c>> wrMap = new Map<String, Map<Id, Weekly_Result__c>>();
    for (Weekly_Result__c wr : wrList) {
        String week = wr.Week__c;
        Map<Id, Weekly_Result__c> wrMapForWeek = wrMap.get(week);
        if (wrMapForWeek == null) {
            wrMapForWeek = new Map<Id, Weekly_Result__c>();
            wrMap.put(week, wrMapForWeek);
        }
        wrMapForWeek.put(wr.Player__c, wr);
    }

    // Now iterate over the weeks that have modified selections
    List<Weekly_Result__c> wrUpsertList = new List<Weekly_Result__c>();
    for (String week : weeks) {
        // See if there is a Game aggregate for this week
        AggregateResult gameAggr = gameAggrMap.get(week);
        if (gameAggr != null) {

            // If there is, it means there are finalized games for this week.
            Decimal pointsAvailable = (Decimal) gameAggr.get('pointsAvailable');

            // We should insert/update Weekly Results for the players whose selections have changed
            // Get selection aggregates for the week
            Map<Id, AggregateResult> selectionAggrMapForWeek = selectionAggrMap.get(week);
            if (selectionAggrMapForWeek == null) {
                // If there is no section aggregate map for this week, then just create an empty map so we
                // don't get a null reference error when we call .get() on it below
                selectionAggrMapForWeek = new Map<Id, AggregateResult>();
            }

            // Get the Weekly Results for the week
            Map<Id, Weekly_Result__c> wrMapForWeek = wrMap.get(week);
            if (wrMapForWeek == null) {
                // If there is no Weekly Result map for this week, then just create an empty map so we
                // don't get a null reference error when we call .get() on it below
                wrMapForWeek = new Map<Id, Weekly_Result__c>();
            }

            // For each player in the Selection aggregate map for the week
            for (Id pid : selectionAggrMapForWeek.keySet()) {
                // Get the Selection aggregate
                AggregateResult selectionAggr = selectionAggrMapForWeek.get(pid);
                // Get the Weekly Result for this player too
                Weekly_Result__c wr = wrMapForWeek.get(pid);
                if (wr == null) {
                    // If none exists, create one
                    wr = new Weekly_Result__c(Week__c = week, Player__c = pid);
                }
                wr.Total_Points__c = (Decimal) selectionAggr.get('pointsScored');
                wr.Total_Points_Available__c = pointsAvailable;
                wrUpsertList.add(wr);
            }

            // Now find existing Weekly Result objects for which there is no corresponding selection aggregate
            // These are players whose selections have been deleted. We need to set their totals to reflect zeros
            for (Id pid : wrMapForWeek.keySet()) {
                // Get the Weekly Result for this player
                Weekly_Result__c wr = wrMapForWeek.get(pid);
                // Get the Selection aggregate too
                AggregateResult selectionAggr = selectionAggrMapForWeek.get(pid);
                if (selectionAggr == null) {
                    wr.Total_Points__c = 0;
                    wr.Total_Points_Available__c = pointsAvailable;
                    wrUpsertList.add(wr);
                }
            }
        }
    }
    upsert wrUpsertList;
}