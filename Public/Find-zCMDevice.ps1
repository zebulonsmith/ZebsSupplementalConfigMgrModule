<#
.DESCRIPTION
Search for a Device Resource using either the mac address or serial number. Useful when the resrouce name or resource ID is not known.

.PARAMETER ByMac
Search using the mac address

.PARAMETER BySerial
Search by serial number

.PARAMETER ShowFriendlyOutput
Returns user readable text instead of a CMDevice object

.PARAMETER SiteInfo
An instance of zCMSiteInfo representing the SCCM Site Server to query against. Can be created via [zCMSiteInfo]::new() or by using New-zCMSiteServerObject. 
Will be created using default configuration if not specified, which will work fine in most situations.

.EXAMPLE
Find-zCMDevice -MacAddress "AA-BB-CC-DD-EE-FF"

.EXAMPLE
Find-zCMDevice -SerialNumber "ABC1234" -ShowFriendlyOutput

#>
function Find-zCMDevice {
    [CmdletBinding()]
    param (
        # Search by Mac Address
        [Parameter(ParameterSetName="ByMac", Mandatory=$true)]
        [string]
        $MacAddress,

        # Search by Serial Number
        [Parameter(ParameterSetName="BySerial", Mandatory=$true)]
        [string]
        $SerialNumber,

        # Show Friendly Output instead of returning a CMDevice object
        [Parameter(Mandatory=$false)]
        [switch]
        $ShowFriendlyOutput,

        #Instance zCMSiteInfo class. Only needs to be set when the site server needs to be specified
        [Parameter(Mandatory=$false)]
        $SiteInfo = [zCMSiteInfo]::new()
    )

    #Make sure that we have the ConfigMgr Module Loaded and are connected to a CM PS Drive
    try {
        $SiteInfo | Test-zCMPSDrive
    }
    catch {
        Throw $_
    }

    #Set up a WMI query to use for finding devices based on the provided search parameters
    switch ($PSCmdlet.parameterSetName) {
        "ByMac" {
            #Convert the provided mac address to a format that SCCM likes
            Write-Verbose "Searching by MAC"
            Try {
                $ConvertedMac = $MacAddress | ConvertTo-zCMMacAddress
            } Catch {
                Throw $_
            }
            $DeviceQry = "select ResourceID from sms_r_system where MACAddresses like '%$($ConvertedMac)%'"
        } #End of ByMac

        "BySerial" {
            Write-Verbose "Searching by Serial"
            $DeviceQry = "Select ResourceID from SMS_G_System_SYSTEM_ENCLOSURE where SerialNumber = '$SerialNumber'" 
        } #End of BySerial

        Default {}
    }

     #Array to hold results of the search. We'll get a list of ResourceIDs, then use Get-CMDevice to resolve them 
     Write-Verbose "Executing WMI Query $DeviceQry"
     $WMIResults = @(Invoke-zCMWMIQuery -Query $DeviceQry -siteinfo $SiteInfo)


    #Array of CMDevice objects that will be returned
    $CMDevices = @()
     Foreach ($Result in $WMIResults) {
        Write-Verbose "Retrieving CMResource Object for ResourceID $($result.ResourceID)"
        $CMDevices += Get-CMResource -ResourceID $Result.ResourceID -fast
     }

    Write-Verbose "Found $($CMDevices.Count) Results."

     #And here we have one of the few valid use cases for Write-Host

###REDO THIS BIT?###
###LOGIC TO DECIDE IF THE DEVICE SHOULD BE DELETED?###

     if ($ShowFriendlyOutput) {
        Write-Verbose "Showing Friendly Output"
        Write-Host "Found " -ForegroundColor Magenta -NoNewline
        Write-Host "$($CMDevices.Count) " -ForegroundColor Yellow -NoNewline
        Write-Host "devices matching the search parameters." -ForegroundColor Magenta

        #Leave now if we didn't find anything
        if ($CMDevices.Count -eq 0 ) {
            Write-Verbose "Found zero devices, exiting."
            return
        }

        #Found multiple devices. Throw a warning
        if ($CMDevices.Count -gt 1) {
            Write-Warning "Found $($CMDevices.Count) devices matching the search parameters. Consider deleting them."
        }


        #Loop through each device and show relevant info
        foreach ($thisDevice in $CMDevices) {
            #I should write a function that uses $Host.UI.RawUI data to figure out how to make a horizontal line.
            Write-Host "=================================================================================================="
            Write-Host "Name: " -ForegroundColor Magenta -NoNewline
            Write-Host $thisdevice.name -ForegroundColor Yellow

            Write-Host "CreationDate: " -ForegroundColor Cyan -NoNewline
            Write-Host $thisdevice.CreationDate -ForegroundColor Yellow

            Write-Host "DistinguishedName: " -ForegroundColor Cyan -NoNewline
            Write-Host $thisdevice.DistinguishedName -ForegroundColor Yellow

            Write-Host "MacAddresses: " -ForegroundColor Cyan -NoNewline
            Write-Host $thisdevice.MacAddresses -ForegroundColor Yellow

            Write-Host "HardwareID: " -ForegroundColor Cyan -NoNewline
            Write-Host $thisdevice.HardwareID -ForegroundColor Yellow

            Write-Host "IsVirtualMachine: " -ForegroundColor Cyan -NoNewline
            Write-Host $thisdevice.IsVirtualMachine -ForegroundColor Yellow

            Write-Host "LastLogonTimeStamp: " -ForegroundColor Cyan -NoNewline
            Write-Host $thisdevice.LastLogonTimeStamp -ForegroundColor Yellow

            Write-Host "LastLogonUserName: " -ForegroundColor Cyan -NoNewline
            Write-Host $thisdevice.LastLogonUserName -ForegroundColor Yellow

            if ($thisDevice.Client -eq 0) {
                Write-Warning "Device does not have the config manager client installed."
            }


            Write-Host

        }

     } Else {
        Return $CMDevices
     }

}