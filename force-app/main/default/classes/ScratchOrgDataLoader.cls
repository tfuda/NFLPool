public with sharing class ScratchOrgDataLoader {
	public ScratchOrgDataLoader() {}
	public void loadData() {
		fflib_SObjectUnitOfWork uow = new fflib_SObjectUnitOfWork(new List<Schema.SObjectType>{
			Team__c.SObjectType,
			Game__c.SObjectType
		});
	}
	public List<Team__c> createUnpersistedTeams() {
		return new List<Team__c>();
	}
}