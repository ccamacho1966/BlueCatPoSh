function Remove-BlueCatSOA {
<#
.SYNOPSIS
    Remove a Start of Authority definition
.DESCRIPTION
    The Remove-BlueCatSOA cmdlet allows the removal of Start of Authority definitions.
.PARAMETER Name
    A string value representing the FQDN of the zone to remove the Start of Authority from.
.PARAMETER ID
    An integer value representing the entity ID of the Start of Authority to be removed.
.PARAMETER Object
    A PSCustomObject representing the Start of Authority to be removed.
.PARAMETER ViewID
    An integer value representing the entity ID of the desired view.
.PARAMETER View
    A PSCustomObject representing the desired view.
.PARAMETER BlueCatSession
    A BlueCat object representing the session to be used for this object operation.
.EXAMPLE
    PS> Remove-BlueCatSOA -Name example.com

    Removes the Start of Authority for 'example.com'.
    BlueCatSession will default to the current default session.
    View will default to the BlueCatSession default view.
.EXAMPLE
    PS> Remove-BlueCatSOA -Name anotherzone.com -ViewID 23456 -BlueCatSession $Session3

    Removes the Start of Authority for 'anotherzone.com'.
    Use the BlueCatSession associated with $Session3 to perform this operation.
    The zone will be searched for in view 23456.
.EXAMPLE
    PS> Remove-BlueCatSOA -ID 10007

    Removes the Start of Authority with entity ID 10007.
    BlueCatSession will default to the current default session.
.EXAMPLE
    PS> $MySOA | Remove-BlueCatSOA

    Removes the Start of Authority represented by $MySOA which is passed on the pipeline.
    BlueCatSession will default to the current default session.
.INPUTS
    PSCustomObject representing the Start of Authority to be removed.
.OUTPUTS
    None
#>
        [CmdletBinding(DefaultParameterSetName='byID')]

    param(
        [Parameter(ParameterSetName='byID',Mandatory)]
        [ValidateRange(1, [int]::MaxValue)]
        [Alias('EntityID','SOAID','ZoneID')]
        [int] $ID,

        [Parameter(ParameterSetName='byObj',Mandatory,ValueFromPipeline)]
        [ValidateNotNullOrEmpty()]
        [Alias('Entity','SOA','Zone')]
        [PSCustomObject] $Object,

        [Parameter(ParameterSetName='byNameViewID',Mandatory)]
        [Parameter(ParameterSetName='byNameViewObj',Mandatory)]
        [ValidateNotNullOrEmpty()]
        [Alias('ZoneName')]
        [string] $Name,

        [Parameter(ParameterSetName='byNameViewID')]
        [ValidateRange(1, [int]::MaxValue)]
        [int] $ViewID,

        [Parameter(ParameterSetName='byNameViewObj',Mandatory)]
        [ValidateNotNullOrEmpty()]
        [PSCustomObject] $View,

        [Parameter()]
        [Alias('Connection','Session')]
        [BlueCat] $BlueCatSession = $Script:BlueCatSession
    )

    begin {
        Get-CallerPreference -Cmdlet $PSCmdlet -SessionState $ExecutionContext.SessionState
        if (-not $BlueCatSession) { throw 'No active BlueCatSession found' }
    }

    process {
        $thisFN = (Get-PSCallStack)[0].Command

        if ($ID) {
            # Convert the Entity ID into an Entity Object to use the object logic
            $Object = Get-BlueCatEntityById -ID $ID -BlueCatSession $BlueCatSession
        }

        if ($Name) {
            # Translate zone name into a zone object
            $SoaLookup = @{
                Name               = $Name
                BlueCatSession     = $BlueCatSession
            }
            if ($View) {
                $SoaLookup.View   = $View
            }
            if ($ViewID) {
                $SoaLookup.ViewID = $ViewID
            }
            $Object = Get-BlueCatSOA @SoaLookup
        }

        if (-not $Object) {
            if ($ID) {
                $FailureMessage = "$($thisFN): Failed to convert Entity ID #$($ID) to SOA Record"
            } else {
                $FailureMessage = "$($thisFN): Failed to convert Name '$($Name)' in View '$($View.name)' to SOA Record"
            }
            Write-Verbose $FailureMessage
            throw $FailureMessage
        }

        if (-not $Object.ID) {
            $FailureMessage = "$($thisFN): Invalid SOA Object"
            Write-Verbose $FailureMessage
            throw $FailureMessage
        }

        if ($Object.type -ne 'StartOfAuthority') {
            $FailureMessage = "$($thisFN): Not SOA Record - $($Object.Name) is type '$($Object.type)'"
            Write-Verbose $FailureMessage
            throw $FailureMessage
        }

        $DeleteSOA = @{
            ID             = $Object.ID
            BlueCatSession = $BlueCatSession
        }

        Write-Verbose "$($thisFN): Deleting SOA record for '$($Object.Name)' (ID:$($Object.ID))"
        Remove-BlueCatEntityById @DeleteSOA
    }
}
