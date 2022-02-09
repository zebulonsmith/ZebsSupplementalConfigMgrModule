<#
.SYNOPSIS
Internal function to validate a provided array of Security Scope names

.DESCRIPTION
Will fail if any of the provided security scope names do not exist. Outputs a CMSecurityScope object

.PARAMETER SecurityScopeName
Name of the Security Scope to be validated and returned.

.PARAMETER SiteInfo
For internal functions, SiteInfo is a required parameter. It should be passed using the SiteInfo object from function calling this one.

.EXAMPLE
Validate a Security Scope named 'Scope A', get a CMSecurytScope object back
Test-zCMSecurityScope -SecurityScopeName 'Scope A'

.EXAMPLE
#Validate an array of strings ($SecurityScopeNames) containing Security Scope names
$SecurityScopes = $SecurityScopeNames | Test-zCMSecurityScope
#>
Function Test-zCMSecurityScope {
    Param (
        # Security Scope Name
        [Parameter(Mandatory=$true,ValueFromPipeline)]
        [string]
        $SecurityScopeName,

        # Instance zCMSiteInfo class. Should be passed by the public function calling this one
        [Parameter(Mandatory=$true)]
        [zCMSiteInfo]
        $SiteInfo
    )
    Begin {
        #Make sure that we have the ConfigMgr Module Loaded and are connected to a CM PS Drive
        Write-Verbose "Connectiong to CM PSDrive"
        try {
            $SiteInfo | Test-zCMPSDrive
        }
        catch {
            Throw $_
        }

        $returnObjects = @()
    }

    #Make sure that we can get a security scope and that one exists with the specified name
    Process {

        Write-Verbose "Processing Security Scope name $SecurityScopeName"
        Try {
            $ThisScope = Get-CMSecurityScope -Name $SecurityScopeName

        } Catch {
            Throw "Security Scope $SecurityScopeName could not be evaluated. $($_.Exception.Message)"
        }

        if ($null -eq $ThisScope) {
            Throw "Security Scope $SecurityScopeName does not exist. $($_.Exception.Message)"
        } else {
            Write-Verbose "Found Security Scope $($ThisScope.CategoryName)"
            $returnObjects += $ThisScope
        }


    }

    End {
        Write-Verbose "Returning Security $($returnObjects.Count) Scope(s) $($returnobjects.CategoryName)"
        return $returnObjects
    }
}