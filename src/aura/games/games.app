<aura:application description="games" extends="force:slds">
    <aura:attribute name="weekNumber" type="String" default="1"/>
    <div class="slds" >
	    <c:gameList weekNumber="{!v.weekNumber}"/>
    </div>
</aura:application>
