<#
.SYNOPSIS
Create a new OS image, apply Security Scopes, Distribute Content and Move to a new location.

.DESCRIPTION
Condenses tasks commonly associated with the creation of a new Operating System Image into one command.

Security Scopes, Bondary Groups for Content Distribution and a destination folder may all be specified by using the appropriate parameters. 

.PARAMETER OSImageName
Name to be assigned to the OS Image

.PARAMETER OSImageSourcePath
Path to the .wim file used by the image

.PARAMETER SecurityScopeNames
Optional array of Security Scope names that should be assigned to the new OS Image


.PARAMETER DistributionPointGroupNames
Optional array of Distribution Point Group Names that the Package should be distributed to. Failure to distribute content will result in a warning, but will not cause the function to fail.


.PARAMETER OSImageDescription
Optional description for the OS image

.PARAMETER DestinationFolderPath
Optional folder that the OS image will be moved to after creation

.PARAMETER DeleteOnFailure
When specified, the new OS Image will be deleted if any critical part of the creation and configuration fails.

.PARAMETER SiteInfo
An instance of zCMSiteInfo representing the SCCM Site Server to query against. Can be created via [zCMSiteInfo]::new() or by using New-zCMSiteServerObject. 
Will be created using default configuration if not specified, which will work fine in most situations.

.EXAMPLE
Create a new image called 'New Image' using Image.wim as the source file. Add Security Scopes "Scope A" and "Scope B," move to 'CCM:\OperatingSystemImage\Folder\', delete the object if security scopes aren't set or it can't be moved.
New-zCMOSImage -OSImageName "New Image" -OSImageSourcePath "\\Server\Share\Image.Wim" -SecurityScopeNames "Scope A", "Scope B" -DistributionPointGroupNames "DP Group A", "DP Group B" -DestinationFolderPath "CCM:\OperatingSystemImage\Folder\" -DeleteOnFailure

.EXAMPLE
Create a new OS image and specify site server 'MyServer' and site 'CCM'
New-zCMOSImage -OSImageName "New Image" -OSImageSourcePath "\\Server\Share\Image.Wim" -SiteInfo (New-zCMSiteServerObject -SCCMSiteServerName "MyServer" -SCCMSiteCode "CCM")

#>
Function New-zCMOSImage {
    Param (
        # Name of the OS Image
        [Parameter(Mandatory=$true)]
        [string]
        $OSImageName,

        # OS Image Source file
        [Parameter(Mandatory=$true)]
        [string]
        $OSImageSourcePath,

        # Add one or more security scopes to the OS Image
        [Parameter(Mandatory=$false)]
        [string[]]
        $SecurityScopeNames,

        # Distribute content to one or more Distribution Point Groups
        [Parameter(Mandatory=$false)]
        [string[]]
        $DistributionPointGroupNames,

        # OS Image Description
        [Parameter(Mandatory=$false)]
        [string]
        $OSImageDescription,

        # Destination folder to move the OS Image to after creation
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


    #Throw an error if an image with the same name already exists
    try {
        $PkgTest = Get-CMOperatingSystemImage -Name $OSImageName
    }
    catch {
        Write-Error "Unable to validate OS Image."
        Throw $_
    }

    if ($PkgTest) {
        Throw "'$OSImageName' already exists."
    }

    #Validate that the specified Security Scopes exist and add them to an array
    if ($SecurityScopeNames) {
        Try {
            $SecurityScopes = $SecurityScopeNames | Test-zCMSecurityScope -SiteInfo $SiteInfo
        } Catch {
            Throw $_
        }
    }



    #Create the OS Image
    Write-Verbose "Creating OS Image Package '$OSImageName'."
    try {
        $PkgNew = New-CMOperatingSystemImage -name $OSImageName -Description $OSImageDescription -Path $OSImageSourcePath
    }
    catch {
        Write-Error "Unable to create '$OSImageName'"
        Throw $_
    }

    

    #Assign Security Scopes
    Foreach ($Scope in $SecurityScopes) {
        Write-Verbose "Assigning Security Scope '$($Scope.CategoryName)' to $OSImageName"
        try {
            $PkgNew | Add-CMObjectSecurityScope -Scope $Scope
        }
        catch {
            Write-Error "Unable to add scope $($Scope.CategoryName)"
            if ($DeleteOnFailure) {
                Write-Verbose "Attempting to delete."
                Remove-CMOperatingSystemImage -Id $PkgNew.PackageID -Force
            }
            Throw $_
        }
    }

    #Move the OS Image
    if ($DestinationFolderPath) {
        Write-Verbose "Moving '$OSImageName' to '$DestinationFolderPath'"
        try {
            $PkgNew | Move-CMObject -FolderPath $DestinationFolderPath
        }
        catch {
            Write-Error "Unable to move $OSImageName"
            if ($DeleteOnFailure) {
                Write-Verbose "Attempting to delete."
                Remove-CMOperatingSystemImage -Id $PkgNew.PackageID
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
    Return (Get-CMOperatingSystemImage -Id $PkgNew.PackageID)

}