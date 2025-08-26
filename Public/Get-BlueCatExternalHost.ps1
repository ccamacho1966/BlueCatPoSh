function Get-BlueCatExternalHost {
<#
.SYNOPSIS
    Retrieve an external host record
.DESCRIPTION
    The Get-BlueCatExternalHost cmdlet allows the retrieval of external host records.
.PARAMETER Name
    A string value representing the FQDN of the external host to be retrieved.
.PARAMETER ViewID
    An integer value representing the entity ID of the desired view.
.PARAMETER View
    A PSCustomObject representing the desired view.
.PARAMETER BlueCatSession
    A BlueCat object representing the session to be used for this object lookup.
.EXAMPLE
    PS> Get-BlueCatExternalHost -Name 'autodiscover.outlook.com'

    Returns a PSCustomObject representing the external host, or NULL if not found.
    BlueCatSession will default to the current default session.
    View will default to the BlueCatSession default view.
.EXAMPLE
    PS> Get-BlueCatExternalHost -Name 'sendgrid.net' -ViewID 23456 -BlueCatSession $Session9

    Returns a PSCustomObject representing the external host, or NULL if not found.
    Use the BlueCatSession associated with $Session9 to perform this lookup.
    The record will be searched for in view 23456.
.INPUTS
    None
.OUTPUTS
    PSCustomObject representing the requested alias, or NULL if not found.

    [int] id
    [string] name
    [string] type = 'ExternalHostRecord'
    [PSCustomObject] config
    [PSCustomObject] view
#>
    [CmdletBinding(DefaultParameterSetName='ViewID')]

    param(
        [Parameter(Mandatory, ValueFromPipeline)]
        [Alias('ExternalHost')]
        [string] $Name,

        [Parameter(ParameterSetName='ViewID')]
        [ValidateRange(1, [int]::MaxValue)]
        [int] $ViewID,

        [Parameter(ParameterSetName='ViewObj',Mandatory)]
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

        if ($ViewID) {
            $View = Get-BlueCatView -ViewID $ViewID -BlueCatSession $BlueCatSession
        } elseif (-not $View) {
            # No View or ViewID has been passed in so attempt to use the default view
            $BlueCatSession | Confirm-Settings -View
            Write-Verbose "$($thisFN): Using default view '$($BlueCatSession.View.name)' (ID:$($BlueCatSession.View.id))"
            $View = $BlueCatSession.View
        }

        if (-not $View) {
            throw "$($thisFN): View could not be resolved"
        }

        if (-not $View.ID) {
            # This is not a valid object!
            throw "$($thisFN): Invalid View object passed to function!"
        }

        if ($View.type -ne 'View') {
            throw "$($thisFN): Object is not a View (ID:$($View.ID) $($View.name) is a $($View.type))"
        }

        $xHost = $Name | Test-ValidFQDN

        $Query = "getEntityByName?parentId=$($View.id)&name=$($xHost)&type=ExternalHostRecord"
        $BlueCatReply = Invoke-BlueCatApi -Method Get -Request $Query -BlueCatSession $BlueCatSession

        if (-not $BlueCatReply.id) {
            # Record not found. Return nothing/null.
            Write-Verbose "$($thisFN): External Host Record for '$($xHost)' not found: $($BlueCatReply)"
        } else {
            # Found the external host - return the result
            Write-Verbose "$($thisFN): Selected #$($BlueCatReply.id) as '$($BlueCatReply.name)'"

            # Build the full object and return
            $BlueCatObj = [PSCustomObject] @{
                id     = $BlueCatReply.id
                name   = $BlueCatReply.name
                type   = $BlueCatReply.type
                view   = $View
                config = $View.config
            }

            $BlueCatObj
        }
    }
}
