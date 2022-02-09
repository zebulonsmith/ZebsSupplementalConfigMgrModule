<#
.SYNOPSIS
.DESCRIPTION
.PARAMETER String
.EXAMPLE
#>
Function Start-zCMContentDistribution {
    Param (
        # DP Group Name
        [Parameter(Mandatory=$true,ValueFromPipeline)]
        [string]
        $DistributionPointGroupName,

        # Instance zCMSiteInfo class. Should be passed by the public function calling this one
        [Parameter(Mandatory=$true)]
        [zCMSiteInfo]
        $SiteInfo
    )
    Begin {
        #Make sure that we have the ConfigMgr Module Loaded and are connected to a CM PS Drive
        try {
            $SiteInfo | Test-zCMPSDrive
        }
        catch {
            Throw $_
        }

    }#Begin


    Process {


    #Distribute Content

        Write-Verbose "Distributing Content to $DistributionPointGroupName"
        try {
            $PkgNew | Start-CMContentDistribution -DistributionPointGroupName $DistributionPointGroupName
        }
        catch {
            Throw  "Failed to distribute content to $DistributionPointGroupName. $($_.Exception.Message)"
        }


    } #Process

    End {
        Write-verbose "Finished."
    }
}