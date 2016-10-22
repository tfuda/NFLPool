@isTest
private class Test_PlayerListController {
	
	static testMethod void testPlayerListController() {
		
		PageReference pageRef = Page.PlayerManagement;
		System.Test.setCurrentPage(pageRef);
		PlayerListController controller = new PlayerListController();
		
		// This assertion assumes there is at least one 'Player' or 'Pool Administrator'
		System.assert(controller.playerWrappers.size() > 0);
		
		// Loop until we find an "active" player
		PlayerWrapper activePlayer;
		for (PlayerWrapper p : controller.playerWrappers) {
			if (p.usr.isactive) {
				activePlayer = p;
				break;
			}
		}
		System.assert(activePlayer != null);
		pageRef.getParameters().put('id', activePlayer.usr.id);
		PageReference newPageRef = controller.deactivate();
		System.assert(newPageRef == null);
		User u = [select id, isactive from user where id = :activePlayer.usr.id limit 1];
		System.assert(false == u.isactive);
		
		pageRef.getParameters().put('id', activePlayer.usr.id);
		newPageRef = controller.activate();
		System.assert(newPageRef == null);
		u = [select id, isactive from user where id = :activePlayer.usr.id limit 1];
		System.assert(true == u.isactive);
		
		newPageRef = controller.newPlayer();
		System.assert(newPageRef.getUrl().startsWith(Page.PlayerDetail.getUrl()));
		String mode = newPageRef.getParameters().get('mode');
		System.assertEquals('new', mode);
	
	}
}