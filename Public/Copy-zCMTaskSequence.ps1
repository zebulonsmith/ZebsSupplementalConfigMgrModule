<#
.DESCRIPTION
Copies a Task Sequence, sets Security Scopes and moves the destination object to a new location.
Condenses tasks commonly associated with the creation of a new Task Sequence into one command.
Security Scopes and a destination folder may all be specified by using the appropriate parameters.

.PARAMETER InputObject
A Source Task Sequence to be copied as a CMTaskSequence object. May be provided via pipeline

.PARAMETER SourceTaskSequenceName
Provide the Source Task Sequence by name

.PARAMETER SourceTaskSequenceID
Provide the source Task Sequence by PackageID

.PARAMETER DestinationTaskSequenceName
Name for the destination Task Sequence

.PARAMETER DestinationFolderPath
Optional folder that the Package will be moved to after creation

.PARAMETER DeleteOnFailure
When specified, the new Package will be deleted if any critical part of the creation and configuration fails.

.PARAMETER SecurityScopeNames
Optional array of Security Scope names that should be assigned to the new Task Sequence

.PARAMETER SiteInfo
An instance of zCMSiteInfo representing the SCCM Site Server to query against. Can be created via [zCMSiteInfo]::new() or by using New-zCMSiteServerObject. 
Will be created using default configuration if not specified, which will work fine in most situations.

.EXAMPLE
#Copy a Task Sequence named 'Source Task Sequence Name' to 'New Task Sequence', apply Security scopes 'Scope A' and 'Scope B', move to 'CCM:\TaskSequence\Folder\' and delete any partially created object if the process fails.
(Get-CMTaskSequence -name "Source Task SequenceName") | Copy-zCMTaskSequence -DestinationTaskSequenceName "New Task Sequence" -SecurityScopeNames "Scope A","Scope B" -DestinationFolderPath "CCM:\TaskSequence\Folder\" -DeleteOnFailure

.EXAMPLE
#Copy Task Sequence 'Source Task Sequence' to 'New Task Sequence' do not add security scopes or move
Copy-zCMTaskSequence -SourceTaskSequenceName 'Source Task Sequence' -DestinationTaskSequenceName 'New Task Sequence' -DeleteOnFailure

