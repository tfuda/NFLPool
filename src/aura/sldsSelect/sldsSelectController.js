({
    handleChange : function(cmp, evt) {
        console.log(evt);
        var compEvent = cmp.getEvent("optionSelected");
        compEvent.setParams({"fieldName": cmp.get("v.name"), "selectedValue": evt.target.value});
        compEvent.fire();
    }
})
