public with sharing class GameService {

    public class GameWrapper {
        @AuraEnabled public Integer gameNumber { get; set; }
        @AuraEnabled public Game__c game { get; set; }
        @AuraEnabled public Boolean isLocked { get; set; }

        public GameWrapper(Integer gameNumber, Game__c game, Boolean isLocked) {
            this.gameNumber = gameNumber;
            this.game = game;
            this.isLocked = isLocked;
        }
    }

    @AuraEnabled(cacheable=true)
    public static List<GameWrapper> getGamesForWeek(String weekNumber) {
        List<Game__c> games = [
            SELECT Id, Name, Week__c, Start_Time__c,
                Home_Team__c, Home_Team__r.Name, Home_Score__c,
                Spread__c,
                Visiting_Team__c, Visiting_Team__r.Name, Visiting_Score__c,
                Final__c, Winner__c
            FROM Game__c
            WHERE Week__c = :weekNumber
            ORDER BY Start_Time__c ASC NULLS LAST
        ];
        Datetime now = Datetime.now();
        List<GameWrapper> wrappers = new List<GameWrapper>();
        for (Integer i = 0; i < games.size(); i++) {
            Game__c g = games.get(i);
            Boolean locked = (g.Start_Time__c != null && now > g.Start_Time__c);
            wrappers.add(new GameWrapper(i + 1, g, locked));
        }
        return wrappers;
    }

    @AuraEnabled
    public static List<GameWrapper> saveGames(List<Game__c> games) {
        List<String> errors = validateGames(games);
        if (!errors.isEmpty()) {
            throw new AuraHandledException(String.join(errors, '\n'));
        }
        upsert games;
        if (!games.isEmpty()) {
            return getGamesForWeek(games[0].Week__c);
        }
        return new List<GameWrapper>();
    }

    @AuraEnabled
    public static List<GameWrapper> deleteGame(Id gameId, String weekNumber) {
        if ([SELECT COUNT() FROM Selection__c WHERE Game__c = :gameId] > 0) {
            throw new AuraHandledException(
                'Unable to delete game because one or more selections reference it. ' +
                'Delete all selections for this game first.'
            );
        }
        Game__c game = [SELECT Id FROM Game__c WHERE Id = :gameId LIMIT 1];
        delete game;
        return getGamesForWeek(weekNumber);
    }

    @AuraEnabled(cacheable=true)
    public static List<Map<String, String>> getTeamOptions() {
        List<Map<String, String>> options = new List<Map<String, String>>();
        List<Team__c> teams = new Selector_Team().selectAll();
        for (Team__c t : teams) {
            options.add(new Map<String, String>{
                'value' => t.Id,
                'label' => t.Short_Name__c
            });
        }
        return options;
    }

    public static List<String> validateGames(List<Game__c> games) {
        List<String> errors = new List<String>();
        Map<Id, String> usedTeams = new Map<Id, String>();

        for (Integer i = 0; i < games.size(); i++) {
            Game__c game = games.get(i);
            Integer gameNum = i + 1;

            if (game.Home_Team__c == null || game.Visiting_Team__c == null) {
                errors.add('Game ' + gameNum + ': You must set both home and visiting team.');
            } else {
                if (usedTeams.containsKey(game.Home_Team__c)) {
                    errors.add('Game ' + gameNum + ': The home team has already been assigned to a previous game.');
                }
                if (usedTeams.containsKey(game.Visiting_Team__c)) {
                    errors.add('Game ' + gameNum + ': The visiting team has already been assigned to a previous game.');
                }
                usedTeams.put(game.Home_Team__c, '');
                usedTeams.put(game.Visiting_Team__c, '');
            }

            if (game.Home_Score__c != null && (game.Home_Score__c < 0 || game.Home_Score__c > 99)) {
                errors.add('Game ' + gameNum + ': Home score must be between 0 and 99.');
            }
            if (game.Visiting_Score__c != null && (game.Visiting_Score__c < 0 || game.Visiting_Score__c > 99)) {
                errors.add('Game ' + gameNum + ': Visiting score must be between 0 and 99.');
            }
            if (game.Spread__c != null && (game.Spread__c < -50 || game.Spread__c > 50)) {
                errors.add('Game ' + gameNum + ': Spread must be between -50 and 50.');
            }
            if (game.Final__c && (game.Home_Score__c == null || game.Visiting_Score__c == null || game.Spread__c == null)) {
                errors.add('Game ' + gameNum + ': To finalize, you must set home score, visiting score, and spread.');
            }
        }
        return errors;
    }
}
