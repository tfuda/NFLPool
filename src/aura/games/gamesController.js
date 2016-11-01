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
                            var errorMsg = "Unknown error";
                            var errors = response.getError();
                            if (errors) {
                                if (errors[0] && errors[0].message) {
                                   errorMsg = errors[0].message;
                                }
                            }
                            reject(new Error(errorMsg));
                        }
                    });
                $A.enqueueAction(action);
            });
        }

        var getSettings = cmp.get("c.getSettings");
        serverSideCall(getSettings, cmp).then(
            function(settings) {
                console.log(settings);
                cmp.set("v.selectedWeek", settings.CurrentWeek__c.toString());
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
    },
    onOptionSelected: function(cmp, evt) {
        console.log(evt);
        if (evt.getParam("fieldName") === "week") {
            var selectedWeek = evt.getParams("selectedValue");
            cmp.set("v.selectedWeek", selectedWeek);
            var getGames = cmp.get("c.getGames");
            getGames.setParams({"weekNumber": selectedWeek});
            AuraPromise.serverSideCall(getGames, cmp).then(
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