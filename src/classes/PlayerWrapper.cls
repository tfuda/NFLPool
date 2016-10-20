/* Encapsulates a player and his or her corresponding user account */
public with sharing class PlayerWrapper {

    public User usr { get; set; }
    public Player__c player { get; set; }
    
    public PlayerWrapper() {}
    
    public PlayerWrapper(User usr, Player__c player) {
        this.usr = usr;
        this.player = player;
    }
    
    /* Builds and returns the PlayerWrapper for the specified User ID */
    public static PlayerWrapper getPlayerWrapper(String userId) {
    	
    	System.debug('Retrieving User object with ID: ' + userId);
    	
    	// Get the User
    	User usr = [select username, phone, name, lastname, 
    		isactive, id, firstname, email, mobilephone, createddate, 
    		communitynickname, profileid, profile.name, alias, 
    		street, city, state, postalcode
    		from User where id = :userId limit 1];    	
    		
    	System.debug('Retrieve User: ' + usr);
    	
        // Get the Player object that corresponds to the User
        Player__c player = [select p.name, p.id, p.user__c, 
        	p.totalpaymentsrollup__c, p.balancedueformula__c,
        	(select id, createddate, createdbyid, lastmodifieddate, 
        	lastmodifiedbyid, amount__c, paymentdate__c from payments__r) 
        	from player__c p where p.user__c = :usr.id];

		// Create and return the PlayerWrapper object
		PlayerWrapper wrapper = new PlayerWrapper(usr, player);
        return wrapper;     
    }
    
    /* Builds and returns the PlayerWrapper list from the passed in list of User IDs */
    public static List<PlayerWrapper> getPlayerWrapperList(List<Id> userIds) {
    	
        // First, get the Users
        List<User> users = [select username, phone, name, lastname, 
        	isactive, id, firstname, email, mobilephone, createddate, 
        	communitynickname, profileid, profile.name, alias,
			street, city, state, postalcode        	 
        	from User where id in :userIds order by name asc];
            
        // Get the Player objects that correspond to these Users
        List<Player__c> players = [select p.name, p.id, p.user__c,
        	p.totalpaymentsrollup__c, p.balancedueformula__c,
        	(select id, createddate, createdbyid, lastmodifieddate, 
        	lastmodifiedbyid, amount__c	from payments__r) 
        	from player__c p where p.user__c in :userIds];
        
        // Map the Player objects to their corresponding User ids
        Map<id, Player__c> playerMap = new Map<Id, Player__c>();
        for (Player__c p : players) {
            playerMap.put(p.user__c, p);     
        }
        
        // Now for each User, create a PlayerWrapper object and add to the list
        List<PlayerWrapper> playerWrappers = new List<PlayerWrapper>();
        for (User usr : users) {
            PlayerWrapper wrapper = new PlayerWrapper();
            wrapper.usr = usr;
            wrapper.player = playerMap.get(usr.id);
            playerWrappers.add(wrapper);
        }
        return playerWrappers;     
    }
}