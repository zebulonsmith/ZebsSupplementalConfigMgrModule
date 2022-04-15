# ZebsSupplimentalConfigMgrModule

## Overview

This module is intended to extend the functionality of the native Microsoft Configuration Manager module. It adds some functionality and convenience to existing features.

## Extended Functionality

### Get-zCMUserGroupResource

This cmdlet can search for and return SMS\_R\_UserGroup object. This is very useful when creating User Collections with a User Group Resource as a direct member.

```powershell
#Create a user collection called 'Accounting Users' and add the 'Domain\AccountingUsers' UserGroup Resource as a direct member.
New-zCMUserCollection -CollectionName "Accounting Users" -LimitingCollectionName "All Users and User Groups" | 
	% {Add-CMUserCollectionDirectMembershipRule -CollectionId $_.CollectionID -ResourceId (Get-zCMUserGroupResource -Name 'Domain\\Accounting Users').ResourceID}
```

### Invoke-zCMAdvancedWMIQuery

There isn't currently a good native method of executing a WQL query that's limited to a single collection. This cmdlet fills that gap and also provides better output when using [Extended WQL](https://docs.microsoft.com/en-us/mem/configmgr/develop/core/understand/extended-wmi-query-language) in queries.

```powershell
#Show differences in output when using Extended WQL
$query = "Select DISTINCT resourceID from sms_r_system where name = '$($env:computername)'"

Invoke-zCMAdvancedWMIQuery -Query $query

#vs

Invoke-CMWmiQuery -Query $query



#Query only devices from the collection ZEB000001
"Select * from SMS_R_System" | Invoke-zCMAdvancedWMIQuery -Query $query -CollectionID "ZEB000001"
```

## Convenience

These cmdlets were written because I'm lazy. They assist with the automation of common tasks within Configuration Manager.

### ConvertTo-zCMMacAddress

Converts most strings of 12 alpha-numeric characters (with or without special characters in between) to the mac address format used by MECM. Useful when building WMI queries.

```powershell
$macs = "`"" + ( ((Get-NetAdapter).MacAddress | ConvertTo-zCMMacAddress ) -join "`", `"" ) + "`""
Invoke-zCMWMIQuery -Query "Select * from SMS_R_System where MacAddresses in ($macs)"
```

### Convert-zCMDateTimeFromWMITime and Convert-zCMWMITimeFromDateTime

Convert between DateTime objects and [DMTF Date and Time Format](https://docs.microsoft.com/en-us/windows/win32/wmisdk/date-and-time-format), which is often used in WMI objects.
