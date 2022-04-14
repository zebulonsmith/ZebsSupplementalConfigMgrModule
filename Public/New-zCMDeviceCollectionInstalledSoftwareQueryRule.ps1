<#
.DESCRIPTION
This function will output the text of a query rule that can be used with a Device Collection.

The query rule will create a query against SMS_G_System_INSTALLED_SOFTWARE using the provided Product Name and (optionally) version.

Example Output:
select *  from  SMS_R_System
inner join SMS_G_System_INSTALLED_SOFTWARE on SMS_G_System_INSTALLED_SOFTWARE.ResourceId = SMS_R_System.ResourceId
where SMS_G_System_INSTALLED_SOFTWARE.ProductName = "Git"
and SMS_G_System_INSTALLED_SOFTWARE.ProductVersion = "11.4.7462.6"

.PARAMETER ProductName
The Product Name to search for in the SMS_G_System_INSTALLED_SOFTWARE table. Follow typical WMI query rules. '%' as a wildcard, '\' as an escape character, etc.

.PARAMETER ProductNameOperator
The comparison operator to use in the query. Valid options are Equals or Like. Defaults to 'Equals.'

.PARAMETER ProductVersion
Optionally, include a product version in the query.

.PARAMETER ProductVersionOperator
The comparison operator to use in the query. Valid options are Equals, GreaterThan, GreaterThanOrEquals, LessThan, LessThanOrEquals and Like. Defaults to Equals.

.EXAMPLE
#Output the text of a query to use for locating devices with 'Microsoft 365 Apps for enterprise - en-us' installed.
New-zCMDeviceCollectionInstalledSoftwareQueryRule -ProductName "Microsoft 365 Apps for enterprise - en-us"

.EXAMPLE
#Output the text of a query to use for locating devices with 'Microsoft 365 Apps for enterprise - en-us' version 16.0.14827.20220 installed
New-zCMDeviceCollectionInstalledSoftwareQueryRule -ProductName "Microsoft 365 Apps for enterprise - en-us" -Productversion 16.0.14827.20220


.EXAMPLE
#Create a device collection with a query to include devices with 'Microsoft 365 Apps for Enterprise%' version -Productversion '16.%' installed
$query = New-zCMDeviceCollectionInstalledSoftwareQueryRule -ProductName "Microsoft 365 Apps for enterprise%" -ProductNameOperator "like" -Productversion "16.%" -ProductVersionOperator "like"
New-zCMDeviceCollection -CollectionName "Collection Name" -LimitingCollectionName "All Desktop and Server Clients" -MembershipQueryRules $Query
#>



function New-zCMDeviceCollectionInstalledSoftwareQueryRule {
    param (
        #ProductName
        [Parameter(
            Mandatory=$true,
            HelpMessage="The Product Name to search for in the SMS_G_System_INSTALLED_SOFTWARE table. Follow typical WMI query rules. '%' as a wildcard, '\' as an escape character, etc."
            )
        ]
        [String]
        $ProductName,
        [Parameter(
            Mandatory=$false,
            HelpMessage="The operator to use against ProductName. Valid options are Equals or Like. Defaults to Equals."
            )
        ]
        [ValidateSet("Equals","Like")]
        [string]
        $ProductNameOperator = "Equals",

        #ProductVersion
        [Parameter(
            Mandatory=$false,
            HelpMessage="The Product Version to search for in the SMS_G_System_INSTALLED_SOFTWARE table. Follow typical WMI query rules. '%' as a wildcard, '\' as an escape character, etc."
            )
        ]
        [String]
        $ProductVersion,
        [Parameter(
            Mandatory=$false,
            HelpMessage="The operator to use against ProductVersion. Valid options are Equals, GreaterThan, GreaterThanOrEquals, LessThan, LessThanOrEquals and Like. Defaults to Equals. Defaults to Equals."
            )
        ]
        [ValidateSet("Equals","Like","GreaterThan","GreaterThanOrEquals","LessThan","LessThanOrEquals")]
        [string]
        $ProductVersionOperator = "Equals"
    )

    #Get an instance of the zCMWMIOperator class to help build the query
    $zCMStringToWMIOperator = [zCMStringToWMIOperator]::new()

    #Build the query
    $Query = "select *  from  SMS_R_System
    inner join SMS_G_System_INSTALLED_SOFTWARE on SMS_G_System_INSTALLED_SOFTWARE.ResourceId = SMS_R_System.ResourceId
    where SMS_G_System_INSTALLED_SOFTWARE.ProductName"

    $Query += " $($zCMStringToWMIOperator.StringToOperator($ProductNameOperator)) `"$($ProductName)`""

    if ($ProductVersion) {
        $Query += " and SMS_G_System_INSTALLED_SOFTWARE.ProductVersion $($zCMStringToWMIOperator.StringToOperator($ProductVersionOperator)) `"$($ProductVersion)`""
    }

    Return $Query

}

