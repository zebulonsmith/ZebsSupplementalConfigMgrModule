# ZebsSupplimentalConfigMgrModule

[https://github.com/zebulonsmith/ZebsSupplimentalConfigMgrModule](https://github.com/zebulonsmith/ZebsSupplimentalConfigMgrModule)
[https://www.powershellgallery.com/packages/ZebsSupplimentalConfigMgrModule](https://www.powershellgallery.com/packages/ZebsSupplimentalConfigMgrModule)
## Overview

This module is intended to extend the functionality of the native Microsoft Configuration Manager module. It adds some functionality and convenience to existing features.

## Extended Functionality

### The zCMSiteInfo Class

This class is here to make it easier to perform actions based on whether or not the Configuration Manager console is installed, which makes the native ConfigurationManager module available. Many cmdlets in this module rely on the console installation but some do not. The zCMSiteInfo class helps us determine what is available at the time. Most cmdlets in this module accept a '-siteinfo' parameter that specifies which site actions should be performed against.

```powershell
#Connect to a specific site and site server
[zCMSiteInfo]::new("Servername","SiteCode")

#Automatically connect to the site associated with the console installation
[zCMSiteInfo]::new()
```

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

## Invoke-zCMWMIQuery

Performs a more basic query than Invoke-zCMAdvancedWMIQuery and can't limit to a collection, but will work without the native Configuration Manager module available.

```powershell
#Perform a query when the Configuration Manager console is installed and already attached to a site
Invoke-zCMWMIQuery -query "Select * from SMS_R_System"

#Perform a query from a device that does not have the console installed and doesn't know where the site server is
Invoke-zCMWMIQuery -query "Select * from SMS_CombinedDeviceResources where ResourceID = '167896'" -SiteInfo ([zCMSiteInfo]::new("Servername","SiteCode"))
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

```powershell
(get-date -Date "10/26/1985 1:35 AM") | Convert-zCMWMITimeFromDateTime
"19851026013500.000000-240" | Convert-zCMDateTimeFromWMITime
```

### Easily Create Common Queries for User and Device Collections

```powershell
#Create a device collection with a query to include devices with 'Microsoft 365 Apps for Enterprise%' version -Productversion '16.%' installed
$query = New-zCMDeviceCollectionInstalledSoftwareQueryRule -ProductName "Microsoft 365 Apps for enterprise%" -ProductNameOperator "like" -Productversion "16.%" -ProductVersionOperator "like"
New-zCMDeviceCollection -CollectionName "Collection Name" -LimitingCollectionName "All Desktop and Server Clients" -MembershipQueryRules $Query

#Create a device collection with a query to include devices in the Domain.com/Path/To/Computers
New-zCMDeviceCollection -CollectionName "Collection Name" -LimitingCollectionName "All Desktop and Server Clients" -MembershipQueryRules (New-zCMDeviceCollectionSystemOUPathQueryRUle -OUPath "Domain.com/Path/To/Computers")
```

### Find-zCMDevice

Search for Devices by Serial Number or Mac Address

```powershell
Find-zCMDevice -MacAddress "AA-BB-CC-DD-EE-FF"


Find-zCMDevice -SerialNumber "ABC1234" -ShowFriendlyOutput
```

### Shortcuts for Common Tasks

There are several cmdlets included to quickly create and copy objects. Most can create objects in a specific folder and perform other actions that otherwise require several operations. When applicable, content distribution can be triggered when the object is created. 

Copy-zCMTaskSequence

New-zCMApplication

New-zCMDeviceCollection

New-zCMUserCollection

New-zCMOSImage

New-zCMPackage
