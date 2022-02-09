    <#
      .SYNOPSIS
      Create an instance of the zCMSiteInfo class, which is used to represent the Primary Site Server being connected to.

      .DESCRIPTION
      Allows Public functions to be launched with more flexibility, depending on where they are executed from.
      Also makes it easy to determine if the MS ConfigMgr module is available when it is needed.
      
      Most other functions in this module will accept an object of this type as input so that the values can be specified manually
      as needed. 

      In most situations, it will not be necessary to create the zCMSiteInfo object manually. This will mostly need to be used in situations where the 
      ConfigMgr console is installed to a non-default location, multiple environments are being managed, etc.


      .EXAMPLE
      Get-zCMSiteServerObject

      .EXAMPLE
      Get-zCMSiteServerObject -SCCMiteServerName "SERVER" -SCCMSiteCode "SVR"

      .EXAMPLE
      Get-zCMSiteServerObject  -SCCMiteServerName "SERVER" -SCCMSiteCode "SVR" -MSConfigMgrPath "c:\why\is\this\here"

      .PARAMETER SCCMSiteServername
      Name of the Configuration Manager Server to bind to. If not specified, the [zCMSiteInfo]::new() constructor will attempt to read the last used server
      from the registry.

      .PARAMETER SCCMSiteCode
      SCCM Site Code. Will attempt read from the registry if not specified.

      .PARAMETER MSConfigMgrModulePath
      If the ConfigMgr console is not installed in the default location, or $ENV:SMS_ADMIN_UI_PATH does not exist, this must be specified.

    
      #>
function New-zCMSiteServerObject {

    #Adding a DefaultParameterSetName that doesn't exist elsewhere allows us to run the cmdlet with no params
    [cmdletBinding(DefaultParameterSetName="UseDefault")]

    #AllProperties - Specify Server name, site code and Path to MS configMgr Module
    #ServerAndSiteCode - Specify the servername and site code, assume that the module is in the default location
    Param(
        [parameter(Mandatory,ParameterSetName="AllProperties")]
        [parameter(Mandatory,ParameterSetName="ServerAndSiteCode")]
        [String]$SCCMSiteServerName,

        [parameter(Mandatory,ParameterSetName="AllProperties")]
        [parameter(Mandatory,ParameterSetName="ServerAndSiteCode")]
        [String]$SCCMSiteCode,

        [parameter(Mandatory,ParameterSetName="AllProperties")]
        [String]$MSConfigMgrModulePath
        
    )

    Switch ($PSCmdlet.ParameterSetName) {
        "UseDefault" {
            Write-Verbose "Creating [zCMSiteInfo] Object using default properties."
            Try {
                $SiteInfo = [zCMSiteInfo]::new()
            } Catch {
                Throw $_
            }
        }

        "AllProperties" {
            Write-Verbose "Creating [zCMSiteInfo] Object using SCCMSiteServerName, SCCMSiteCode and MSConfigMgrModulePath."
            if ( !(Test-Path -Path $MSConfigMgrModulePath) ) {
                Write-Warning "Unable to resolve path $MSConfigMgrModulePath"
            }
            
            Try {
                $SiteInfo = [zCMSiteInfo]::new($SCCMSiteServerName, $SCCMSiteCode, $MSConfigMgrModulePath)
            } Catch {
                Throw $_
            }
        }

        "ServerAndSiteCode" {
            Write-Verbose "Creating [zCMSiteInfo] Object using SCCMSiteServerName, SCCMSiteCode."
            Try {
                $SiteInfo = [zCMSiteInfo]::new($SCCMSiteServerName, $SCCMSiteCode)
            } Catch {
                Throw $_
            }
        }

    }

    #Write Warnings in the event that we're missing the PSDrive and/or Module
    if ($SiteInfo.MSConfigMgrModuleLoaded -eq $false) {
        Write-Warning "Unable to load Microsoft ConfigurationManager Module from path $($SiteInfo.MSConfigMgrModulePath)"
    }

    if ($SiteInfo.ConfigMgrPSDriveLoaded -eq $false) {
        Write-Warning "Unable to create PSDrive '$($SiteInfo.SCCMSiteCode)'"
    }

    Return $SiteInfo

}