$script:ModuleName = 'ZebsSupplimentalConfigMgrModule'

##Import Classes
if (Test-Path "$PSScriptRoot\Classes\classes.psd1") {
    $ClassLoadOrder = Import-PowerShellDataFile -Path "$PSScriptRoot\Classes\classes.psd1" -ErrorAction SilentlyContinue
}

foreach ($class in $ClassLoadOrder.order) {
    $path = "$PSScriptRoot\classes\$class.ps1"
    if (Test-Path $path) {
        Write-Verbose "Importing class from $($path)"
        . $path
    }
}

#Get public and private function definition files.
$Public  = @( Get-ChildItem -Path $PSScriptRoot\Public\*.ps1 -ErrorAction SilentlyContinue )
$Private = @( Get-ChildItem -Path $PSScriptRoot\Private\*.ps1 -ErrorAction SilentlyContinue )

#Dot source the files
Foreach($import in @($Public + $Private))
{
    Try
    {
        Write-Verbose "Importing $($Import.FullName)"
        . $import.fullname
    }
    Catch
    {
        Write-Error -Message "Failed to import function $($import.fullname): $_"
    }
}

Export-ModuleMember -Function $Public.Basename

