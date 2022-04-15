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

Function Convert-zCMDateTimeFromWMITime {
    Param (
        # DateTimeObject
        [Parameter(Mandatory=$true, ValueFromPipeline=$true)]
        [String]
        $WMITime
    )


    #Convert to the standard DMTF format used by WMI.
    $dateTime = [System.Management.ManagementDateTimeConverter]::ToDateTime($WMITime)

    Return $dateTime

}