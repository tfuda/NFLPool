public class PlayerListController {
	
	private ApexPages.StandardSetController base;
	
	public Boolean activeOnly {
		get {
			if (activeOnly == null)
				activeOnly = true;
			return activeOnly;
		}
		set;
	}
	
	public List<PlayerWrapper> playerWrappers {
		get {
			// Build a list of PlayerWrapper objects that encapsulate the User
			// and associated Player object in one object
			refreshRecordSet();
			List<User> users = (List<User>) this.base.getRecords();
			List<Id> userIds = new List<Id>();
			for (User usr : users) {
				userIds.add(usr.id);
			}
			return PlayerWrapper.getPlayerWrapperList(userIds);
		}
	}
	
	public PlayerListController() {
		refreshRecordSet();
	}
	
	private void refreshRecordSet() {
		this.base = new ApexPages.StandardSetController(
			Database.getQueryLocator(
				'select id, name, username, firstname, lastname, phone, email, communitynickname, '
					+ 'alias, isactive, profileid, profile.name from user '
					+ 'where (profile.name = \'' + Constants.PLAYER_PROFILE
					+ '\' or profile.name = \'' + Constants.PLAYER_PLATFORM_PROFILE
					+ '\' or profile.name = \'' + Constants.POOL_ADMIN_PROFILE
					+ '\') ' + ((activeOnly) ? 'and isactive = true ' : '')
					+ 'order by name asc'
			)
		);
		this.base.setPageSize(50);
	}
	
	public PageReference toggleActiveOnly() {
		this.activeOnly = !this.activeOnly;
		return null;
	}
	
	public PageReference deactivate() {
		String userId = ApexPages.currentPage().getParameters().get('id');
		User usr = [select id, isactive from user where id = :userId limit 1];
		usr.isactive = false;
		update usr;
		refreshRecordSet();
		return null;
	}
	
	public PageReference activate() {
	String userId = ApexPages.currentPage().getParameters().get('id');
	User usr = [select id, isactive from user where id = :userId limit 1];
	usr.isactive = true;
	update usr;
	refreshRecordSet();
return null;
}

public PageReference newPlayer() {
PageReference playerDetail = Page.PlayerDetail;
playerDetail.getParameters().put('mode', 'new');
return playerDetail;
}
}