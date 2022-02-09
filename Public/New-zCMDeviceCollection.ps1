<#
.SYNOPSIS
Create a new Device Collection, specify the update schedule and set the destination folder via one cmdlet.

.DESCRIPTION
Condenses common tasks needed when creating a new collection, including adding query rules, setting the update schedule and moving the collection to a new location after creation.

.PARAMETER CollectionName
Name to be assigned to the collection

.PARAMETER LimitingCollectionName
Name of the Limiting Collection

.PARAMETER DestinationFolderPath
If this is specified, the collection will be moved to the specified folder once it's been created

.PARAMETER CollectionComment
Optional comment to add to the collection

.PARAMETER MemberShipQueryRules
An array of collection query rules as strings. Be careful using this, invalid queries may result in a broken collection that can't be deleted unless the offending rules are removed first.
The best way to validate values to be added here is to create the queries in a test collection, then copy the text of the WMI query.

.PARAMETER CMSchedule
A schedule created using New-CMSchedule from the Microsoft ConfigurationManager module may be used here. Otherwise, the default schedule of one collection membership update per week will be used.

.PARAMETER DeleteOnFailure
Select this switch to attempt to delete the collection if it is not created properly.

.PARAMETER SiteInfo
An instance of zCMSiteInfo representing the SCCM Site Server to query against. Can be created via [zCMSiteInfo]::new() or by using New-zCMSiteServerObject. 
Will be created using default configuration if not specified, which will work fine in most situations.

.EXAMPLE
#Create Collection 'Test' limited by 'All Systems'
New-zCMDeviceCollection -CollectionName "Test" -LimitingCollectionName "All Systems"

.EXAMPLE
#Same as above, specifying site server 'MyServer' and Site Code 'CCM'
New-zCMDeviceCollection -CollectionName "Test" -LimitingCollectionName "All Systems" -SiteInfo (New-zCMSiteServerObject -SCCMSiteServerName "MyServer" -SCCMSiteCode "CCM")

.EXAMPLE
Create a new collection, specifying a destination folder and some query rules
$QryRules = @(
    'select SMS_R_SYSTEM.ResourceID,SMS_R_SYSTEM.ResourceType,SMS_R_SYSTEM.Name,SMS_R_SYSTEM.SMSUniqueIdentifier,SMS_R_SYSTEM.ResourceDomainORWorkgroup,SMS_R_SYSTEM.Client from SMS_R_System inner join SMS_G_System_INSTALLED_EXECUTABLE on SMS_G_System_INSTALLED_EXECUTABLE.ResourceId = SMS_R_System.ResourceId where (SMS_G_System_INSTALLED_EXECUTABLE.ExecutableName = "WINWORD.EXE" or SMS_G_System_INSTALLED_EXECUTABLE.ExecutableName = "EXCEL.EXE" or SMS_G_System_INSTALLED_EXECUTABLE.ExecutableName = "POWERPNT.EXE" or SMS_G_System_INSTALLED_EXECUTABLE.ExecutableName = "OUTLOOK.EXE") and SMS_G_System_INSTALLED_EXECUTABLE.FileVersion like "12.%"',
    'select SMS_R_SYSTEM.ResourceID,SMS_R_SYSTEM.ResourceType,SMS_R_SYSTEM.Name,SMS_R_SYSTEM.SMSUniqueIdentifier,SMS_R_SYSTEM.ResourceDomainORWorkgroup,SMS_R_SYSTEM.Client from SMS_R_System inner join SMS_G_System_OPERATING_SYSTEM on SMS_G_System_OPERATING_SYSTEM.ResourceID = SMS_R_System.ResourceId where SMS_G_System_OPERATING_SYSTEM.Caption like "Microsoft Windows XP %"'
    )
