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
    onOptionSelected: function(cmp, evt, helper) {
        console.log(evt);
        if (evt.getParam("fieldName") === "week") {
            var selectedWeek = evt.getParam("selectedValue");
            cmp.set("v.selectedWeek", selectedWeek);
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
    }
})