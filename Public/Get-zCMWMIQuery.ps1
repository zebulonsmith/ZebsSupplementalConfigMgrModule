function Get-zCMWMIQuery {
    <#
      .SYNOPSIS
      Run a WMI query against an SCCM Site Server's root\SMS\Site_[SITECODE] namespace.

      .DESCRIPTION 
      Runs a WMI query against the root\SMS\Site_[SITECODE] namespace on the Site Server specified in $SiteInfo, which needs to be of type [zCMSiteInfo]. 
      Intended to be a shorter alternative to 'Get-WMIObject -query [QUERY] -Computername [SERVER] -Namespace root\SMS\Site_[SITECODE]      

      .EXAMPLE
      Get-zCMWMIQUery -query "Select * from SMS_CombinedDeviceResources where ResourceID = '167896'"

      .EXAMPLE
      Get-zCMWMIQuery -query "Select * from SMS_CombinedDeviceResources where ResourceID = '167896'" -SiteInfo ([zCMSiteInfo]::new("Servername","SiteCode"))

      .PARAMETER Query
      A valid WMI query to perform against the Site Server's root\SMS\Site_[SITECODE] namespace.

      .PARAMETER SiteInfo
      An instance of zCMSiteInfo representing the SCCM Site Server to query against. Will be created using default configuration if not specified.

      .PARAMETER Credential
      A PSCredential object may be specified when the currently logged on user does not have permission to execute a WMI query against the specified server.

      #>
    [cmdletBinding()]
    Param(
        #WMI Query to execute
        [Parameter(Mandatory=$true)]
        [String]$Query,

        #Instance zCMSiteInfo class. Only needs to be set when the site server needs to be specified
        [Parameter(Mandatory=$false)]
        [zCMSiteInfo]$SiteInfo = [zCMSiteInfo]::new(),

        #Optional credential object
        [Parameter(Mandatory=$false)]
        [ValidateNotNull()]
        [System.Management.Automation.PSCredential]
        [System.Management.Automation.Credential()]
        $Credential = [System.Management.Automation.PSCredential]::Empty
    )




    <#
        New-CIMSession doesn't know what to do with a [System.Management.Automation.PSCredential]::Empty object in the -Credential param.
        As a workaround, we'll only use that parameter if the credential object is populated.
    #>
    Try {
        if ($Credential -ne [System.Management.Automation.PSCredential]::Empty) {
            Write-Verbose "Creating CMSession with provided credentials."
            $CIMSession = New-CimSession -ComputerName $SiteInfo.SCCMServer -Credential $Credential
        } else {
            Write-Verbose "Creating CMSession with current user credentials."
            $CIMSession = New-CimSession -ComputerName $SiteInfo.SCCMServer        
        }
    } Catch {
        Throw $_
    }

    #Execute the query
     Try {
        Write-Verbose "Executing WMI Query '$Query' against '$($SiteInfo.SCCMServer)' namespace '$($SiteInfo.SCCMWMINameSpace)'"
        $result = Get-CimInstance -CimSession $CIMSession -Namespace $SiteInfo.SCCMWMINameSpace -Query $Query
    } Catch {
        Throw $_
    }

    Return $Result

}
