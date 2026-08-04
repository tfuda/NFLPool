public with sharing class PlayerService {

    public class PlayerDetail {
        @AuraEnabled public User usr { get; set; }
        @AuraEnabled public Player__c player { get; set; }
        @AuraEnabled public List<PlayerPayment__c> payments { get; set; }
    }

    @AuraEnabled(cacheable=true)
    public static PlayerDetail getPlayer(String userId) {
        if (String.isBlank(userId)) {
            userId = UserInfo.getUserId();
        }
        PlayerWrapper pw = PlayerWrapper.getPlayerWrapper(userId);
        PlayerDetail detail = new PlayerDetail();
        detail.usr = pw.usr;
        detail.player = pw.player;
        detail.payments = pw.player != null ? pw.player.Payments__r : new List<PlayerPayment__c>();
        return detail;
    }

    @AuraEnabled(cacheable=true)
    public static List<Map<String, String>> getProfileOptions() {
        List<Map<String, String>> options = new List<Map<String, String>>();
        List<Profile> profiles = [
            SELECT Id, Name FROM Profile
            WHERE Name = :Constants.PLAYER_PROFILE
            OR Name = :Constants.PLAYER_PLATFORM_PROFILE
            OR Name = :Constants.POOL_ADMIN_PROFILE
        ];
        for (Profile p : profiles) {
            options.add(new Map<String, String>{
                'value' => p.Id,
                'label' => p.Name
            });
        }
        return options;
    }

    @AuraEnabled
    public static String createPlayerUser(String firstname, String lastname,
            String username, String nickname, String email, String phone,
            String street, String city, String state, String postalcode,
            String profileId, Boolean isActive) {
        String userId = PoolManagerUtils.createPlayerUser(
            firstname, lastname, username, nickname, email, phone,
            street, city, state, postalcode, profileId, isActive
        );
        createPlayerObject(userId);
        return userId;
    }

    @AuraEnabled
    public static String updatePlayerUser(String userId, String firstname, String lastname,
            String username, String nickname, String email, String phone,
            String street, String city, String state, String postalcode,
            String profileId, Boolean isActive) {
        String resultId = PoolManagerUtils.updatePlayerUser(
            userId, firstname, lastname, username, nickname, email, phone,
            street, city, state, postalcode, profileId, isActive
        );
        List<Player__c> players = [
            SELECT Id FROM Player__c WHERE User__c = :userId LIMIT 1
        ];
        if (!players.isEmpty()) {
            updatePlayerObject(players[0].Id, userId);
        } else {
            createPlayerObject(userId);
        }
        return resultId;
    }

    private static Id createPlayerObject(String userId) {
        User usr = [SELECT Id, Name, Phone, CommunityNickname FROM User WHERE Id = :userId LIMIT 1];
        Player__c p = new Player__c();
        p.Name = usr.Name;
        p.User__c = usr.Id;
        p.Phone__c = usr.Phone;
        p.Nickname__c = usr.CommunityNickname;
        insert p;
        return p.Id;
    }

    private static Id updatePlayerObject(String playerId, String userId) {
        User usr = [
            SELECT Id, Name, Phone, CommunityNickname
            FROM User WHERE Id = :userId LIMIT 1
        ];
        Player__c p = [
            SELECT Id, Name, Phone__c, Nickname__c
            FROM Player__c WHERE Id = :playerId LIMIT 1
        ];
        p.Name = usr.Name;
        p.User__c = usr.Id;
        p.Phone__c = usr.Phone;
        p.Nickname__c = usr.CommunityNickname;
        update p;
        return p.Id;
    }

    @AuraEnabled
    public static PlayerPayment__c savePayment(PlayerPayment__c payment, Decimal balanceDue) {
        if (payment.Amount__c != null && balanceDue != null && payment.Amount__c > balanceDue) {
            throw new AuraHandledException('The payment amount is greater than the balance due.');
        }
        upsert payment;
        return payment;
    }

    @AuraEnabled
    public static void deletePayment(Id paymentId) {
        PlayerPayment__c payment = [SELECT Id FROM PlayerPayment__c WHERE Id = :paymentId LIMIT 1];
        delete payment;
    }

    @AuraEnabled(cacheable=true)
    public static List<PlayerDetail> getPlayerList(Boolean activeOnly) {
        String query = 'SELECT Id, Name, IsActive, Username, Email, Phone, ' +
            'CommunityNickname, Profile.Name ' +
            'FROM User WHERE ' +
            '(Profile.Name = \'' + String.escapeSingleQuotes(Constants.PLAYER_PROFILE) + '\' ' +
            'OR Profile.Name = \'' + String.escapeSingleQuotes(Constants.PLAYER_PLATFORM_PROFILE) + '\' ' +
            'OR Profile.Name = \'' + String.escapeSingleQuotes(Constants.POOL_ADMIN_PROFILE) + '\') ';
        if (activeOnly) {
            query += 'AND IsActive = true ';
        }
        query += 'ORDER BY Name ASC';
        List<User> users = Database.query(query);

        List<Id> userIds = new List<Id>();
        for (User u : users) {
            userIds.add(u.Id);
        }

        Map<Id, Player__c> playersByUserId = new Map<Id, Player__c>();
        for (Player__c p : [
            SELECT Id, Name, User__c, TotalPaymentsRollup__c, BalanceDueFormula__c
            FROM Player__c WHERE User__c IN :userIds
        ]) {
            playersByUserId.put(p.User__c, p);
        }

        List<PlayerDetail> results = new List<PlayerDetail>();
        for (User u : users) {
            PlayerDetail detail = new PlayerDetail();
            detail.usr = u;
            detail.player = playersByUserId.get(u.Id);
            detail.payments = new List<PlayerPayment__c>();
            results.add(detail);
        }
        return results;
    }

    @AuraEnabled
    public static void activateUser(Id userId) {
        User u = [SELECT Id, IsActive FROM User WHERE Id = :userId LIMIT 1];
        u.IsActive = true;
        update u;
    }

    @AuraEnabled
    public static void deactivateUser(Id userId) {
        User u = [SELECT Id, IsActive FROM User WHERE Id = :userId LIMIT 1];
        u.IsActive = false;
        update u;
    }
}
