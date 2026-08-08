public class SelectionController {
	private Settings__c settings = PoolManagerUtils.getSettings();

	public String selectedPlayer { get; set; }

	public String playerName {
		get {
			if (selectedPlayer != null) {
				Player__c p = [
					select p.user__r.communitynickname
					from player__c p
					where p.id = :selectedPlayer
					limit 1
				];
				return p.user__r.communitynickname;
			} else {
				return null;
			}
		}
	}

	public String weekNumber { get; set; }

	// Returns true if the current user is an "admin"
	public Boolean isAdmin {
		get {
			if (isAdmin == null) {
				isAdmin = false;
				List<Profile> adminProfiles = [
					select id, name
					from profile
					where name = :Constants.SYSTEM_ADMIN_PROFILE
					or name = :Constants.POOL_ADMIN_PROFILE
				];
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
	public List<GameSelection> gameSelections { get; set; }

	public SelectionController() {

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

	/* Refreshes the gameSelections collection */
	public void refreshGameSelections(String weekNumber, String playerId) {

		gameSelections = new List<GameSelection>();

		// Get games for the specified week
		List<Game__c> games = [
			select id, name, start_time__c,
				home_team__r.name, home_score__c, spread__c,
				visiting_team__r.name, visiting_score__c, final__c, winner__c
			from game__c
			where week__c = :weekNumber
			order by start_time__c, name asc
		];

		List<Selection__c> selections;
		if (playerId != null) {
			// Get selections for the specified player
			selections = [
				select id, game__c, team__c, team__r.Name, player__c, points__c
				from selection__c
				where player__c = :playerId and game__c in :games
			];
		}

		// Now map the Selection to the Game ID
		Map<String, Selection__c> gameSelectionMap = new Map<String, Selection__c>();
		if (selections != null) {
			for (Selection__c selection: selections) {
				gameSelectionMap.put(selection.game__c, selection);
			}
		}

		// Finally, build a List of <GameSelection> objects
		for (Integer i = 0; i < games.size(); i++) {
			Game__c game = games.get(i);
			Selection__c selection = gameSelectionMap.get(game.Id);
			GameSelection gs = new GameSelection(i + 1, playerId, game, selection);
			gameSelections.add(gs);
		}
	}
}
