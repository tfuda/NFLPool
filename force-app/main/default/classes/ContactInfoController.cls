public class ContactInfoController {
	public List<PlayerWrapper> getPoolAdmins() {
		List<User> adminUsers = [
			select Id
			from User
			where (Profile.Name = :Constants.POOL_ADMIN_PROFILE
			or Profile.Name = :Constants.SYSTEM_ADMIN_PROFILE)
			and IsActive = true
			
		];
		List<Id> userIds = new List<Id>();
		for (User usr : adminUsers) {
			userIds.add(usr.Id);
		}
		return PlayerWrapper.getPlayerWrapperList(userIds);
	}
}