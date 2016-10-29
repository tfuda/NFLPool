trigger Game on Game__c (after insert, after update, after delete, after undelete, before delete) {
    if (Trigger.isBefore && Trigger.isDelete) {
        List<Selection__c> selections = [SELECT Id, Game__c FROM Selection__c WHERE Game__c IN :Trigger.oldMap.keySet()];
        for (Selection__c sel : selections) {
            Game__c g = Trigger.oldMap.get(sel.Game__c);
            Trigger.oldMap.get(sel.Game__c).addError('Unable to delete game with ID: ' + g.Id + ' because it has one or more selections associated with it.');
        }
    }
    // Get a Set containing the week numbers of the games that have been modified
    Set<String> weeks = new Set<String>();
    if (Trigger.isInsert || Trigger.isUpdate || Trigger.isUndelete) {
        for (Game__c game : Trigger.new) {
            weeks.add(game.Week__c);
        }
    } else if (Trigger.isDelete) {
        for (Game__c game : Trigger.old) {
            weeks.add(game.Week__c);
        }
    }

    // Aggregate the total points available, grouped by week.
    AggregateResult[] arList = [SELECT SUM(Points__c) pointsAvailable, COUNT(Id) gameCount, Week__c week
    FROM Game__c WHERE Week__c IN :weeks AND Final__c = true
    GROUP BY Week__c ORDER BY Week__c ASC];
    Map<String, Decimal> totalPointsByWeekNumber = new Map<String, Decimal>();
    Set<String> weeksWithNoGames = new Set<String>();
    if (arList.size() > 0) {
        for (AggregateResult ar : arList) {
            if ((Integer) ar.get('gameCount') > 0) {
                totalPointsByWeekNumber.put((String) ar.get('week'), (Decimal) ar.get('pointsAvailable'));
            } else {
                weeksWithNoGames.add((String) ar.get('week'));
            }
        }
        // If no rows are returned by the aggregate query, then there are no games remaining for the affected weeks.
    } else {
        weeksWithNoGames.addAll(weeks);
    }

    // If we've deleted ALL games for a given week, then delete all Weekly Results objects for that week too
    if (!weeksWithNoGames.isEmpty()) {
        List<Weekly_Result__c> wrList = [SELECT Id FROM Weekly_Result__c WHERE Week__c IN :weeksWithNoGames];
        delete wrList;
    }

    // If there are weeks that we need to update
    if (!totalPointsByWeekNumber.isEmpty()) {

        // Aggregate the total points scored by each player, grouped by week
        arList = [SELECT SUM(Points__c) pointsScored, Player__c pid, Game__r.Week__c week
        FROM Selection__c WHERE Game__r.Week__c IN :totalPointsByWeekNumber.keySet()
        GROUP BY Game__r.Week__c, Player__c
        ORDER BY Game__r.Week__c ASC];

        // Get existing Weekly Results objects for update, map them by week, then player
        Map<String, Map<Id, Weekly_Result__c>> weekMap = new Map<String, Map<Id, Weekly_Result__c>>();
        List<Weekly_Result__c> wrList = [SELECT Id, Player__c, Week__c, Total_Points_Available__c, Total_Points__c
        FROM Weekly_Result__c WHERE Week__c IN :totalPointsByWeekNumber.keySet()];
        for (Weekly_Result__c wr : wrList) {
            Map<Id, Weekly_Result__c> playerMap = weekMap.get(wr.Week__c);
            if (playerMap == null) {
                playerMap = new Map<Id, Weekly_Result__c>();
                weekMap.put(wr.Week__c, playerMap);
            }
            playerMap.put(wr.Player__c, wr);
        }

        // Upsert Weekly Result objects with the values from the Aggregate Query
        wrList = new List<Weekly_Result__c>();
        for (AggregateResult ar : arList) {
            String week = (String) ar.get('week');
            Id pid = (Id) ar.get('pid');
            Decimal pointsScored = (Decimal) ar.get('pointsScored');
            Decimal pointsAvailable = totalPointsByWeekNumber.get(week);

            // If there's an existing Weekly Result for this week/player, then update it, otherwise create one
            Map<Id, Weekly_Result__c> playerMap = weekMap.get(week);
            Weekly_Result__c wr = null;
            if (playerMap != null) {
                wr = playerMap.get(pid);
                if (wr == null) {
                    wr = new Weekly_Result__c(Week__c = week, Player__c = pid);
                }
            } else {
                wr = new Weekly_Result__c(Week__c = week, Player__c = pid);
            }
            wr.Total_Points__c = pointsScored;
            wr.Total_Points_Available__c = pointsAvailable;
            wrList.add(wr);
        }
        upsert wrList;
    }
}