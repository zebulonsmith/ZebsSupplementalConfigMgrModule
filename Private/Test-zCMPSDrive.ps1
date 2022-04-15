<#
.SYNOPSIS
Used internally to validate that the PSDrive created by the MS ConfigMgr module exists and can be accessed. Will change the current location to the CM PSDrive as needed.

.PARAMETER SiteInfo
An instance of the zCMSiteInfo class.

.EXAMPLE
Test-zCMPSDrive -SiteInfo [zCMSiteInfo]::new()
#>
Function Test-zCMPSDrive {
    Param (
        # Site Info Object to validate
        [Parameter(Mandatory=$true, ValueFromPipeline=$true)]
        $SiteInfo
    )


    #Make sure that we have the ConfigMgr Module Loaded and are connected to a CM PS Drive
    Write-Verbose "Verifying that the Microsoft ConfigurationManager module is loaded and $($SiteInfo.SCCMSiteCode) PSDrive exists"
    if ($SiteInfo.MSConfigMgrModuleLoaded -eq $false) {
        Throw "Microsoft ConfigurationManager module is required to run this cmdlet."
    }
    if ($SiteInfo.ConfigMgrPSDriveLoaded -eq $false) {
        Throw "PSDrive $$($SiteInfo.SCCMSiteCode): does not exist."
    }

    #Move to the appropriate PSDrive
    Write-Verbose "Setting location to $($SiteInfo.SCCMSiteCode):"
    Try {
        Set-Location "$($SiteInfo.SCCMSiteCode):"
    } Catch {
        Write-Error "Unable to navigate to PSDrive '$($SiteInfo.SCCMSiteCode):'"
        Throw $_
    }

}