<#
Translates 'Friendly' operator names into their equivalent in WMI.

For example 'Equals' becomes '='
#>


class zCMStringToWMIOperator {

    static $Operators = @{
        "Equals"                = "="
        "Like"                  = "like"
        "GreaterThan"           = ">"
        "GreaterThanOrEquals"   = ">="
        "LessThan"              = "<"
        "LessThanOrEquals"      = "<="
    }

    [Hashtable] GetOperators() {

        Return [zCMStringToWMIOperator]::Operators
    }


    [string] StringToOperator([STRING]$OperatorString) {

        $TheseOperators = [zCMStringToWMIOperator]::Operators

        if ( !($TheseOperators.keys -contains $OperatorString) ) {
            Write-Warning "OperatorString must be one of $($TheseOperators.Keys -join ", ")"
        }
        Return $TheseOperators.$OperatorString
    }
}

