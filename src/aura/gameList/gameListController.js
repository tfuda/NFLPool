({
    onInit : function(cmp) {
        var action = cmp.get("c.getGames");
        action.setParams({ weekNumber : cmp.get("v.weekNumber") });

        action.setCallback(this, function(response) {
            var state = response.getState();
            if (state === "SUCCESS") {
                var games = response.getReturnValue();
                console.log(games);
                cmp.set("v.games", games);
            } else if (state === "INCOMPLETE") {
                // TODO - do something
            } else if (state === "ERROR") {
                var errors = response.getError();
                if (errors) {
                    if (errors[0] && errors[0].message) {
                        console.log("Error message: " + errors[0].message);
                    }
                } else {
                    console.log("Unknown error");
                }
            }
        });

        $A.enqueueAction(action);
    }
})