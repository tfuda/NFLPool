public class ResultsController {
	
	public String currentWeek { get; set; }
	
	public String selectedWeek { get; set; }
	
	public List<String> weeks { get; set; }
	
	public ResultsController() {
		Settings__c s = [SELECT CurrentWeek__c FROM Settings__c];
		currentWeek = s.CurrentWeek__c.format();
		selectedWeek = ApexPages.currentPage().getParameters().get('week');
		if (selectedWeek == null) {
			selectedWeek = currentWeek;
		}
		weeks = new List<String>();
		for (Integer i = 1; i <= s.CurrentWeek__c; i++) {
			weeks.add(i.format());
		}
	}
	
	@RemoteAction
	public static Results getWeeklyResults(String week) {
		AggregateResult[] ar = [SELECT SUM(Points__c) pointsAvailable FROM Game__c WHERE Week__c = :week AND Final__c = true];
		Decimal pointsAvailable = (Decimal) ar[0].get('pointsAvailable');
		List<Weekly_Result__c> wrList = [
			SELECT Id, Name, Week__c, Player__r.Nickname__c,
				Total_Points__c, Total_Points_Available__c, Win_Percentage__c
			FROM Weekly_Result__c
			WHERE Week__c = :week
			ORDER BY Total_Points__c DESC
		];
		return getWeeklyResults(pointsAvailable, wrList);
	}
	
	@RemoteAction
	public static Results getSeasonalResults() {
		AggregateResult[] ar = [SELECT SUM(Points__c) pointsAvailable FROM Game__c WHERE Final__c = true];
		Decimal pointsAvailable = (Decimal) ar[0].get('pointsAvailable');
		List<Player__c> pList;
		if (!System.Test.isRunningTest()) {
			pList = [
				SELECT Id, Nickname__c, Total_Points__c,
					Total_Points_Available__c, Win_Percentage__c
				FROM Player__c
				WHERE User__r.IsActive = true
				ORDER BY Total_Points__c DESC
			];
		} else {
			pList = [
				SELECT Id, Nickname__c, Total_Points__c,
					Total_Points_Available__c, Win_Percentage__c
				FROM Player__c
				ORDER BY Total_Points__c DESC
			];
		}
		return getSeasonalResults(pointsAvailable, pList);
	}
	
	private static Results getWeeklyResults(Decimal pointsAvailable, List<Weekly_Result__c> wrList) {
		Results r = new Results();
		r.pointsAvailable = pointsAvailable;
		r.rWrappers = new List<ResultWrapper>();
		for (Weekly_Result__c wr : wrList) {
			ResultWrapper rWrapper = new ResultWrapper(wr.Player__r.Nickname__c, wr.Total_Points__c, wr.Win_Percentage__c);
			r.rWrappers.add(rWrapper);
		}
		return r;
	}
	
	private static Results getSeasonalResults(Decimal pointsAvailable, List<Player__c> pList) {
		Results r = new Results();
		r.pointsAvailable = pointsAvailable;
		r.rWrappers = new List<ResultWrapper>();
		for (Player__c p : pList) {
			ResultWrapper rWrapper = new ResultWrapper(p.Nickname__c, p.Total_Points__c, p.Win_Percentage__c);
			r.rWrappers.add(rWrapper);
		}
		return r;
	}
	
	public class Results {
		public Decimal pointsAvailable { get; set; }
		public List<ResultWrapper> rWrappers { get; set; }
	}
	
	public class ResultWrapper {
		public String nickname { get; set; }
		public Decimal pointsScored { get; set; }
		public Decimal winPercentage { get; set; }
		public ResultWrapper(String nickname, Decimal pointsScored, Decimal winPercentage) {
			this.nickname = nickname;
			this.pointsScored = pointsScored;
			this.winPercentage = winPercentage;
		}
	}
}