({
    onInit : function(cmp, evt, helper) {
        var getSettings = cmp.get("c.getSettings");
        helper.serverSideCall(getSettings, cmp).then(
            function(settings) {
                console.log(settings);
                cmp.set("v.selectedWeek", settings.CurrentWeek__c.toString());
                cmp.set("v.weekOptions", helper.getWeekOptions(settings.NumberOfWeeks__c));
                // Get the games for the current week
                var getGames = cmp.get("c.getGames");
                getGames.setParams({"weekNumber": settings.CurrentWeek__c.toString()});
                return helper.serverSideCall(getGames, cmp);
            }
        ).then(
            function(games) {
                console.log(games);
                cmp.set("v.games", games);
            }
        ).catch(
            function(error) {
                console.error(error);
                throw new Error(error);
            }
        );
    },
    weekSelected: function(cmp, evt, helper) {
        var selectedWeek = cmp.get("v.selectedWeek");
        var getGames = cmp.get("c.getGames");
        getGames.setParams({"weekNumber": selectedWeek});
        helper.serverSideCall(getGames, cmp).then(
            function(games) {
                console.log(games);
                cmp.set("v.games", games);
            }
        ).catch(
            function(error) {
                console.error(error);
                throw new Error(error);
            }
        );
    }
})