.EXAMPLE
#Copy Task Sequence 'Source Task Sequence' to 'New Task Sequence' do not add security scopes or move using server 'MyServer' in site 'CCM'
Copy-zCMTaskSequence -SourceTaskSequenceName 'Source Task Sequence' -DestinationTaskSequenceName 'New Task Sequence' -DeleteOnFailure -SiteInfo (New-zCMSiteServerObject -SCCMSiteServerName "MyServer" -SCCMSiteCode "CCM")
#>
Function Copy-zCMTaskSequence {
    Param (
        # Source Task Sequence as a CMTaskSequence object
        [Parameter(ParameterSetName="ByObject",ValueFromPipeline)]
        $InputObject,

        # Source Task Sequence by Name
        [Parameter(ParameterSetName="ByName")]
        [string]
        $SourceTaskSequenceName,

        # Source Task Sequence by ID
        [Parameter(ParameterSetName="ByID")]
        [string]
        $SourceTaskSequencePackageID,

        # Destination Task Sequence Name
        [Parameter(Mandatory=$true)]
        [string]
        $DestinationTaskSequenceName,

        # Add one or more security scopes to the Task Sequence
        [Parameter(Mandatory=$false)]
        [string[]]
        $SecurityScopeNames,

        # Destination folder to move the Task Sequence to after creation
        [Parameter(Mandatory=$false)]
        [string]
        $DestinationFolderPath,

        # Attempt to delete the object if it is not created properly
        [Parameter(mandatory=$false)]
        [switch]
        $DeleteOnFailure,

        # Instance zCMSiteInfo class. Only needs to be set when the site server needs to be specified
        [Parameter(Mandatory=$false)]
        [zCMSiteInfo]
        $SiteInfo = [zCMSiteInfo]::new()
    )

    #Make sure that we have the ConfigMgr Module Loaded and are connected to a CM PS Drive
    try {
        $SiteInfo | Test-zCMPSDrive
    }
    catch {
        Throw $_
    }

    #Verify that the destination path exists if it's specified. Throw an error if it doesn't exist.
    if ($DestinationFolderPath) {
        Write-Verbose "Validating path $DestinationFolderPath"
        if ( !(Test-Path $DestinationFolderPath) ) {
            Write-Error "Path '$DestinationFolderPath' does not exist or cannot be reached."
            Throw $_
        }
    }

    #Get $SourceTS as a CMTaskSequence object based on which parameterset is used
    Write-Verbose "Validating that Source Task Sequence exists"
    switch  ($PSCmdlet.ParameterSetName) {
        "ByObject" {
            $SourceTS = $InputObject
        }#ByObject

        "ByName" {
            try {
               $SourceTS = Get-CMTaskSequence -Name $SourceTaskSequenceName
            }
            catch {
               Write-Error "Unable to find a Task Sequence named $SourceTaskSequenceName"
               Throw $_ 
            }
        }#ByName

        "ByID" {
            try {
                $SourceTS = Get-CMTaskSequence -TaskSequencePackageId $SourceTaskSequencePackageID
            }
            catch {
                Write-Error "Unable to find a Task Sequence with PackageID $SourceTaskSequencePackageID"
                Throw $_
            }
        }#ByID
    }#Switch

    #If we can't resolve the Source Task Sequence, throw an error
    if ($null -eq $SourceTS) {
        Throw "Unable to locate the specified Source Task Sequence."
    }


    #Validate that the specified Security Scopes exist and add them to an array
    if ($SecurityScopeNames) {
        Try {
            $SecurityScopes = $SecurityScopeNames | Test-zCMSecurityScope -SiteInfo $SiteInfo
        } Catch {
            Throw $_
        }
    }

    #Make sure that a Task Sequence with the same name as the $SourceTaskSequenceName doesn't exist
    try {
        $TestTS = Get-CMTaskSequence -Name $DestinationTaskSequenceName
    }
    catch {
        Write-Error "Unable to validate existence of destination Task Sequence '$DestinationTaskSequenceName'"
        Throw $_
    }
    if ($TestTS) {
        Throw "A Task Sequence named '$DestinationTaskSequenceName' already exists."
    }


    #If all validation tests pass, copy the Task Sequence
    try {
        $DestinationTS = $SourceTS | Copy-CMTaskSequence
    }
    catch {
        Write-Error "Unable to copy Task Sequence"
        Throw $_
    }

    #Rename the new Task Sequence
    try {
        Write-Verbose "Setting new Task Sequence Name"
        $DestinationTS | Set-CMTaskSequence -NewName $DestinationTaskSequenceName 
    }
    catch {
        Write-Error "Unable to change Task Sequence Name"
        if ($DeleteOnFailure) {
            Write-Verbose "Attempting to delete."
            $DestinationTS | Remove-CMTaskSequence
        }
        Throw $_
    }

    #Assign Security Scopes
    Foreach ($Scope in $SecurityScopes) {
        Write-Verbose "Assigning Security Scope '$($Scope.CategoryName)'"
        try {
            $DestinationTS | Add-CMObjectSecurityScope -Scope $Scope
        }
        catch {
            Write-Error "Unable to add scope $($Scope.CategoryName)"
            if ($DeleteOnFailure) {
                Write-Verbose "Attempting to delete."
                $DestinationTS | Remove-CMTaskSequence
            }
            Throw $_
        }
    }

    #Move the Task Sequence to the destination folder
    if ($DestinationFolderPath) {
        Write-Verbose "Moving '$DestinationTS' to '$DestinationFolderPath'"
        try {
            $DestinationTS | Move-CMObject -FolderPath $DestinationFolderPath
        }
        catch {
            Write-Error "Unable to move $DestinationTS"
            if ($DeleteOnFailure) {
                Write-Verbose "Attempting to delete."
                $DestinationTS | Remove-CMTaskSequence
            }
            Throw $_
        }
    }

    #Get a fresh copy of the newly created Task Sequence to return
    return (Get-CMTaskSequence -name $DestinationTaskSequenceName)

}