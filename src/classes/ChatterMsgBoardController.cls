public with sharing class ChatterMsgBoardController {
	public CollaborationGroup grp { get; set; }
	public ChatterMsgBoardController() {
	}
	
	public PageReference initNflGroup() {
		this.grp = [SELECT Id, Name FROM CollaborationGroup WHERE Name = 'NFL Pool'];
		return null;
	}
	
	public PageReference initAdminGroup() {
		this.grp = [SELECT Id, Name FROM CollaborationGroup WHERE Name = 'NFL Pool Administrators'];
		return null;
	}
}