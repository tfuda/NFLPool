public class ContactInfoController {
	public List<PlayerWrapper> getPoolAdmins() {
		List<User> adminUsers = [select Id from User where Profile.Name = 'Pool Administrator'];
		List<Id> userIds = new List<Id>();
		for (User usr : adminUsers) {
			userIds.add(usr.Id);
		}
		return PlayerWrapper.getPlayerWrapperList(userIds);
	}
}