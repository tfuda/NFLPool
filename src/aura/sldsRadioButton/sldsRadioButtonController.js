({
    handleClick : function(cmp, event) {
        var compEvent = cmp.getEvent("optionSelected");
        compEvent.setParams({"fieldName": cmp.get("v.name"), "selectedValue": cmp.get("v.value")});
        compEvent.fire();
    }
})
