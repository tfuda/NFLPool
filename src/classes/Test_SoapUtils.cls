@isTest
private class Test_SoapUtils {

	static testMethod void testSoapUtils() {
		SoapUtils.PoolManagerUtils pmu = new SoapUtils.PoolManagerUtils();
		Profile p = [SELECT Id FROM Profile WHERE Name='Player'];
		try {
			String response = pmu.createPlayerUser('Test', 'Tester', 'test.tester@nflpool.com', 'testy', 'tester@testing.com',
				'(222) 555-5555', '123 Test Street', 'Testville', 'TN', '12345', p.Id, true);
			System.assert(false, 'Unit test methods do not support web service callouts.');
		} catch (Exception ex) {
			System.assert(true);
		}
		try {
			String response = pmu.updatePlayerUser(UserInfo.getUserId(), 'Test', 'Tester', 'test.tester@nflpool.com', 'testy', 't.tester@test.com', 
				'(222) 555-1234', '555 Test Lane', 'Testville', 'TN', '12345', p.Id, true);
			System.assert(false, 'Unit test methods do not support web service callouts.');
		} catch (Exception ex) {
			System.assert(true);
		}
	}
}