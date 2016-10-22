public class EmailTemplateDeleter implements Schedulable {
	public void execute(SchedulableContext sc) {
		DateTime cutoff = DateTime.now().addHours(-1);
		List<EmailTemplate> templateList = [SELECT Id FROM EmailTemplate WHERE Name LIKE 'Temp_%' AND CreatedDate < :cutoff];
		delete templateList;
	}
}