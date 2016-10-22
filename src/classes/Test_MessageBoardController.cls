@isTest
private class Test_MessageBoardController {
	
	static testMethod void testMessageBoardController() {
		
		// Delete any existing messages
		List<Message__c> existingMessages = [select Id from Message__c];
		delete existingMessages;
		
		// Create some test messages (two pages worth)
		List<Message__c> testMessages = new List<Message__c>();
		for (Integer i = 0; i < (2 * MessageBoardController.PAGE_SIZE); i++) {
			Message__c newMsg = new Message__c();
			newMsg.Message__c = 'This is message #' + (i + 1);
			testMessages.add(newMsg);
		}
		insert testMessages;
		
		PageReference msgBoardPage = Page.MessageBoard;
		Test.setCurrentPage(msgBoardPage);
		MessageBoardController con = new MessageBoardController();
		List<Message__c> messages = con.getMessages();
		System.assert(messages.size() == MessageBoardController.PAGE_SIZE);
		System.assert(con.pageSize == MessageBoardController.PAGE_SIZE);
		System.assert(con.getPageNumber() == 1);
		System.assert(con.getHasNext());
		System.assert(!con.getHasPrevious());
		System.assert(con.getResultSize() == (2 * MessageBoardController.PAGE_SIZE));
		con.next();
		System.assert(con.getPageNumber() == 2);
		System.assert(con.getHasPrevious());
		System.assert(!con.getHasNext());
		con.previous();
		con.first();
		con.last();
		System.assert(con.numberOfPages == 2);
		con.newMessage.message__c = 'This is message #' + ((2 * MessageBoardController.PAGE_SIZE) + 1);
		PageReference pageRef = con.post();
		System.assert(pageRef.getUrl().startsWith(Page.MessageBoard.getUrl()));
		System.assert(con.pageSize == MessageBoardController.PAGE_SIZE);
		con.cancel();
	}
}