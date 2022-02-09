<#
This class creates an object that represents the information needed to connect to an MS ConfigMgr Primary Site Server

Instances of the class will indicate the Server Name, Site Code, Path to the MS ConfigMgr Powershell Module, 
and whether or not the module loaded and PSDrive was created.

This module is intended to allow the usage of cmdlets that do not require the MS ConfigMgr module independently, so we will not throw
errors if the module can't be loaded, only report on the status.

New-zCMSiteServerObject acts as a wrapper to create an instance of this class. It is also exposed external to the module.
#>

Class zCMSiteInfo {
    static [STRING]$SiteInfoRegPath = "HKCU:\Software\Microsoft\ConfigMgr10\AdminUI\MRU\1\"
    static [STRING]$DefaultModulePath = "$($ENV:SMS_ADMIN_UI_PATH)\..\ConfigurationManager.psd1"

    [STRING]$SCCMServer
    [STRING]$SCCMSiteCode
    [STRING]$SCCMWMINameSpace

    [STRING]$MSConfigMgrModulePath

    [BOOLEAN]$MSConfigMgrModuleLoaded
    [BOOLEAN]$ConfigMgrPSDriveLoaded


    # Default Constructor. Attempt to read the registry to get info about the last used Site Server
    zCMSiteInfo() {
        #Set up server name, site code, path to the configmgr module, WMI Namespace
        $this.SCCMServer =(Get-ItemProperty -Path ([zCMSiteInfo]::SiteInfoRegPath)).ServerName
        $this.SCCMSiteCode = (Get-ItemProperty -Path ([zCMSiteInfo]::SiteInfoRegPath)).SiteCode
        $this.MSConfigMgrModulePath = [zCMSiteInfo]::DefaultModulePath
        $this.SCCMWMINameSpace = "root\SMS\Site_$($this.SCCMSiteCode)"

        if ([STRING]::IsNullOrEmpty($this.SCCMServer)) {
            Throw "Unable to find an entry to SCCM Site Server in $([zCMSiteInfo]::SiteInfoRegPath)"
        }

        if ([STRING]::IsNullOrEmpty($this.SCCMSiteCode)) {
            Throw "Unable to find an entry to SCCM Site Code in $([zCMSiteInfo]::SiteInfoRegPath)"
        }


        #Import the MS ConfigManager module, if able
        Import-Module $this.MSConfigMgrModulePath -Global
        $MSConfigMgrModule = Get-Module ConfigurationManager
        if ($MSConfigMgrModule -eq $null) {
            $this.MSConfigMgrModuleLoaded = $false
        } else {
            $this.MSConfigMgrModuleLoaded = $true
        }

        #Create the PSDrive, if able
        if($null -eq (Get-PSDrive -Name $this.SCCMSiteCode -PSProvider CMSite -ErrorAction SilentlyContinue)) {
            New-PSDrive -Name $this.SCCMSiteCode -PSProvider CMSite -Root $this.SCCMServer -ErrorAction SilentlyContinue
        }

        #Validate whether or not the PSDrive was created
        if($null -eq (Get-PSDrive -Name $this.SCCMSiteCode -PSProvider CMSite -ErrorAction SilentlyContinue)) {
            $this.ConfigMgrPSDriveLoaded = $false
        } else {
            $this.ConfigMgrPSDriveLoaded = $true
        }

    }

    #Specify Site Server and Site Code, use the default location for the MS Config Mgr Module
    zCMSiteInfo([STRING]$SCCMServer,[STRING]$SCCMSiteCode) {
        #Set up server name, site code, path to the configmgr module, WMI Namespace
        $this.SCCMServer = $SCCMServer
        $this.SCCMSiteCode = $SCCMSiteCode
        $this.MSConfigMgrModulePath = [zCMSiteInfo]::DefaultModulePath
        $this.SCCMWMINameSpace = "root\SMS\Site_$($this.SCCMSiteCode)"

         #Import the MS ConfigManager module, if able
         Import-Module $this.MSConfigMgrModulePath -ErrorAction SilentlyContinue
         $MSConfigMgrModule = Get-Module ConfigurationManager
         if ($MSConfigMgrModule -eq $null) {
             $this.MSConfigMgrModuleLoaded = $false
         } else {
             $this.MSConfigMgrModuleLoaded = $true
         }

         #Create the PSDrive, if able
         if((Get-PSDrive -Name $this.SCCMSiteCode -PSProvider CMSite -ErrorAction SilentlyContinue) -eq $null) {
             New-PSDrive -Name $this.SCCMSiteCode -PSProvider CMSite -Root $this.SCCMServer -ErrorAction SilentlyContinue
         }

         #Validate whether or not the PSDrive was created
         if((Get-PSDrive -Name $this.SCCMSiteCode -PSProvider CMSite -ErrorAction SilentlyContinue) -eq $null) {
             $this.ConfigMgrPSDriveLoaded = $false
         } else {
             $this.ConfigMgrPSDriveLoaded = $true
         }

    }

        #Specify Site Server, Site Code, and Module Path
        zCMSiteInfo([STRING]$SCCMServer,[STRING]$SCCMSiteCode,[STRING]$MSConfigMgrModulePath) {
            #Set up server name, site code, path to the configmgr module, WMI Namespace
            $this.SCCMServer = $SCCMServer
            $this.SCCMSiteCode = $SCCMSiteCode
            $this.MSConfigMgrModulePath = $MSConfigMgrModulePath
            $this.SCCMWMINameSpace = "root\SMS\Site_$($this.SCCMSiteCode)"

             #Import the MS ConfigManager module, if able
        Import-Module $this.MSConfigMgrModulePath -ErrorAction SilentlyContinue
        $MSConfigMgrModule = Get-Module ConfigurationManager
        if ($MSConfigMgrModule -eq $null) {
            $this.MSConfigMgrModuleLoaded = $false
        } else {
            $this.MSConfigMgrModuleLoaded = $true
        }

        #Create the PSDrive, if able
        if((Get-PSDrive -Name $this.SCCMSiteCode -PSProvider CMSite -ErrorAction SilentlyContinue) -eq $null) {
            New-PSDrive -Name $this.SCCMSiteCode -PSProvider CMSite -Root $this.SCCMServer -ErrorAction SilentlyContinue
        }

        #Validate whether or not the PSDrive was created
        if((Get-PSDrive -Name $this.SCCMSiteCode -PSProvider CMSite -ErrorAction SilentlyContinue) -eq $null) {
            $this.ConfigMgrPSDriveLoaded = $false
        } else {
            $this.ConfigMgrPSDriveLoaded = $true
        }

        }

}
