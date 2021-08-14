public with sharing class ScratchOrgDataLoader {
	public ScratchOrgDataLoader() {}
	public void loadData() {
		fflib_SObjectUnitOfWork uow = new fflib_SObjectUnitOfWork(new List<Schema.SObjectType>{
			Team__c.SObjectType,
			Game__c.SObjectType
		});
		// Create Team records
		uow.registerNew(createUnpersistedTeams());
	}
	public List<Team__c> createUnpersistedTeams() {
		return new List<Team__c>{
			new Team__c(Name = 'Arizona Cardinals', Short_Name__c = 'Cardinals'),
			new Team__c(Name = 'Atlanta Falcons', Short_Name__c = 'Falcons'),
			new Team__c(Name = 'Baltimore Ravens', Short_Name__c = 'Ravens'),
			new Team__c(Name = 'Buffalo Bills', Short_Name__c = 'Bills'),
			new Team__c(Name = 'Carolina Panthers', Short_Name__c = 'Panthers'),
			new Team__c(Name = 'Chicago Bears', Short_Name__c = 'Bears'),
			new Team__c(Name = 'Cincinnati Bengals', Short_Name__c = 'Bengals'),
			new Team__c(Name = 'Cleveland Browns', Short_Name__c = 'Browns'),
			new Team__c(Name = 'Dallas Cowboys', Short_Name__c = 'Cowboys'),
			new Team__c(Name = 'Denver Broncos', Short_Name__c = 'Broncos')
		};
	}
}