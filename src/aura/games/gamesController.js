({
    onInit : function(cmp) {
        var serverSideCall = function(action, component) {
            return new Promise(function(resolve, reject) {
                action.setCallback(this,
                    function(response) {
                        var state = response.getState();
                        if (component.isValid() && state === "SUCCESS") {
                            resolve(response.getReturnValue());
                        } else if (component.isValid() && state === "ERROR") {
                            reject(new Error(_getErrorDescription(response.getError())));
                        }
                    });
                $A.enqueueAction(action);
            });
        }

        var getSettings = cmp.get("c.getSettings");
        serverSideCall(getSettings, cmp).then(
            function(settings) {
                console.log(settings);
                cmp.set("v.selectedWeek", settings.CurrentWeek__c);
                cmp.set("v.numWeeks", settings.NumberOfWeeks__c);
                var getGames = cmp.get("c.getGames");
                getGames.setParams({"weekNumber": settings.CurrentWeek__c.toString()});
                return serverSideCall(getGames, cmp);
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
    }
})