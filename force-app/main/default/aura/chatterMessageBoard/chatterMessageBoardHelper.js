({
    loadGroupId: function (component, event, helper) {
        var action = component.get("c.getGroupIdByName");
        action.setParams({ groupName: component.get("v.groupName") });
        action.setCallback(this, function (response) {
            var state = response.getState();
            if (state === "SUCCESS") {
                var groupId = response.getReturnValue();
                if (groupId) {
                    component.set("v.groupId", groupId);
                } else {
                    component.set("v.errorMessage", 'Chatter group "' + component.get("v.groupName") + '" was not found.');
                }
            } else {
                var errors = response.getError();
                var message = errors && errors[0] && errors[0].message
                    ? errors[0].message
                    : "An unknown error occurred while loading the message board.";
                component.set("v.errorMessage", message);
            }
            component.set("v.isLoading", false);
        });
        $A.enqueueAction(action);
    }
})
