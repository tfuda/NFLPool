public with sharing class Selector_Team extends fflib_SObjectSelector {
	public Schema.SObjectType getSObjectType() {
		return Team__c.SObjectType;
	}

	public List<Schema.SObjectField> getSObjectFieldList() {
		return new List<Schema.SObjectField>{
			Team__c.Id,
			Team__c.External_ID__c,
			Team__c.Name,
			Team__c.Short_Name__c
		};
	}

	public override String getOrderBy() {
		return Team__c.Short_Name__c.getDescribe().name;
	}

	public List<Team__c> selectAll() {
		fflib_QueryFactory qf = newQueryFactory();
		return (List<Team__c>) Database.query(qf.toSOQL());
	}
}