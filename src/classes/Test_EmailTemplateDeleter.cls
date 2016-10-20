@IsTest
public class Test_EmailTemplateDeleter{
    static testMethod void testEmailTemplateDeleter() {
        EmailTemplate t1 = new EmailTemplate(
            Name = 'Temp-Test1', 
            DeveloperName = 'Temp_Test1',
            Body = 'Test Template 1',
            FolderId = UserInfo.getUserId(),
            TemplateType = 'text',
            IsActive = true
        );
        insert t1;
        
        EmailTemplateDeleter etd = new EmailTemplateDeleter();
        etd.execute(null);
        
        EmailTemplate actual = [SELECT Id, Name FROM EmailTemplate WHERE Id = :t1.Id];
        System.assertEquals(t1.Id, actual.Id);
    }
}