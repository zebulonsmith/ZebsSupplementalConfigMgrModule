<#
.SYNOPSIS
Create a new Package, apply Security Scopes, Distribute Content and Move to a new location.

.DESCRIPTION
Condenses tasks commonly associated with the creation of a new Operating System Package into one command.

Security Scopes, Bondary Groups for Content Distribution and a destination folder may all be specified by using the appropriate parameters. 

.PARAMETER PackageName
Name to be assigned to the Package

.PARAMETER PackageSourcePath
Path to the source files for the Package

.PARAMETER SecurityScopeNames
Optional array of Security Scope names that should be assigned to the new Package

.PARAMETER DistributionPointGroupNames
Optional array of Distribution Point Group Names that the Package should be distributed to. Failure to distribute content will result in a warning, but will not cause the function to fail.

.PARAMETER PackageDescription
Optional description for the Package

.PARAMETER DestinationFolderPath
Optional folder that the Package will be moved to after creation

.PARAMETER DeleteOnFailure
When specified, the new Package will be deleted if any critical part of the creation and configuration fails.

.PARAMETER SiteInfo
An instance of zCMSiteInfo representing the SCCM Site Server to query against. Can be created via [zCMSiteInfo]::new() or by using New-zCMSiteServerObject. 
Will be created using default configuration if not specified, which will work fine in most situations.

.EXAMPLE
#Create a new Package called 'Package Name' using PackageFolder as the source path. Add Security Scopes "Scope A" and "Scope B", move to "CCM:\Package\Folder\", delete the object if security scopes aren't set or it can't be moved.
New-zCMOSPackage -PackageName "Package Name" -OSPackageSourcePath "\\Server\Share\PackageFolder" -SecurityScopeNames "Scope A", "Scope B" -DistributionPointGroupNames "DP Group A", "DP Group B" -DestinationFolderPath "CCM:\Package\Folder\" -DeleteOnFailure

.EXAMPLE
#Create a new Package and specify site server 'MyServer' and site 'CCM'
New-zCMOSPackage -PackageName "Package Name" -OSPackageSourcePath "\\Server\Share\PackageFolder" -SiteInfo (New-zCMSiteServerObject -SCCMSiteServerName "MyServer" -SCCMSiteCode "CCM")

#>
Function New-zCMPackage {
    Param (
        # Name of the Package
        [Parameter(Mandatory=$true)]
        [string]
        $PackageName,

        # Package Source file
        [Parameter(Mandatory=$true)]
        [string]
        $PackageSourcePath,

        # Add one or more security scopes to the Package
        [Parameter(Mandatory=$false)]
        [string[]]
        $SecurityScopeNames,

        # Distribute content to one or more Distribution Point Groups
        [Parameter(Mandatory=$false)]
        [string[]]
        $DistributionPointGroupNames,

        # Package Description
        [Parameter(Mandatory=$false)]
        [string]
        $PackageDescription,

        # Destination folder to move the Package to after creation
        [Parameter(Mandatory=$false)]
        [string]
        $DestinationFolderPath,

        # Attempt to delete the object if it is not created properly
        [Parameter(mandatory=$false)]
        [switch]
        $DeleteOnFailure,

        # Instance zCMSiteInfo class. Only needs to be set when the site server needs to be specified
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

    #Throw an error if an Package with the same name already exists
    try {
        $PkgTest = Get-CMPackage -Name $PackageName
    }
    catch {
        Write-Error "Unable to validate Package."
        Throw $_
    }

    if ($PkgTest) {
        Throw "'$PackageName' already exists."
    }

    #Validate that the specified Security Scopes exist and add them to an array
    if ($SecurityScopeNames) {
        Try {
            $SecurityScopes = $SecurityScopeNames | Test-zCMSecurityScope -SiteInfo $SiteInfo
        } Catch {
            Throw $_
        }
    }

    #Create the Package
    Write-Verbose "Creating Package Package '$PackageName'."
    try {
        $PkgNew = New-CMPackage -name $PackageName -Description $PackageDescription -Path $PackageSourcePath
    }
    catch {
        Write-Error "Unable to create '$PackageName'"
        Throw $_
    }

    #Assign Security Scopes
    Foreach ($Scope in $SecurityScopes) {
        Write-Verbose "Assigning Security Scope '$($Scope.CategoryName)' to $PackageName"
        try {
            $PkgNew | Add-CMObjectSecurityScope -Scope $Scope
        }
        catch {
            Write-Error "Unable to add scope $($Scope.CategoryName)"
            if ($DeleteOnFailure) {
                Write-Verbose "Attempting to delete."
                Remove-CMPackage -Id $PkgNew.PackageID
            }
            Throw $_
        }
    }

    #Move the Package
    if ($DestinationFolderPath) {
        Write-Verbose "Moving '$PackageName' to '$DestinationFolderPath'"
        try {
            $PkgNew | Move-CMObject -FolderPath $DestinationFolderPath
        }
        catch {
            Write-Error "Unable to move $PackageName"
            if ($DeleteOnFailure) {
                Write-Verbose "Attempting to delete."
                Remove-CMPackage -Id $PkgNew.PackageID
            }
            Throw $_
        }
    }

    #Distribute Content
    if ($DistributionPointGroupNames) {
        Try {
            $DistributionPointGroupNames | Start-zCMContentDistribution -SiteInfo $SiteInfo
        } Catch {
            Write-warning $_.Exception.Message 
        }   
    }

    #Get a fresh copy of the newly created object so that it has updated properties and return it
    Write-Verbose "Process Completed."
    Return (Get-CMPackage -Id $PkgNew.PackageID)

}