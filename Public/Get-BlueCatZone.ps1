function Get-BlueCatZone {
 <#
.SYNOPSIS
    Retrieve a DNS Zone definition
.DESCRIPTION
    The Get-BlueCatHost cmdlet allows the retrieval of DNS Zone definitions.
.PARAMETER Name
    A string value representing the FQDN of the Zone definition to be retrieved.
.PARAMETER ViewID
    An integer value representing the entity ID of the desired view.
.PARAMETER View
    A PSCustomObject representing the desired view.
.PARAMETER BlueCatSession
    A BlueCat object representing the session to be used for this object lookup.
.EXAMPLE
    PS> Get-BlueCatHost -Name example.com

    Returns a PSCustomObject representing the requested zone definition, or NULL if not found.
    BlueCatSession will default to the current default session.
    View will default to the BlueCatSession default view.
.EXAMPLE
    PS> Get-BlueCatHost -Name anotherzone.com -ViewID 23456 -BlueCatSession $Session3

    Returns a PSCustomObject representing the requested zone definition, or NULL if not found.
    Use the BlueCatSession associated with $Session3 to perform this lookup.
    The record will be searched for in view 23456.
.INPUTS
    None
.OUTPUTS
    PSCustomObject representing the requested zone definition, or NULL if not found.

    [int] id
    [string] name
    [string] shortName
    [string] type = 'Zone'
    [string] properties
    [PSCustomObject] property
    [PSCustomObject] config
    [PSCustomObject] view
#>
   [CmdletBinding(DefaultParameterSetName='byID')]

    param(
        [parameter(Mandatory)]
        [Alias('Zone')]
        [string] $Name,

        [Parameter(ParameterSetName='byID')]
        [ValidateRange(1, [int]::MaxValue)]
        [int]$ViewID,

        [Parameter(ParameterSetName='byObj',Mandatory)]
        [ValidateNotNullOrEmpty()]
        [PSCustomObject] $View,

        [Parameter()]
        [Alias('Connection','Session')]
        [BlueCat]$BlueCatSession = $Script:BlueCatSession
    )

    begin {
        Get-CallerPreference -Cmdlet $PSCmdlet -SessionState $ExecutionContext.SessionState
        if (-not $BlueCatSession) { throw 'No active BlueCatSession found' }
    }

    process {
        $thisFN = (Get-PSCallStack)[0].Command

        $Zone = $Name | Test-ValidFQDN

        if ($View)   {
            $ViewID = $View.ID
        }
        if (-not $ViewID) {
            $BlueCatSession | Confirm-Settings -View
            $ViewID = $BlueCatSession.View.id
        }

        $zPath = $Zone.Split('\.')
        [array]::Reverse($zPath)

        $zId = $ViewID
        foreach ($bit in $zPath) {
            $Query = "getEntityByName?parentId=$($zId)&type=Zone&name=$($bit)"
            $BlueCatReply = Invoke-BlueCatApi -Method Get -Request $Query -BlueCatSession $BlueCatSession
            if (-not $BlueCatReply.id) {
                Write-Verbose "$($thisFN): Zone $($Zone) not found!"
                return
            }
            $zId = $BlueCatReply.id
        }
        $zObj = $BlueCatReply | Convert-BlueCatReply -BlueCatSession $BlueCatSession

        Write-Verbose "$($thisFN): Selected #$($zObj.id) as '$($zObj.name)'"
        $zObj
    }
}
