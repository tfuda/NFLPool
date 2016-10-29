({
    navigateToGame : function(component, event, helper) {
        var gameId = component.get("v.game.Id");
        var navToSObjEvt = $A.get("e.force:navigateToSObject");
        navToSObjEvt.setParams({
            recordId: gameId,
            slideDevName: "detail"
        });
        navToSObjEvt.fire();
    }
})