function Add-BlueCatExternalHost
{
<#
.SYNOPSIS
    Create a new External Host record.
.DESCRIPTION
    The Add-BlueCatExternalHost cmdlet will create a new External Host record.

    External Host records are necessary as targets for CNAME, MX, and SRV records when the target is not in a zone managed by the IPAM appliance.
.PARAMETER Name
    A string value representing the FQDN of the External Host record to be created.
.PARAMETER ViewID
    An integer value representing the entity ID of the desired view.
.PARAMETER View
    A PSCustomObject representing the desired view.
.PARAMETER BlueCatSession
    A BlueCat object representing the session to be used for this object creation.
.PARAMETER PassThru
    A switch that causes a PSCustomObject representing the new External Host record to be returned.
.EXAMPLE
    PS> Add-BlueCatExternalHost -Name 'server19.example.com'

    Create a new External Host record for 'server19.example.com'.
    BlueCatSession will default to the current default session.
    View will default to the BlueCatSession default view.
.EXAMPLE
    PS> Add-BlueCatExternalHost -Name 'server22.foreign.com' -ViewID 23456 -BlueCatSession $Session9

    Create a new External Host record for 'server22.foreign.com' in view 23456.
    Use the BlueCatSession associated with $Session9 to create this record.
.EXAMPLE
    PS> Add-BlueCatExternalHost -Name 'host96.example.com' -View $MyViewObj -BlueCatSession $Session6 -PassThru

    Create a new External Host record for 'host96.example.com'.
    Use the BlueCatSession associated with $Session6 to create this record.
    Create the record in the view associated with PSCustomObject $MyViewObj.

    A PSCustomObject representing the new External Host record will be returned (PassThru).
.INPUTS
    None
.OUTPUTS
    None, by default.

    If the '-PassThru' switch is used, a PSCustomObject representing the new External Host record will be returned.
#>
    [CmdletBinding(DefaultParameterSetName='ViewID')]

    param(
        [Parameter(Mandatory)]
        [Alias('ExternalHost')]
        [string] $Name,

        [Parameter(ParameterSetName='ViewID')]
        [int] $ViewID,

        [Parameter(ParameterSetName='ViewObj',Mandatory)]
        [ValidateNotNullOrEmpty()]
        [PSCustomObject] $View,

        [Parameter()]
        [Alias('Properties')]
        [PSCustomObject] $Property,

        [Parameter()]
        [Alias('Connection','Session')]
        [BlueCat] $BlueCatSession = $Script:BlueCatSession,

        [switch] $PassThru
    )

    begin {
        Get-CallerPreference -Cmdlet $PSCmdlet -SessionState $ExecutionContext.SessionState
        if (-not $BlueCatSession) { throw 'No active BlueCatSession found' }
    }

    process {
        $thisFN = (Get-PSCallStack)[0].Command

        $xHost = $Name | Test-ValidFQDN

        $LookupParms = @{
            Name           = $xHost
            BlueCatSession = $BlueCatSession
        }

        if ($ViewID) {
            $LookupParms.ViewID = $ViewID
        } elseif ($View)   {
            $LookupParms.View   = $View
            $ViewID             = $View.ID
        }

        $BlueCatReply = Get-BlueCatExternalHost @LookupParms
        if ($BlueCatReply) {
            throw "$($thisFN): $($xHost) already exists as Object #$($result.id)!"
        }

        $Uri = "addExternalHostRecord?viewId=$($ViewID)&name=$($xHost)"
        $BlueCatReply = Invoke-BlueCatApi -Method Post -Request $Uri -Connection $BlueCatSession

        if (-not $BlueCatReply) {
            throw "$($thisFN): Failed to create $($xHost): $($result)"
        }

        Write-Verbose "$($thisFN): Created #$($BlueCatReply) as '$($xHost)'"

        if ($PassThru) {
            Get-BlueCatEntityById -ID $BlueCatReply -BlueCatSession $BlueCatSession
        }
    }
}
