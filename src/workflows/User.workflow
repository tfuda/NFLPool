<?xml version="1.0" encoding="UTF-8"?>
<Workflow xmlns="http://soap.sforce.com/2006/04/metadata">
    <alerts>
        <fullName>ThursdayGameReminder</fullName>
        <description>Thursday game reminder email</description>
        <protected>false</protected>
        <recipients>
            <recipient>Players</recipient>
            <type>group</type>
        </recipients>
        <recipients>
            <recipient>PoolAdministrators</recipient>
            <type>group</type>
        </recipients>
        <senderType>CurrentUser</senderType>
        <template>unfiled$public/ThursdayGameReminder</template>
    </alerts>
</Workflow>
