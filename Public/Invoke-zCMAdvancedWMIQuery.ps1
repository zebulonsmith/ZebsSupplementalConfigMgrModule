<#
.DESCRIPTION
Extends the functionality in Get-zCMWMIQuery to let us limit the scope of a query to a specific collection using
native Configuration Manager functionality. Also retrieves "nicer" results for queries using Extended WQL or 'Special Queries' than other
methods.
https://docs.microsoft.com/en-us/mem/configmgr/develop/core/understand/extended-wmi-query-language
https://docs.microsoft.com/en-us/mem/configmgr/develop/core/understand/special-queries

Requires that the Configuration Manager console is installed as it leverages the
WqlQueryEngine provider in C:\Program Files (x86)\Microsoft Endpoint Manager\AdminConsole\bin\adminui.wqlqueryengine.dll

This method is slower than Invoke-CMWmiQuery and Invoke-zCMWMIQuery, but has the advantage that it can be scoped to a collection.

To see the differences in what's returned, try the following. Be sure to execute each query cmdlet one at a time so that the
differences can be seen.

$query = "Select DISTINCT resourceID from sms_r_system where name = '$($env:computername)'"

Invoke-zCMWMIQuery -Query $query

Invoke-zCMAdvancedWMIQuery -Query $query

Invoke-CMWmiQuery -Query $query

.PARAMETER Query
The WQL query to execute. Can be passed via the pipeline.

.PARAMETER CollectionName
Limit results to members of the named collection

.PARAMETER CollectionID
Limit results to members of the collection with this ID

.PARAMETER SiteInfo
An instance of zCMSiteInfo representing the SCCM Site Server to query against. Will be created using default configuration if not specified.

.EXAMPLE
#Query all devices
$query = New-zCMDeviceCollectionInstalledSoftwareQueryRule -ProductName "%Office%" -ProductNameOperator "like"
Invoke-zCMAdvancedWMIQuery -Query $query

.EXAMPLE
#Query only the 'Accounting Computers' collection
"Select * from SMS_R_System" | Invoke-zCMAdvancedWMIQuery -Query $query -CollectionName "Accounting Computers"

.EXAMPLE
#Query devices from the collection ZEB000001
"Select * from SMS_R_System" | Invoke-zCMAdvancedWMIQuery -Query $query -CollectionID "ZEB000001"
#>


function Invoke-zCMAdvancedWMIQuery {
    [CmdletBinding(DefaultParameterSetName='Default')]
    param (
        [Parameter(
            Mandatory=$true,
            ParameterSetName="CollectionID",
            ValueFromPipeline=$true,
            HelpMessage="Query to execute against Configuration Manager."
            )
        ]
        [Parameter(
            Mandatory=$true,
            ParameterSetName="CollectionName",
            ValueFromPipeline=$true,
            HelpMessage="Query to execute against Configuration Manager."
            )
        ]
        [Parameter(
            Mandatory=$true,
            ParameterSetName="Default",
            ValueFromPipeline=$true,
            HelpMessage="Query to execute against Configuration Manager."
            )
        ]
        [string]$Query,

        [Parameter(
            Mandatory=$false,
            ParameterSetName="CollectionID",
            HelpMessage="Specify a Collection ID to limit query results to only include inventory data from devices in that collection."
            )
        ]
        [STRING]$CollectionID,

        [Parameter(
            Mandatory=$false,
            ParameterSetName="CollectionName",
            HelpMessage="Specify a Collection Name to limit query results to only include inventory data from devices in that collection."
            )
        ]
        [STRING]$CollectionName,

        [Parameter(
            Mandatory=$false,
            ParameterSetName="CollectionID",
            HelpMessage="Instance zCMSiteInfo class. Only needs to be set when the site server needs to be specified, otherwise the site server associated with the current user's Configuration Manager console settings."
            )
        ]
        [Parameter(
            Mandatory=$false,
            ParameterSetName="CollectionName",
            HelpMessage="Instance zCMSiteInfo class. Only needs to be set when the site server needs to be specified, otherwise the site server associated with the current user's Configuration Manager console settings."
            )
        ]
        [Parameter(
            Mandatory=$false,
            ParameterSetName="Default",
            HelpMessage="Instance zCMSiteInfo class. Only needs to be set when the site server needs to be specified, otherwise the site server associated with the current user's Configuration Manager console settings."
            )
        ]
        [zCMSiteInfo]$SiteInfo = [zCMSiteInfo]::new()
    )

    #Make sure that we have the ConfigMgr Module Loaded and are connected to a CM PS Drive
    try {
        $SiteInfo | Test-zCMPSDrive
    }
    catch {
        Throw $_
    }

    #Import the adminui.wqlqueryengine assembly
    $dllplath = "$(split-path $env:SMS_ADMIN_UI_PATH -Parent)\AdminUI.WqlQueryEngine.dll"

    if (test-path $dllplath) {
        Try {
            add-type -Path $dllplath
        } catch {
            throw $_
        }
    } else {
        throw [System.IO.FileNotFoundException]::New("Could not find $dllplath")
    }

    <#
    Create an instance of Microsoft.ConfigurationManagement.ManagementProvider.WqlQueryEngine.WqlConnectionManager.
    I wish I had more info about how this works. I had many beers one night, did a lot of searching and found an old
    technet post about someone doing it for SMS 2007 with vbscript and turned it into some rough powershell, then
    fixed it later when I had more faculties. The post was lost forever because I was searching for things in DuckDuckGo
    on my tablet like an idiot. If anyone knows where I can find out more about this kind of thing, I'd love to chat.
    #>
    Try {
        $objSCCM = New-Object -TypeName Microsoft.ConfigurationManagement.ManagementProvider.WqlQueryEngine.WqlConnectionManager
    } Catch {
        Throw $_
    }

    #Connect to the site server
    Try {
        [void]$objSCCM.Connect($SiteInfo.SCCMServer)
    } Catch {
        Throw $_
    }

    #Limit the query to the specified collection
    if ($CollectionID -or $collectionName) {
        switch ($PSCmdlet.ParameterSetname) {
            "CollectionName" {$collection = Get-CMCollection -Name $CollectionName}
            "CollectionID"   {$collection = Get-CMCollection -CollectionId $CollectionID}
        }

        if ($null -eq $collection) {
            Throw "The specified collection does not exist."
        } else {
            #This must be an array!
            [String[]]$LimitToCollectionID[0] = "$($collection.CollectionID)"
        }

        Try {
            $objSCCM.context.clear()
            $objSCCM.Context.add("LimitToCollectionIDs",$LimitToCollectionID)
        } catch {
            Throw $_
        }
    }

    #Execute the query

    Try {
        $objQuery = $objSCCM.QueryProcessor.ExecuteQuery($Query)
    } Catch {
        Throw $_
    }


    $results = New-Object System.Collections.Generic.List[PSObject]

    #Get the enumerator

    $enum = $objQuery.GetEnumerator()


    #Foreach loop to go through each object in the enumerator and parse the output into an object
    Foreach ($item in $enum) {
        $thisResult = [PSCustomObject]@{}

        #Build up the thisResult object by using the get_item method
        $properties = $enum.current.propertylist.keys -split "`n"
        Foreach ($property in $properties) {
            $propertyValue = $item.get_item($property).objectvalue
            $thisResult | Add-member -MemberType NoteProperty -Name $property -Value $propertyValue
        }

        [void]$results.Add($thisResult)
    }

    $objQuery.Dispose()
    $objSCCM.Dispose()
    Return $results
}

