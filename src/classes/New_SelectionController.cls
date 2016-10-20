public with sharing class New_SelectionController {

	private Settings__c settings = PoolManagerUtils.getSettings();

	public String mode { get; set; }
	
	public String selectedPlayer { get; set; }
	
	public String playerName { 
		get {
			if (selectedPlayer != null) {
				Player__c p = [select p.user__r.communitynickname from player__c p 
					where p.id=:selectedPlayer limit 1];
				return p.user__r.communitynickname;
			} else {
				return null;
			}
		}
	} 
	
	public List<SelectOption> players { 
		get {
			if (players == null) {
				players = new List<SelectOption>();
				players.add(new SelectOption('', '-- None --'));
				List<Player__c> pList = [select p.id, p.name, p.user__c,
					p.user__r.communitynickname, p.user__r.isactive, p.user__r.profile.name
					from player__c p where (p.user__r.isactive = true) 
					and (p.user__r.profile.name = 'Player' 
					or p.user__r.profile.name = 'Pool Administrator') order by p.name];
				for (Player__c p : pList) {
					SelectOption player = new SelectOption(p.id, p.name + ' (' + p.user__r.communitynickname + ')');
					players.add(player);
				}
			}
			return players;
		}
		set;
	}
	
	public String weekNumber { get; set; }
	
	public List<SelectOption> weekNumbers {
		get {
			if (weekNumbers == null) {
				Integer numberOfWeeks = settings.NumberOfWeeks__c.intValue();
				weekNumbers = new List<SelectOption>();
				for (Integer i=1; i <= numberOfWeeks; i++) {
					 weekNumbers.add(new SelectOption(i.format(), i.format()));
				}
			}
			return weekNumbers;
		}
		set;
	}
	
	// Returns true if the current user is an "admin"
	public Boolean isAdmin { 
		get {
			if (isAdmin == null) {
				isAdmin = false;
				List<Profile> adminProfiles = [select id, name from profile 
					where name = 'System Administrator' 
					or name = 'Platform System Admin'
					or name = 'Pool Administrator'];
				for (Profile p : adminProfiles) {
					if (p.id == UserInfo.getProfileId()) {
						isAdmin = true;
					}
				}
			}
			return isAdmin;
		}
		set;
	}

	// List displayed in data table    
	public List<New_GameSelection> gameSelections { get; set; }

	// Total number of points
	public Double totalPoints { get; set; }
	
	public Boolean allLocked {
		get {
			allLocked = true;
			for (New_GameSelection gs : gameSelections) {
				allLocked &= gs.isLocked;	
			}
			return allLocked;
		}
		set;
	}
	
	public Integer selectedGame { get; set; }
	
	public New_SelectionController() {
		
		mode='view';
		selectedPlayer = ApexPages.currentPage().getParameters().get('playerId');
		weekNumber = ApexPages.currentPage().getParameters().get('weekNumber');
		if (selectedPlayer == null) {
			if (!isAdmin) {
				// If not an admin, then just set selected player to the currently logged in 
				// User's corresponding Player object
				String userId = UserInfo.getUserId();
				Player__c p = [select p.id, p.user__c from player__c p where p.user__c = :userId limit 1];
				selectedPlayer = p.id;
			}
		}
		if (weekNumber == null) {
			weekNumber = settings.currentweek__c.format();
		}
		refreshGameSelections(weekNumber, selectedPlayer);
	}
	
	// Action functions
	public PageReference go() {
		mode='view';
		refreshGameSelections(weekNumber, selectedPlayer);
		return null;    	
	}
	
	public PageReference edit() {
		mode='edit';
		return null;
	}
	
	public PageReference privilegedEdit() {
		mode='privileged-edit';
		return null;
	}
	
	public PageReference saveSelection() {
		New_GameSelection gs = gameSelections.get(selectedGame - 1);
		try {
			gs.save(isAdmin);
			ApexPages.addMessage(new ApexPages.Message(ApexPages.Severity.INFO, 
				'Game ' + selectedGame + ' saved successfully.'));
		} catch (SaveException se) {
			ApexPages.addMessage(new ApexPages.Message(ApexPages.Severity.ERROR, 
				'Game ' + selectedGame + ' could not be saved. ' + se.getMessage() + 
				'. Contact the pool administrator(s) to see if they can help.'));
		} catch (Exception ex) {
			ApexPages.addMessage(new ApexPages.Message(ApexPages.Severity.ERROR, 
				'Game ' + selectedGame + ' could not be saved. An unknown error occurred: ' + ex.getMessage() + 
				'. Contact the pool administrator(s) to see if they can help.'));
		}
		refreshGameSelections(weekNumber, selectedPlayer);
		return null;
	}
	
	public PageReference done() {
		mode='view';
		refreshGameSelections(weekNumber, selectedPlayer);
		return null;
	}
	
	/* Refreshes the gameSelections collection and calculates totalPoints in the process */
	public void refreshGameSelections(String weekNumber, String playerId) {
		
		gameSelections = new List<New_GameSelection>();
		totalPoints = 0;
		
		// Get games for the specified week
		List<Game__c> games = [select id, name, start_time__c,
			home_team__r.name, home_score__c, spread__c, 
			visiting_team__r.name, visiting_score__c, final__c, winner__c
			from game__c where week__c = :weekNumber 
			order by start_time__c, name asc];
		
		List<Selection__c> selections;
		if (playerId != null) {
			// Get selections for the specified player
			selections = [select id, game__c, team__c, team__r.Name, player__c, points__c 
				from selection__c where player__c = :playerId and game__c in :games];
		}
		
		// Now map the Selection to the Game ID
		Map<String, Selection__c> gameSelectionMap = new Map<String, Selection__c>();
		if (selections != null) {
			for (Selection__c selection: selections) {
				gameSelectionMap.put(selection.game__c, selection);
				totalPoints += selection.points__c;
			}
		}
		
		// Finally, build a List of <GameSelection> objects
		Integer numGames = games.size();
		Integer numSelections = 0;
		for (Integer i=0; i < games.size(); i++) {
			Game__c game = games.get(i);
			Selection__c selection = gameSelectionMap.get(game.Id);
			if (selection != null && selection.team__c != null) {
				numSelections++;
			}
			New_GameSelection gs = new New_GameSelection(i+1, playerId, game, selection);
			gameSelections.add(gs);
		}
		if (!String.isBlank(selectedPlayer)) {
			ApexPages.addMessage(new ApexPages.Message(
				numSelections < numGames ? ApexPages.Severity.WARNING : ApexPages.Severity.INFO, 
				'' + numSelections + ' of ' + numGames + ' selected.')
			);
		}
	}
}