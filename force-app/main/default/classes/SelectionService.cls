public with sharing class SelectionService {

    public class GameSelectionWrapper {
        @AuraEnabled public Integer gameNumber { get; set; }
        @AuraEnabled public Game__c game { get; set; }
        @AuraEnabled public Selection__c selection { get; set; }
        @AuraEnabled public Boolean isLocked { get; set; }
        @AuraEnabled public String selectedTeamId { get; set; }
    }

    public class SelectionsResult {
        @AuraEnabled public List<GameSelectionWrapper> gameSelections { get; set; }
        @AuraEnabled public Decimal totalPoints { get; set; }
        @AuraEnabled public Integer numGames { get; set; }
        @AuraEnabled public Integer numSelections { get; set; }
    }

    @AuraEnabled(cacheable=true)
    public static SelectionsResult getSelectionsForPlayerWeek(String playerId, String weekNumber) {
        SelectionsResult result = new SelectionsResult();
        result.gameSelections = new List<GameSelectionWrapper>();
        result.totalPoints = 0;

        List<Game__c> games = [
            SELECT Id, Name, Start_Time__c,
                Home_Team__c, Home_Team__r.Name, Home_Score__c, Spread__c,
                Visiting_Team__c, Visiting_Team__r.Name, Visiting_Score__c,
                Final__c, Winner__c
            FROM Game__c
            WHERE Week__c = :weekNumber
            ORDER BY Start_Time__c, Name ASC
        ];

        Map<Id, Selection__c> selectionsByGame = new Map<Id, Selection__c>();
        if (String.isNotBlank(playerId)) {
            List<Selection__c> selections = [
                SELECT Id, Game__c, Team__c, Team__r.Name, Player__c, Points__c
                FROM Selection__c
                WHERE Player__c = :playerId AND Game__c IN :games
            ];
            for (Selection__c sel : selections) {
                selectionsByGame.put(sel.Game__c, sel);
            }
        }

        Datetime now = Datetime.now();
        Integer numSelections = 0;
        for (Integer i = 0; i < games.size(); i++) {
            Game__c game = games.get(i);
            Selection__c sel = selectionsByGame.get(game.Id);

            GameSelectionWrapper gsw = new GameSelectionWrapper();
            gsw.gameNumber = i + 1;
            gsw.game = game;
            gsw.selection = sel;
            gsw.isLocked = (game.Start_Time__c != null && now > game.Start_Time__c);
            if (sel != null) {
                gsw.selectedTeamId = sel.Team__c;
                if (sel.Points__c != null) {
                    result.totalPoints += sel.Points__c;
                }
                if (sel.Team__c != null) {
                    numSelections++;
                }
            }
            result.gameSelections.add(gsw);
        }

        result.numGames = games.size();
        result.numSelections = numSelections;
        return result;
    }

    @AuraEnabled
    public static void saveSelection(Id gameId, String playerId, Id selectedTeamId, Boolean isAdmin) {
        Game__c game = [SELECT Id, Start_Time__c FROM Game__c WHERE Id = :gameId LIMIT 1];
        Boolean isLocked = (game.Start_Time__c != null && Datetime.now() > game.Start_Time__c);
        if (isLocked && !isAdmin) {
            throw new AuraHandledException('Unable to save selection because the game is locked.');
        }

        List<Selection__c> existing = [
            SELECT Id, Game__c, Player__c, Team__c
            FROM Selection__c
            WHERE Game__c = :gameId AND Player__c = :playerId
            LIMIT 1
        ];

        Selection__c sel;
        if (!existing.isEmpty()) {
            sel = existing[0];
        } else {
            sel = new Selection__c(Game__c = gameId, Player__c = playerId);
        }
        sel.Team__c = selectedTeamId;
        upsert sel;
    }

    @AuraEnabled(cacheable=true)
    public static List<Map<String, String>> getActivePlayers() {
        List<Map<String, String>> playerOptions = new List<Map<String, String>>();
        List<Player__c> players = [
            SELECT Id, Name, User__r.CommunityNickname
            FROM Player__c
            WHERE User__r.IsActive = true
            AND (User__r.Profile.Name = :Constants.PLAYER_PROFILE
                OR User__r.Profile.Name = :Constants.PLAYER_PLATFORM_PROFILE
                OR User__r.Profile.Name = :Constants.POOL_ADMIN_PROFILE)
            ORDER BY Name
        ];
        for (Player__c p : players) {
            playerOptions.add(new Map<String, String>{
                'value' => p.Id,
                'label' => p.Name + ' (' + p.User__r.CommunityNickname + ')'
            });
        }
        return playerOptions;
    }

    @AuraEnabled(cacheable=true)
    public static String getCurrentPlayerIdForUser() {
        String userId = UserInfo.getUserId();
        List<Player__c> players = [
            SELECT Id FROM Player__c WHERE User__c = :userId LIMIT 1
        ];
        if (!players.isEmpty()) {
            return players[0].Id;
        }
        return null;
    }
}
