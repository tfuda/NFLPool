global class PoolManagerUtils {

	/*
	 * Creates a User for a new player using the passed in values. This is done as a web service so that
	 * it can be committed as a separate transaction before creating the Player object for the new Player.
	 */
	webService static String createPlayerUser(String firstname, String lastname, 
		String username, String nickname, String email, String phone,
		String street, String city, String state, String postalcode, 
		String profileid, Boolean isactive) {
		Database.DMLOptions dmo = new Database.DMLOptions();
		dmo.EmailHeader.triggerUserEmail = true;
		
		// Set User fields not required on the input form
		User usr = new User(firstname = firstname, lastname = lastname, username = username,
			communitynickname = nickname, email = email, phone = phone, 
			street = street, city = city, state = state, postalcode = postalcode,
			profileid = profileid, alias = 'player', emailencodingkey = 'UTF-8', 
			languagelocalekey = 'en_US', localesidkey = 'en_US', timezonesidkey = 'America/New_York', 
			receivesadmininfoemails = false, receivesinfoemails = false, isactive = isactive);
		
		// This sends the welcome email
		usr.setOptions(dmo);
		
		insert usr;
		System.debug('Successfully created User: ' + usr);
		return usr.id;
	}
	
	/*
	 * Updates an existing User for a player using the passed in values. This is done as a web service so that
	 * it can be committed as a separate transaction before updating the Player object for the Player.
	 */
	webService static String updatePlayerUser(String id, String firstname, String lastname, 
		String username, String nickname, String email, String phone, 
		String street, String city, String state, String postalcode,
		String profileid, Boolean isactive) {
		
		// Retrieve the User
		User usr = [select id, firstname, lastname, username, communitynickname, 
			email, phone, street, city, state, postalcode, profileid, isactive
			from user where id = :id limit 1];

		// Update the fields
		usr.firstname = firstname;
		usr.lastname = lastname;
		usr.username = username;
		usr.communitynickname = nickname;
		usr.email = email;
		usr.phone = phone;
		usr.street = street;
		usr.city = city;
		usr.state = state;
		usr.postalcode = postalcode;
		usr.profileid = profileid;
		usr.isactive = isactive;
		update usr;
		
		System.debug('Successfully updated User: ' + usr);
		return usr.id;
	}
	
	/* Returns the singleton Settings object */
	private static Settings__c settings;
	public static Settings__c getSettings() {
		if (settings == null) {
			settings = [select usernamesuffix__c, numberofweeks__c, 
				maxgames__c, currentweek__c, entryfee__c 
				from settings__c limit 1];
		}
		return settings;		
	}
}