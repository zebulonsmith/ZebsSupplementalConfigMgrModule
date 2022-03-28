<#
.DESCRIPTION
Retrieves a UserGroup Resource based on search parameters.
At the time of the creation of this module, there's no cmdlet in Microsoft's ConfigurationManager module to do this.

Assumes that the user account executing the command can load the Microsoft ConfigurationManager module and is assigned a role with
permission to read UserGroup Resources unless -ReturnWMIQuery is specified. In that case, the function will only build and return
a query to pass to Get-zCMWMIQuery.

This was written because, at the time of writing, a cmdlet did not exist in the Microsoft ConfigurationManager module to provide the
same functionality. A very common use case for a User Collection is to add a UserGroup resource as a direct member. This cmdlet will
facilitate that. (See examples.)

.PARAMETER Name
Search for UserGroups by their name in Config Manager. Use '%' as a wildcard. Be sure to follow typical WMI query rules regarding escape characters.
'Domain\GroupName' is invalid because '\' is an escape character. Instead use 'Domain\\GroupName'

.Parameter GroupType
Optionally, specify either ActiveDirectory or AzureAD to filter down results when searching by Name.

.PARAMETER ResourceID
Retrieve a UserGroup using the ResourceID.

.PARAMETER ReturnWMIQuery
Instead of returning CMResource objects based on the search criteria, the function will return the text of a WMI query that can be
passed to Get-zCMWMIQuery. This is useful when the Microsoft ConfigurationManager module isn't available.

.PARAMETER SiteInfo
An instance of zCMSiteInfo representing the SCCM Site Server to query against. Will be created using default configuration if not specified.

.EXAMPLE
#Find all UserGroup resources with a name that starts with 'Accounting'
Get-zCMUserGroupResource -Name "Accounting%"

.EXAMPLE
#Find all UserGroup resources associated with an AzureAD group with a name that starts with 'Accounting'
Get-zCMUserGroupResource -Name "Accounting%" -GroupType AzureAD

.EXAMPLE
#Find the UserGroup with ResourceID 1234567890
Get-zCMUserGroupResource -ResourceID 1234567890

.EXAMPLE
#Find all UserGroup resources with a name that starts with 'Accounting' and query Config Manager directly for results via WMI/CIM.
Get-zcmUserGroupResource -Name 'Accounting%' -ReturnWMIQuery | Invoke-zCMWMIQuery

.EXAMPLE
#Create a user collection called 'Accounting Users' and add the 'Domain\AccountingUsers' UserGroup Resource as a direct member.
New-zCMUserCollection -CollectionName "Accounting Users" -LimitingCollectionName "All Users and User Groups" | % {Add-CMUserCollectionDirectMembershipRule -CollectionId $_.CollectionID -ResourceId (Get-zCMUserGroupResource -Name 'Domain\\Accounting Users').ResourceID}
#>

function Get-zCMUserGroupResource {
    [CmdletBinding()]

    param (
       [Parameter(
            Mandatory=$false,
            HelpMessage="Name of the Group ('Name' column in Config Manager Console) to search for. Accepts '%' as a wildcard.",
            ParameterSetName="SearchCriteriaName"
            )
        ]
        [String]
        $Name,

        [Parameter(
            Mandatory=$false,
            HelpMessage="Retrieve a UserGroup resource by ResourceID",
            ParameterSetName="SearchCriteriaResourceID"
            )
        ]
        [string]
        $ResourceID,

        [Parameter(
            Mandatory=$false,
            HelpMessage="Type of group to search for when using the 'Name' parameter. Filters results to groups found in either Local Active Directory or AzureAD",
            ParameterSetName="SearchCriteriaName"
            )
        ]
        [ValidateSet("ActiveDirectory","AzureAD")]
        [String]
        $GroupType,


        [Parameter(
            Mandatory=$false,
            HelpMessage="If specified, will build and return the WMI query used to search for the UserGroup Resource which can be passed on to Get-zCMWMIQuery. Useful when the MS ConfigurationManager module is not available."
            )
        ]
        [switch]
        $ReturnWMIQuery,

        [Parameter(
            Mandatory=$false,
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

    #Build the WMI query that will be used to search for the UserGroup Resource
    switch ($PSCmdlet.ParameterSetName) {
        "SearchCriteriaName"        {$WhereClause = " where name like '$($Name)'"  }
        "SearchCriteriaResourceID"  {$WhereClause = " where ResourceID = '$($ResourceID)'"}
        Default                     {$WhereClause = ""}
    }

    switch ($GroupType) {
        "ActiveDirectory"   {$WhereClause += " and AGENTNAME = 'SMS_AD_SECURITY_GROUP_DISCOVERY_AGENT'"}
        "AzureAD"           {$WhereClause += " and AGENTNAME = 'SMS_AZUREAD_USER_GROUP_DISCOVERY_AGENT'"}
        Default {}
    }

    $qry = "Select * from SMS_R_UserGroup" + $WhereClause


    if ($ReturnWMIQuery) {
        Return $qry
    }

    Try {
        $FoundResources = Invoke-zCMWMIQUery -query $qry -siteinfo $SiteInfo
    } Catch {
        Throw $_
    }

    $ReturnList = New-Object 'System.Collections.Generic.List[PSObject]'
    Foreach ($resource in $FoundResources) {
        $thisCMResource = Get-cmresource -ResourceID $resource.ResourceID -fast
        $ReturnList.add($thisCMResource)
    }

    Return $ReturnList

}