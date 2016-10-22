public with sharing class MessageBoardController {
	
	@TestVisible private static Integer PAGE_SIZE = 15;
	private ApexPages.StandardSetController base;
	
	public Message__c newMessage {
		get {
			if (newMessage == null) {
				newMessage = new Message__c();
			}
			return newMessage;
		}
		set;
	}
	
	public List<Message__c> getMessages() {
		return (List<Message__c>) base.getRecords();
	}
	
	public MessageBoardController() {
		refreshRecordSet();
	}
	
	private void refreshRecordSet() {
		this.base = new ApexPages.StandardSetController(
			Database.getQueryLocator(
			[
				Select m.Message__c, m.CreatedDate, m.CreatedBy.CommunityNickname,
					m.CreatedBy.FirstName, m.CreatedBy.LastName, m.CreatedById
				From Message__c m
				Order By m.CreatedDate desc
			]));
		this.base.setPageSize(PAGE_SIZE);
	}
    
    /* Pagination stuff */
    /* Indicates whether there are more records after the current page set */
	public Boolean getHasNext() {
		return this.base.getHasNext();
	}

    /* Indicates whether there are more records before the current page set */
	public Boolean getHasPrevious() {
		return this.base.getHasPrevious();
	}

    /* Gets the first page of records */
	public void first() {
		this.base.first();
	}

    /* Gets the previous page of records */
	public void previous() {
		this.base.previous();
	}

    /* Gets the next page of records */
	public void next() {
		this.base.next();
	}

    /* Gets the last page of records */
	public void last() {
		this.base.last();
	}

    /* Returns the current page number */
	public Integer getPageNumber() {
		return this.base.getPageNumber();
	}

    /* Returns the number of records in the result set */
	public Integer getResultSize() {
		return this.base.getResultSize();
	}

    /* Returns the number of pages in the result set */
	public Integer numberOfPages {
		get {
			Integer resultSize = this.base.getResultSize();
			Integer pageSize = this.base.getPageSize();
			Integer numberOfPages = resultSize / pageSize;
			if (Math.mod(resultSize, pageSize) > 0) {
				numberOfPages++;
			}
			return numberOfPages;
		}
	}
    
    /* Getters and setters for the page size */
	public Integer pageSize {
		get {
			return this.base.getPageSize();
		}
	}
    
    /* Action methods */
	public PageReference post() {
		if (newMessage.Message__c == null || newMessage.Message__c.length() == 0) {
			ApexPages.addMessage(new ApexPages.Message(ApexPages.Severity.ERROR,
				'A message body is required.'));
			return null;
		}
		
		insert newMessage;
		newMessage = new Message__c();
		PageReference ref = Page.MessageBoard;
		ref.setRedirect(true);
		return ref;
	}
	
	public PageReference cancel() {
		newMessage.Message__c = null;
		return null;
	}
}