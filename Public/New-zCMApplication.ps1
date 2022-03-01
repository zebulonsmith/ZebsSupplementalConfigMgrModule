<#
.DESCRIPTION
Creates a new ConfigManager Application Adds additional functionality to New-CMApplication such as the ability to set Security Scope names and specify a destionation folder.

.PARAMETER ApplicationName
Name of the Application to be created

.PARAMETER ApplicationDescription
Optional Application Description

.PARAMETER SecurityScopeNames
Comma Seperated list of security scope names to add to the Application.

.PARAMETER DestinationFolderPath
Optional folder path to move the Application to after creation

.PARAMETER DeleteOnFailure
When specified, the new Package will be deleted if any critical part of the creation and configuration fails.

.PARAMETER SiteInfo
An instance of zCMSiteInfo representing the SCCM Site Server to query against. Can be created via [zCMSiteInfo]::new() or by using New-zCMSiteServerObject.
Will be created using default configuration if not specified, which will work fine in most situations.

.EXAMPLE
#Create a new Application, set description, add security scopes and move to the folder CCM:\Application\TestFolder
New-zCMApplication -ApplicationName "TestApp" -ApplicationDescription "This is a test" -SecurityScopeNames "App Administrators, App Editors" -DestinationFolderPath "CCM:\Application\testfolder"
#>
Function New-zCMApplication {
    Param (
        # New application's name
        [Parameter(Mandatory=$true)]
        [string]
        $ApplicationName,

        # New Application's description
        [Parameter(Mandatory=$false)]
        [string]
        $ApplicationDescription = "",

        # Add one or more security scopes to the OS Image
        [Parameter(Mandatory=$false)]
        [string[]]
        $SecurityScopeNames,

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

    #Throw an error if an app with the same name already exists
    try {
        $AppTest = Get-CMApplication -Name $ApplicationName
    }
    catch {
        Write-Error "Unable to validate Application."
        Throw $_
    }

    if ($AppTest) {
        Throw "'$ApplicationName' already exists."
    }

    #Validate that the specified Security Scopes exist and add them to an array
    if ($SecurityScopeNames) {
        Try {
            $SecurityScopes = $SecurityScopeNames | Test-zCMSecurityScope -SiteInfo $SiteInfo
        } Catch {
            Throw $_
        }
    }


    #Create the application
    $NewApp = New-CMApplication -Name $ApplicationName -Description $ApplicationDescription

    #Assign Security Scopes
    Foreach ($Scope in $SecurityScopes) {
        Write-Verbose "Assigning Security Scope '$($Scope.CategoryName)' to $ApplicationName"
        try {
            $NewApp| Add-CMObjectSecurityScope -Scope $Scope
        }
        catch {
            Write-Error "Unable to add scope $($Scope.CategoryName)"
            if ($DeleteOnFailure) {
                Write-Verbose "Attempting to delete."
                Remove-CMApplication -Name $newApp.LocalizedDisplayName
            }
            Throw $_
        }
    }

        #Move the OS Image
        if ($DestinationFolderPath) {
            Write-Verbose "Moving '$ApplicationName' to '$DestinationFolderPath'"
            try {
                $NewApp | Move-CMObject -FolderPath $DestinationFolderPath
            }
            catch {
                Write-Error "Unable to move $ApplicationName"
                if ($DeleteOnFailure) {
                    Write-Verbose "Attempting to delete."
                    Remove-CMOperatingSystemImage -Id $NewApp.PackageID
                }
                Throw $_
            }
        }

    #Get an up to date instance of the Application and return it
    Return Get-CMApplication -Name $NewApp.LocalizedDisplayName

}