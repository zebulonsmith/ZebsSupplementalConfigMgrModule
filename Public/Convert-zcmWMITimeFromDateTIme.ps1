<#
.DESCRIPTION
Converts a standard DateTime to the rounded UTC DMTF time format used in SCCM. Needed for many WMI/SQL queries.


.PARAMETER DateTime
DateTime object to be converted. Will accept pipeline input

.EXAMPLE
Get-Date | Convert-zCMWMITimeFromDateTime

.EXAMPLE
Convert-zCMWMITimeFromDateTIMe -DateTime (Get-Date "7/4/1776")
#>

Function Convert-zCMWMITimeFromDateTime {
    Param (
        # DateTimeObject
        [Parameter(Mandatory=$true, ValueFromPipeline=$true)]
        [DateTime]
        $DateTime
    )


    #Convert to the standard DMTF format used by WMI.
    $WMITime = [System.Management.ManagementDateTimeConverter]::ToDmtfDateTime($DateTime)

    Return $WMITime

}