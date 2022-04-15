<#
.DESCRIPTION
Returns an array of CMCollection objects of which the provided Device Resource is a member of.

The Device may be specified using either an input object created with Get-CMResource, the Computer Name, or the Resource ID.

.PARAMETER InputObject
Used when providing a CMDevice object from the command line

.PARAMETER ComputerName
Computer Name as a string

.PARAMETER ResourceID
ResourceID as a string or int

.PARAMETER ShowPrettyOutput
Spits out a formatted table containing relevant results. Useful for quick lookup tasks

.PARAMETER NoReturnObject
Instructs the cmdlet that no output object should be returned. Best used with ShowPrettyOutput when manually looking up a device.

.EXAMPLE
Search using the pipeline
Get-cmdevice -name $env:computername -fast | Get-zCMDeviceCollectionMembership

.EXAMPLE
Search using Computer Name
Get-zCMDeviceCollectionMembership -ComputerName $env:computerName

.EXAMPLE
Search using ResourceID
Get-zCMDeviceCollectionmembership -ResourceID 16794302

.EXAMPLE
Search using ResourceID, do not return any objects and show a table with the results found
Get-zCMDeviceCollectionmembership -ResourceID 16794302 -ShowPrettyOutput -NoReturnObject
#>
Function Get-zCMDeviceCollectionMembership {


    Param (
        [Parameter(ParameterSetName="DeviceObject",ValueFromPipeLine=$true)]
        $InputObject,
        [Parameter(ParameterSetName="ByName")]
        [STRING]$ComputerName,
        [Parameter(ParameterSetName="ByResourceID")]
        [INT32]$ResourceID,
        [Parameter(Mandatory=$false)]
        [SWITCH]$ShowPrettyOutput,
        [Parameter(Mandatory=$false)]
        [SWITCH]$NoReturnObject,
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

    #Use the provided params to get a CMDevice that we'll use to search for collection membership.
    #It's important to validate this to make sure that we're getting correct results and for performance
    #It takes much less time to verify that a device resource exists than it does to run the collection membership query
    switch ($PSCmdlet.ParameterSetName)
    {
        "DeviceObject" {
                            Write-Debug "Using Input Object to validate the device."

                            if ([String]::IsNullOrEmpty($InputObject.ResourceID) ) {
                                Throw "InputObject is not a CMDevice object."
                            } else {
                                #this seems idiotic, but it will help sanitize input. It's hard to validate that we're getting
                                #a CMDevice object from the pipeline
                                Try {
                                    $Device = Get-cmdevice -ResourceId $InputObject.ResourceID -Fast
                                } Catch {
                                    Throw "Unable to validate InputObject.`n$($_.exception.message)"
                                }
                            }

                        }#DeviceObject

        "ByName"      {

                            Write-Debug "Using ComputerName to validate the device."

                            #No wildcard searches.
                            if ($ComputerName -match "\*") {
                                Write-Debug "User used a wildcard in the ComputerName. Erroring Out."
                                Throw "No Wildcards, please."
                            }

                            Try {
                                $Device = Get-cmdevice -Name $ComputerName -Fast
                            } Catch {
                                Write-Debug "Couldn't query SCCM."
                                Throw "Failed to query SCCM for device named $ComputerName.`n$($_.exception.message)"
                            }

                            if ($Device -eq $null) {
                                Write-Debug "No results found for $ComputerName"
                                Throw "Failed to find a device named '$ComputerName'."
                            }

                       }#ByName

        "ByResourceID" {
                            Write-Debug "Using ResourceID to validate the device."
                            Try {
                                
                                $Device = Get-cmdevice -ResourceId $ResourceID -Fast
                            } Catch {
                                Write-Debug "Couldn't query SCCM."
                                Throw "Failed to query SCCM for device with ID $ResourceID.`n$($_.exception.message)"
                            }

                            if ($Device -eq $null) {
                                Write-Debug "No results found for $ResourceID"
                                Throw "Failed to find a device with ID '$ResourceID'."
                            }
                            
                            

                       }#ByResourceID

         
        Default {}
    }#Switch


    #WMI Query to find the names of the collections that the device is a member of
    Write-Verbose "Searching for collection names"
    $MembershipQry = "Select CollectionID from SMS_FullCollectionMembership where ResourceID = '$($Device.ResourceID)'"
    $collections = Get-zcmwmiquery -Query $MembershipQry


    #Add each collection that is found to an arraylist that will be returned when the cmdlet runs
    $membership = New-object -TypeName System.Collections.ArrayList
    $i = 0
    Write-Verbose "Processing Discovered Collections"                
    foreach ($Collection in $Collections)
    {

        $i ++
        Write-Progress -Activity "Parsing Collections" -Status "$i of $($Collections.Count)" -PercentComplete (($i / $collections.count)*100)

        $thisCol = Get-CMDeviceCollection -CollectionId $Collection.CollectionID
 	    $membership.add($thisCol) | out-null

                Write-Verbose "     $($thisCol.Name)"
    }


    if ($ShowPrettyOutput) {
        Write-Debug "User requested pretty output"
        Write-Output $membership | select-object -property Name, LastMemberChangeTime, LastRefreshTime | Sort-Object -Property Name | Format-Table
        $NoReturnObject = $true
    }

    if (!$NoReturnObject) {
        Return $membership
    }

 

}