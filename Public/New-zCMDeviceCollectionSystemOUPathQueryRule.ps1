<#
.DESCRIPTION
This function will output the text of a query rule that can be used with a Device Collection.

The query rule will include any devices whos Active Directory computer objects are found within the
specified Organizational Unit according to the value in SMS_R_System.SystemOUName.

.PARAMETER OUPath
Path to the OU to use in the query. Use the format 'Domain.com/path/to/OU' Follow typical WMI query rules. '%' as a wildcard, '\' as an escape character, etc.

.PARAMETER Operator
The comparison operator to use in the query. Either 'Equals' or 'Like.' Defaults to 'Equals.'

.EXAMPLE
#Output the text of a query to use for locating devices in the 'Domain.com/Path/To/Computers' OU.
New-zCMDeviceCollectionSystemOUPathQueryRUle -OUPath "Domain.com/Path/To/Computers"

.EXAMPLE
#Create a device collection with a query to include devices in the Domain.com/Path/To/Computers
New-zCMDeviceCollection -CollectionName "Collection Name" -LimitingCollectionName "All Desktop and Server Clients" -MembershipQueryRules (New-zCMDeviceCollectionSystemOUPathQueryRUle -OUPath "Domain.com/Path/To/Computers")
#>



function New-zCMDeviceCollectionSystemOUPathQueryRule {
    param (

        [Parameter(
            Mandatory=$true,
            HelpMessage="The path of the OU to target in the format 'Domain.com/Path/To/OU' Follow typical WMI query rules. '%' as a wildcard, '\' as an escape character, etc."
            )
        ]
        [String]
        $OUPath,

        [Parameter(
            Mandatory=$false,
            HelpMessage="The comparison operator to use in the query. Either 'Equals' or 'Like.' Defaults to 'Equals.'"
            )
        ]
        [ValidateSet("Equals","Like")]
        [String]
        $OUPathOperator = "Equals"
    )
    #Get an instance of the zCMWMIOperator class to help build the query
    $zCMStringToWMIOperator = [zCMStringToWMIOperator]::new()

    Return "select * from SMS_R_System where SMS_R_System.SystemOUName $($zCMStringToWMIOperator.StringToOperator($OUPathOperator)) `"$($OUPath)`""


}

