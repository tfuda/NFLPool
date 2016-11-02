({
    serverSideCall: function(action, component) {
        var getErrorDescription = function(errors) {
            if (errors) {
                if (errors[0] && errors[0].message) {
                   return errors[0].message;
                }
            } else {
                return "Unknown error";
            }
        }

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
    },
    getWeekOptions: function(numWeeks) {
        var weekOptions = [];
        for (var i = 1; i <= numWeeks; i++) {
            weekOptions.push({label: 'Week ' + i.toString(), value: i.toString()});
        }
        return weekOptions;
    }
})