New-zCMDeviceCollection -CollectionName "Test" -LimitingCollectionName "All Systems" -DestinationFolderPath 'CCM:\DeviceCollection\Folder' -CollectionComment "This is a test" -MembershipQueryRules $QryRules
#>
Function New-zCMDeviceCollection {
    Param (
        # Collection Name
        [Parameter(Mandatory=$true)]
        [string]
        $CollectionName,

        # Limiting Collection Name
        [Parameter(Mandatory=$true)]
        [string]
        $LimitingCollectionName,

        # Comment to be added to the collection. May be left empty.
        [Parameter(Mandatory=$false)]
        [string]
        $CollectionComment = "",
        
        # Array of strings representing query rules for the collection. May be left empty.      
        [Parameter(Mandatory=$false)]
        [string[]]
        $MembershipQueryRules,

        # SCCM Schedule object built with New-CMSchedule. Will default to updating every 7 days if not specified.
        [Parameter(Mandatory=$false)]
        $CMSchedule,

        # Destination folder within a ConfigMgr PSDrive to move the collection to after creation. Will be created in the root of the Collections node.
        [Parameter(Mandatory=$false)]
        [string]
        $DestinationFolderPath,
        
        # Attempt to delete the object is it is not created properly
        [Parameter(Mandatory=$false)]
        [switch]
        $DeleteOnFailure,

        # Instance zCMSiteInfo class. Only needs to be set when the site server needs to be specified.
        [Parameter(Mandatory=$false)]
        [zCMSiteInfo]
        $SiteInfo = [zCMSiteInfo]::new()
    )

    #Make sure that we have the ConfigMgr Module Loaded and are connected to a CM PS Drive
    try {
        $SiteInfo | Test-zCMPSDrive
    }
    catch {
        Throw $_
    }

    #Verify that the destination path exists if it's specified. Throw an error if it doesn't exist.
    if ($DestinationFolderPath) {
        Write-Verbose "Validating path $DestinationFolderPath"
        if ( !(Test-Path $DestinationFolderPath) ) {
            Write-Error "Path '$DestinationFolderPath' does not exist or cannot be reached."
            Throw $_
        }
    }

    #Verify that the limiting collection exists
    Write-Verbose "Validating Limiting Collection $LimitedCollectionName"
    $limCol = Get-CMDeviceCollection -Name $LimitingCollectionName
    if ($null -eq $limCol) {
        Write-Error "Limiting Collection $LimitingCollectionName does not exist."
        Throw $_
    }

    #Create a CMSchedule object as needed
    if ($null -eq $CMSchedule) {
        Write-Verbose "No schedule specified, will use the default."
        try {
            $CMSchedule = New-CMSchedule -RecurCount 7 -RecurInterval Days -Start (get-date).AddHours(-12)
        }
        catch {
            Write-Error "Unable to create CMSchedule object."
            Throw $_
        }        
    } else {
        Write-Verbose "Validating that $CMSchedule is the correct type."
        if ($CMSchedule.GetType().name -ne "WqlArrayItems") {
            Write-Error "$CMSchedule appears to be of the wrong type. Create using New-CMSchedule."
            Throw $_
        }
    }

    #Fail if the collection exists
    Write-Verbose "Checking to see if collection exists."
    $col = Get-CMCollection -Name $CollectionName
    if ($col) {
        Throw "Collection '$CollectionName' already exists."
    }

    #Create the collection
    Write-Verbose "Creating '$CollectionName'"
    try {
        $Collection = New-CMDeviceCollection `
                -Comment $CollectionComment `
                -LimitingCollectionName $LimitingCollectionName `
                -Name $CollectionName `
                -RefreshSchedule $CMSchedule
    }
    catch {
        Write-Error "Unable to create collection $CollectionName"
        Throw $_
    }

    #Add Membership rules
    Write-Verbose "Adding Membership Rules."
    $i = 0
    Foreach ($rule in $MembershipQueryRules) {
        try {
            Add-CMDeviceCollectionQueryMembershipRule -RuleName "$CollectionName $i" -QueryExpression $rule -CollectionId $Collection.CollectionID
        }
        catch {
            Write-Error "Unable to add rule '$rule' to '$CollectionName'"
            if ($DeleteOnFailure) {
                Write-Verbose "Attempting to delete."
                Remove-CMCollection -Id $Collection.CollectionID -Force
            }
            Throw $_
        }
    }

    #Move collection as required    
    if ($DestinationFolderPath) {
        Write-Verbose "Moving Collection to $DestinationFolderPath"
        try {
            $Collection | Move-CMObject -FolderPath $DestinationFolderPath 
        }
        catch {
            Write-Error "Failed to move $CollectionName to $DestinationFolderPath"
            if ($DeleteOnFailure) {
                Write-Verbose "Attempting to delete."
                Remove-CMCollection -Id $Collection.CollectionID -Force
            }
            Throw $_
        }
    }

    #Get a fresh instance of the collection that includes all of the changes made and return it
    Write-Verbose "Process Completed"
    Return (Get-CMDeviceCollection -ID $Collection.CollectionID)

}