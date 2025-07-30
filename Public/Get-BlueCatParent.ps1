function Get-BlueCatParent {
<#
.SYNOPSIS
    Retrieve a Host record (A/AAAA)
.DESCRIPTION
    The Get-BlueCatHost cmdlet allows the retrieval of DNS A and AAAA records.
.PARAMETER ID
    An integer value representing the ID of the entity.
.PARAMETER Object
    A PSCustomObject representing the entity.
.PARAMETER BlueCatSession
    A BlueCat object representing the session to be used for this lookup.
.EXAMPLE
    PS> Get-BlueCatParent -ID 101267

    Returns a PSCustomObject representing the parent entity, or NULL if not found.
    BlueCatSession will default to the current default session.
.EXAMPLE
    PS> Get-BlueCatParent -Object $MyObject -BlueCatSession $Session4

    Returns a PSCustomObject representing the parent entity, or NULL if not found.
    Use the BlueCatSession associated with $Session4 to perform this lookup.
.INPUTS
    None
.OUTPUTS
    PSCustomObject representing the parent entity, or NULL if not found.
#>
    [CmdletBinding()]

    param(
        [Parameter(ParameterSetName='byID',Mandatory)]
        [ValidateRange(1, [int]::MaxValue)]
        [Alias('EntityID')]
        [int] $ID,

        [Parameter(ParameterSetName='byObj',Mandatory,ValueFromPipeline)]
        [ValidateNotNullOrEmpty()]
        [Alias('Entity')]
        [PSCustomObject] $Object,

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

        if (-not $ID) {
            if (-not $Object.id) {
                throw "$($thisFN): Invalid entity object"
            }
            $ID = $Object.id
        }

        $Query        = "getParent?entityId=$($ID)"
        $BlueCatReply = Invoke-BlueCatApi -BlueCatSession $BlueCatSession -Method Get -Request $Query
        if ($BlueCatReply.id) {
            $BlueCatReply | Convert-BlueCatReply -BlueCatSession $BlueCatSession
        }
    }
}
