public with sharing class ChatterMsgBoardController {
	public CollaborationGroup grp { get; set; }
	public ChatterMsgBoardController() {
	}
	
	public PageReference initNflGroup() {
		this.grp = [SELECT Id, Name FROM CollaborationGroup WHERE Name = :Constants.NFL_POOL_CHATTER_GROUP];
		return null;
	}
	
	public PageReference initAdminGroup() {
		this.grp = [SELECT Id, Name FROM CollaborationGroup WHERE Name = :Constants.NFL_POOL_ADMINS_CHATTER_GROUP];
		return null;
	}
}