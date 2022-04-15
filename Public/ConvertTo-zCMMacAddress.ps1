<#
.DESCRIPTION
Used internally to convert mac address strings of any format to the "aa:bb:cc:dd:ee:ff" format used by ConfigMgr.
Special characters are removed, then colons are inserted at the appropriate points and the entire string is validated via regex.
Will fail with System.FormatException if the input string cannot be converted.

.PARAMETER MacAddress
Mac Address string to process.

.EXAMPLE
"This?Will,Fail" | ConvertTo-zCMMacAddress

.EXAMPLE
"11-aa-BB-33-44:66" | ConvertTo-zCMMacAddress
#>
Function ConvertTo-zCMMacAddress {
    Param (
        # Mac Address String
        [Parameter(Mandatory=$true,ValueFromPipeline)]
        [string]
        $MacAddress
    )
    Begin {
        $results = New-object System.Collections.ArrayList
    }

    Process {
        Write-Verbose "Processing $MacAddress"

        Write-Verbose "Removing Special Characters"
        $newmac = $MacAddress -replace '[\W]',''

        Write-Debug "New Value is: $newmac"

        #Bomb out if the mac was nothing but special characters.
        if ($newmac.Length -eq 0) {
            #Throwing a format exception error so that we can process based on the thrown object later, if need be.
            Throw [System.FormatException]::new("The provided MAC address is invalid. Please use the format 'aa:bb:cc:dd:ee:ff'")
        }

        #Insert Colons
        Write-Verbose "Inserting colons"
        $newmac = $newmac.Insert(10,":").Insert(8,":").Insert(6,":").Insert(4,":").Insert(2,":")
        Write-Debug "New Value is: $newmac"

        #Regex match to verify that the final result is a valid mac
        if (!($newmac -match "^(([a-fA-F0-9]{2}[:]){5}[a-fA-F0-9]{2})$")) {
            Write-Verbose "Mac $newmac is not valid"
            Throw [System.FormatException]::new("The provided MAC address is invalid. Please use the format 'aa:bb:cc:dd:ee:ff'")
        } else {
            Write-Verbose "Mac $newmac passed validation. Will be returned."
            $results.add($newmac) | out-null
        }

    }#Process
    End {
        return $results
    }
}