public class EmailController {
	public Boolean underTest { get; set; }
	
	public class UserWrapper {
		public Integer index { get; set; }
		public User usr { get; set; }
		public String label { get; set; }
		public Boolean selected { get; set; }
		
		public UserWrapper(Integer index, User usr) {
			this.index = index;
			this.usr = usr;
			if ('Player'.equals(usr.profile.name)) {
				this.label = usr.name + ' (' + usr.communitynickname + ')';
			} else if ('Pool Administrator'.equals(usr.profile.name)) {
				this.label = usr.name + ' (' + usr.communitynickname + ') *';
			}
			this.selected = false;
		}
	}
	
	public Integer numColumns = 4;
	public String mode { get; set; }
	public String subject { get; set; }
	public String message { get; set; }
	public Boolean selectAll { get; set; }
	public Boolean copyMe {
		get {
			if (copyMe == null) {
				copyMe = false;
			}
			return copyMe;
		}
		set;
	}
	
	public List<List<UserWrapper>> playerList {
		get {
			if (playerList == null) {
				List<User> users = [
					select id, name, communitynickname,
						username, email, profile.name
					from user
					where isactive = true and (profile.name = 'Player'
					or profile.name = 'Pool Administrator')
					order by name asc
				];
				
				playerList = new List<List<UserWrapper>>();
				List<UserWrapper> row;
				Integer playerIndex = 0;
				Integer colIndex = 0;
				for (User usr : users) {
					if (colIndex == 0) {
						row = new List<UserWrapper>();
					}
					UserWrapper wrapper = new UserWrapper(playerIndex, usr);
					row.add(wrapper);
					colIndex++;
					if ((colIndex == numColumns) || (playerIndex == users.size() - 1)) {
						playerList.add(row);
						colIndex = 0;
					}
					playerIndex++;
				}
			}
			return playerList;
		}
		set;
	}
	
	public EmailController() {
	}
	
	public PageReference emailPlayers() {
		mode = 'emailPlayers';
		return Page.Email;
	}
	
	public PageReference emailAdmins() {
		mode = 'emailAdmins';
		return Page.Email;
	}
	
	public PageReference selectDeselectAll() {
		if (true == selectAll) {
			for (List<UserWrapper> row : playerList) {
				for (UserWrapper wrapper : row) {
					wrapper.selected = true;
				}
			}
		} else {
			for (List<UserWrapper> row : playerList) {
				for (UserWrapper wrapper : row) {
					wrapper.selected = false;
				}
			}
		}
		return null;
	}
	
	public PageReference cancel() {
		playerList = null;
		subject = null;
		message = null;
		copyMe = null;
		selectAll = null;
		return Page.Email;
	}
	
	public PageReference send() {
		
		if (subject == null || subject.length() == 0) {
			ApexPages.addMessage(new ApexPages.Message(ApexPages.Severity.ERROR, 'You must specify a subject for your email.'));
		}
		
		if (message == null || message.length() == 0) {
			ApexPages.addMessage(new ApexPages.Message(ApexPages.Severity.ERROR, 'You must specify a message for your email.'));
		}
		
		// Get the selected recipients
		List<Id> targetIds = new List<Id>();
		if ('emailPlayers'.equalsIgnoreCase(mode)) {
			for (List<UserWrapper> row : playerList) {
				for (UserWrapper wrapper : row) {
					if (true == wrapper.selected) {
						targetIds.add(wrapper.usr.Id);
					}
				}
			}
		} else {
			List<User> admins = [
				select id, email, name, communitynickname, profile.name
				from user
				where isactive = true and
				(profile.name = 'Pool Administrator' or profile.name = 'Platform System Admin')
			];
			for (User admin : admins) {
				targetIds.add(admin.Id);
			}
			
			System.debug('admin list: ' + admins);
		}
		
		System.debug('playerList: ' + playerList);
		
		if (targetIds.size() == 0) {
			ApexPages.addMessage(new ApexPages.Message(ApexPages.Severity.ERROR, 'You must specify at least one recipient for your email.'));
		}
		
		// If validation fails, there will be messages, just return and display the messages
		if (ApexPages.hasMessages(ApexPages.Severity.ERROR)) {
			return Page.Email;
		}
		
		// Send the message.
		try {
			User me = [SELECT Id, Name, Email, CommunityNickname FROM User WHERE Id = :UserInfo.getUserId()];
			if (targetIds.size() == 1) {
				sendSingleEmailMessage(subject, message, targetIds[0], copyMe);
			} else {
				sendMassEmailMessage(subject, message, targetIds, copyMe);
			}
			ApexPages.addMessage(new ApexPages.Message(ApexPages.Severity.INFO, 'Your message has been sent.'));
			playerList = null;
			subject = null;
			message = null;
			copyMe = null;
			selectAll = null;
			return Page.Email;
		} catch (Exception ex) {
			ApexPages.addMessage(new ApexPages.Message(ApexPages.Severity.ERROR,
				'Error sending your email: ' + ex.getMessage() +
					' Contact your pool administrator(s) for assistance.'));
			return Page.Email;
		}
	}
	
	private static void sendSingleEmailMessage(String subject, String body, Id targetId, Boolean copyMe) {
		User me = [SELECT Id, Name, Email, CommunityNickname FROM User WHERE Id = :UserInfo.getUserId()];
		List<Messaging.Email> emailList = new List<Messaging.Email>();
		Messaging.SingleEmailMessage email = new Messaging.SingleEmailMessage();
		email.setTargetObjectId(targetId);
		email.setBccSender(copyMe);
		email.setReplyTo(me.email);
		email.setSenderDisplayName(me.name + ' (' + me.communitynickname + ')');
		email.setSubject(subject);
		email.setPlainTextBody(body);
		email.setSaveAsActivity(false);
		emailList.add(email);
		System.debug('emailList.size(): ' + emailList.size());
		if (!System.Test.isRunningTest()) {
			Messaging.sendEmail(emailList);
		}
	}
	
	private static void sendMassEmailMessage(String subject, String body, List<Id> targetIds, Boolean copyMe) {
		User me = [SELECT Id, Name, Email, CommunityNickname FROM User WHERE Id = :UserInfo.getUserId()];
		List<Messaging.Email> emailList = new List<Messaging.Email>();
		Messaging.MassEmailMessage email = new Messaging.MassEmailMessage();
		email.setTargetObjectIds(targetIds);
		email.setBccSender(copyMe);
		email.setReplyTo(me.email);
		email.setSenderDisplayName(me.name + ' (' + me.communitynickname + ')');
		email.setTemplateId(createEmailTemplate(subject, body).Id);
		email.setSaveAsActivity(false);
		emailList.add(email);
		System.debug('emailList.size(): ' + emailList.size());
		if (!System.Test.isRunningTest()) {
			Messaging.sendEmail(emailList);
		}
	}
	
	private static EmailTemplate createEmailTemplate(String subject, String body) {
		Datetime now = Datetime.now();
		EmailTemplate template = new EmailTemplate(
			DeveloperName = 'Temp_' + UserInfo.getUserId() + '_' + now.format('yyyyMMddHHmmss'),
			Name = 'Temp-' + UserInfo.getUserId() + '-' + now.format('yyyyMMddHHmmss'),
			Description = 'Temporary template created by ' + UserInfo.getUserName() + ' on ' + now.format(),
			Subject = subject,
			Body = body,
			TemplateType = 'text',
			Encoding = 'ISO-8859-1',
			FolderId = UserInfo.getUserId(),
			IsActive = true
		);
		insert template;
		return template;
	}
}