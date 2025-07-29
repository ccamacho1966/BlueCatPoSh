function Get-BlueCatEntityById {
<#
.SYNOPSIS
    Retrieve BlueCat Entity by its Entity ID (API Call: getEntityById)
.DESCRIPTION
    The Get-BlueCatEntityById cmdlet allows the retrieval of a specific BlueCat entity by its Entity ID.
.PARAMETER ID
    An integer value that represents the entity ID of object to be retrieved.
.PARAMETER BlueCatSession
    A BlueCat object representing the session to be used for this object lookup.
.EXAMPLE
    PS> Get-BlueCatEntityById -ID 105127

    Returns a PSCustomObject representing the specific Entity ID.
    A null value is returned if the Entity ID does not exist.
    BlueCatSession will default to the current default session.
.EXAMPLE
    PS> Get-BlueCatEntityById -ID 105272 -BlueCatSession $Session7

    Returns a PSCustomObject representing the specific Entity ID.
    A null value is returned if the Entity ID does not exist.
    BlueCatSession $Session7 will be used to perform the lookup.
.INPUTS
    None
.OUTPUTS
    PSCustomObject representing BlueCat entity, or NULL if not found.
#>
    [CmdletBinding()]

    param(
        [parameter(Mandatory)]
        [Alias('EntityID')]
        [ValidateRange(1, [int]::MaxValue)]
        [int] $ID,

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

        Write-Verbose "$($thisFN): ID='$($ID)'"

        $Query = "getEntityById?id=$($ID)"
        $BlueCatReply = Invoke-BlueCatApi -Method Get -Request $Query -BlueCatSession $BlueCatSession

        if (-not $BlueCatReply.id) {
            Write-Verbose "$($thisFN): ID #$($ID) not found: $($BlueCatReply)"
            throw "Entity Id $($ID) not found: $($BlueCatReply)"
        }
        Write-Verbose "$($thisFN): Selected $($BlueCatReply.type) #$($BlueCatReply.id) as $($BlueCatReply.name)"

        $BlueCatReply | Convert-BlueCatReply -BlueCatSession $BlueCatSession
    }
}
