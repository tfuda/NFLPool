public with sharing class GamesController {
	
	public String mode { get; set; }
	public String deleteButtonId { get; set; }
	public String weekNumber { get; set; }
	public List<GameWrapper> gameList { get; set; }
	public Integer gameCount {
		get {
			return gameList.size();
		}
	}
	
	public List<String> weekNumbers {
		get {
			if (weekNumbers == null) {
				Integer numberOfWeeks = settings.NumberOfWeeks__c.intValue();
				weekNumbers = new List<String>();
				for (Integer i = 1; i <= numberOfWeeks; i++) {
					weekNumbers.add(i.format());
				}
			}
			return weekNumbers;
		}
		set;
	}
	
	public String numGamesToAdd {
		get {
			if (numGamesToAdd == null) {
				numGamesToAdd = '1';
			}
			return numGamesToAdd;
		}
		set;
	}
	
	public List<SelectOption> numGameOptions {
		get {
			List<SelectOption> numGameOptions = new List<SelectOption>();
			for (Integer i = 1; i <= (settings.MaxGames__c - gameCount); i++) {
				numGameOptions.add(new SelectOption(i.format(), i.format()));
			}
			return numGameOptions;
		}
	}
	
	public Settings__c settings {
		get {
			return PoolManagerUtils.getSettings();
		}
	}
	
	public List<SelectOption> teamList {
		get {
			if (teamList == null) {
				teamList = new List<SelectOption>();
				teamList.add(new SelectOption('', '-- None --'));
				List<Team__c> teams = new Selector_Team().selectAll();
				for (Team__c t : teams) {
					teamList.add(new SelectOption(t.Id, t.Short_Name__c));
				}
			}
			return teamList;
		}
		set;
	}
	
	public GamesController() {
		Map<String, String> params = ApexPages.currentPage().getParameters();
		
		if (params.get('weekNumber') != null) {
			this.weekNumber = params.get('weekNumber');
		} else {
			this.weekNumber = settings.CurrentWeek__c.format();
		}
		
		if (params.get('view') != null) {
			this.mode = params.get('view');
		} else {
			this.mode = 'view';
		}
		
		this.gameList = retrieveGameList();
	}
	
	public PageReference edit() {
		mode = 'edit';
		return null;
	}
	
	public PageReference editLocked() {
		mode = 'edit-locked';
		return null;
	}
	
	public PageReference addGame() {
		mode = 'edit';
		// Add a single game
		gameList.add(new GameWrapper(gameList.size() + 1, new Game__c(Week__c = weekNumber)));
		// Adjust game numbers
		for (Integer i = 0; i < gameList.size(); i++) {
			gameList.get(i).gameNumber = i + 1;
		}
		return null;
	}
	
	public PageReference addMultipleGames() {
		mode = 'edit';
		// Add the specified number of games
		Integer increment = Integer.valueOf(numGamesToAdd);
		for (Integer i = 0; i < increment; i++) {
			gameList.add(new GameWrapper(gameList.size() + 1, new Game__c(Week__c = weekNumber)));
		}
		// Adjust game numbers
		for (Integer i = 0; i < gameList.size(); i++) {
			gameList.get(i).gameNumber = i + 1;
		}
		return null;
	}
	
	public PageReference save() {
		List<Game__c> validatedGames = validateGames();
		if (validatedGames != null) {
			mode = 'view';
			upsert validatedGames;
			gameList = retrieveGameList();
		}
		return null;
	}
	
	public PageReference quickSave() {
		List<Game__c> validatedGames = validateGames();
		if (validatedGames != null) {
			upsert validatedGames;
			gameList = retrieveGameList();
		}
		return null;
	}
	
	public PageReference cancel() {
		mode = 'view';
		gameList = retrieveGameList();
		return null;
	}
	
	public PageReference deleteGame() {
		System.debug('Delete button ID: ' + deleteButtonId);
		Pattern p = Pattern.compile('.*?:(\\d+?):deleteButton');
		Matcher m = p.matcher(deleteButtonId);
		
		System.debug('Button ID: ' + deleteButtonId);
		
		if (m.matches()) {
			// Determine the game, based on which delete button was clicked
			Integer buttonIndex = Integer.valueOf(m.group(1));
			
			// See if there are any Selections referencing this game
			GameWrapper wrapper = gameList.get(buttonIndex);
			if ([SELECT COUNT() FROM Selection__c WHERE Game__c = :wrapper.game.Id] > 0) {
				ApexPages.addMessage(new ApexPages.Message(ApexPages.Severity.ERROR,
					'Unable to delete game ' + wrapper.gameNumber +
						' because one or more selections reference this game.' +
						' You must delete all selections that reference this game before it can be deleted.'));
			
			} else {
				gameList.remove(buttonIndex);
				if (wrapper.game.Id != null) {
					delete wrapper.game;
				}
				// Adjust game numbers
				for (Integer i = 0; i < gameList.size(); i++) {
					gameList.get(i).gameNumber = i + 1;
				}
			}
		}
		return null;
	}
    
    /**
     * Goes thru the list of GameWrapper objects, validating each of the wrapped
     * Games. If the Game is valid, it is added to a new list of Game objects that 
     * is suitable for upsert. If any of the Game objects is invalid, null is returned.
     * If all Game objects are valid, the validated list of Games is returned.
     *
     * @return List<Game__c>
     */
	private List<Game__c> validateGames() {
		Boolean valid = true;
		Map<Id, String> usedTeams = new Map<Id, String>();
		List<Game__c> validatedGames = new List<Game__c>();
		for (Integer i = 0; i < gameList.size(); i++) {
			Game__c game = gameList.get(i).game;
			
			// First, make sure both home and visiting team are set
			if ((game.Home_Team__c == null) || (game.Visiting_Team__c == null)) {
				ApexPages.addMessage(new ApexPages.Message(ApexPages.Severity.ERROR,
					'Game ' + (i + 1) + ' is invalid. You must set both home and visiting team, ' +
						'or remove this game from the list in order to be able to save the game list.'));
				valid = false;
			} else {
				
				// Check if home or visiting team has already been used
				if (usedTeams.containsKey(game.Home_Team__c)) {
					ApexPages.addMessage(new ApexPages.Message(ApexPages.Severity.ERROR,
						'Game ' + (i + 1) + ' is invalid. The home team you have selected has already been ' +
							'assigned to a previous game. You must either change the home team, ' +
							'or remove this game from the list in order to be able to save the game list.'));
					valid = false;
				}
				if (usedTeams.containsKey(game.Visiting_Team__c)) {
					ApexPages.addMessage(new ApexPages.Message(ApexPages.Severity.ERROR,
						'Game ' + (i + 1) + ' is invalid. The visiting team you have selected has already been ' +
							'assigned to a previous game. You must either change the visiting team, ' +
							'or remove this game from the list in order to be able to save the game list.'));
					valid = false;
				}
				
				// Add the home and visiting team to the used Teams map
				usedTeams.put(game.Home_Team__c, game.Home_Team__r.Name);
				usedTeams.put(game.Visiting_Team__c, game.Visiting_Team__r.Name);
			}
			
			// Validate home score, visiting score and point spread
			if ((game.Home_Score__c != null) && ((game.Home_Score__c < 0) || (game.Home_Score__c > 99))) {
				ApexPages.addMessage(new ApexPages.Message(ApexPages.Severity.ERROR,
					'Game ' + (i + 1) + ' is invalid. The home score must be a number between 0 and 99. ' +
						'You must either change the home score, or remove this game from the list in order ' +
						'to be able to save the game list.'));
				valid = false;
			}
			
			if ((game.Visiting_Score__c != null) && ((game.Visiting_Score__c < 0) || (game.Visiting_Score__c > 99))) {
				ApexPages.addMessage(new ApexPages.Message(ApexPages.Severity.ERROR,
					'Game ' + (i + 1) + ' is invalid. The visiting score must be a number between 0 and 99. ' +
						'You must either change the visiting score, or remove this game from the list in order ' +
						'to be able to save the game list.'));
				valid = false;
			}
			
			if ((game.Spread__c != null) && (game.Spread__c < -50) || (game.Spread__c > 50)) {
				ApexPages.addMessage(new ApexPages.Message(ApexPages.Severity.ERROR,
					'Game ' + (i + 1) + ' is invalid. The point spread must be a number between -50 and 50. ' +
						'You must either change the point spread, or remove this game from the list in order ' +
						'to be able to save the game list.'));
				valid = false;
			}
			
			// Validate that if the game is final, then home score, visiting score and spread all have values
			if (game.Final__c) {
				if ((game.Home_Score__c == null) || (game.Visiting_Score__c == null) || (game.Spread__c == null)) {
					ApexPages.addMessage(new ApexPages.Message(ApexPages.Severity.ERROR,
						'Game ' + (i + 1) + ' is invalid. In order to finalize the game, you must define values for ' +
							'home score, visiting score and spread.'));
					valid = false;
				}
			}
			
			if (valid) {
				// This game is valid, so add it to the list
				validatedGames.add(game);
			}
		}
		
		// Return the validated games list, or null
		if (valid) {
			return validatedGames;
		} else {
			return null;
		}
	}
	
	private List<GameWrapper> retrieveGameList() {
		List<Game__c> games = [
			SELECT p.Name, p.Id, p.Week__c,
				p.Start_Time__c, p.Home_Team__c, p.Home_Team__r.Name, p.Home_Score__c,
				p.Spread__c, p.Visiting_Team__c, p.Visiting_Team__r.Name, p.Visiting_Score__c,
				p.Final__c, p.Winner__c
			FROM Game__c p
			WHERE p.Week__c = :weekNumber
			ORDER BY p.Start_Time__c ASC NULLS LAST
		];
		List<GameWrapper> gameList = new List<GameWrapper>();
		for (Integer i = 0; i < games.size(); i++) {
			gameList.add(new GameWrapper(i + 1, games.get(i)));
		}
		return gameList;
	}
	
	public class GameWrapper {
		
		public Integer gameNumber { get; set; }
		public Game__c game { get; set; }
		public Boolean isLocked {
			get {
				if (game.Id != null) {
					Game__c current = [SELECT Start_Time__c FROM Game__c WHERE Id = :game.Id];
					return (current.Start_Time__c != null && (Datetime.now() > current.Start_Time__c));
				} else {
					return false;
				}
			}
		}
		
		public GameWrapper(Integer gameNumber, Game__c game) {
			this.gameNumber = gameNumber;
			this.game = game;
		}
	}
}