function Set-BlueCatView {
<#
.SYNOPSIS
    Sets the default BlueCat view for an active BlueCat session.
.DESCRIPTION
    The SetBlueCatView cmdlet accepts either the name of the desired view as a string
    or the entity ID as an integer and sets/updates the default view for a specified or
    the default BlueCat session. Once updated, the default view can be retrieved by the
    Get-BlueCatView cmdlet or directly referenced as $BlueCatSession.view (the view
    name as a string) or $BlueCatSession.idView (the entity ID as an integer).
.PARAMETER Name
    A string value representing the name of the desired view.

    When setting a view by name, the BlueCat session must have a default
    configuration already set or an error will be thrown.
.PARAMETER ID
    An integer value representing the entity ID of the desired view.

    When setting a view by entity ID, the configuration will be updated automatically.
.PARAMETER BlueCatSession
    A BlueCat object representing the session to be updated.
.PARAMETER PassThru
    A switch that causes a PSCustomObject representing the view to be returned.
.EXAMPLE
    PS> Set-BlueCatView -Name 'Marketing'

    Updates the default view on the default BlueCat session to be 'Marketing'.
.EXAMPLE
    PS> Set-BlueCatView -ID 23456 -BlueCatSession $MyOtherBlueCatSession

    Updates the default view for $MyOtherBlueCatSession to entity ID 23456.
    If entity ID 23456 is not a view, an error will be thrown by the cmdlet.
.EXAMPLE
    PS> $UpdatedView = $AnotherSession | Set-BlueCatView -Name 'Partners' -PassThru

    Pipes the session $AnotherSession to Set-BlueCatView and updates it to the view
    named 'Partners'. Since the '-PassThru' switch is specified, a new PSCustomObject
    representing the view is returned and stored in the variable $UpdatedView.
.INPUTS
    [BlueCat] object can be piped to Set-BlueCatView as the session to be updated.
.OUTPUTS
    None, by default.

    If the '-PassThru' switch is used, a PSCustomObject representing the view will be returned.
#>
    [CmdletBinding()]

    param(
        [Parameter(Mandatory,Position=0,ParameterSetName='ByName')]
        [Alias('ViewName')]
        [string] $Name,

        [Parameter(Mandatory,Position=0,ParameterSetName='ByID')]
        [ValidateRange(1, [int]::MaxValue)]
        [Alias('ViewID')]
        [int] $ID,

        [Parameter(ValueFromPipeline,Position=1)]
        [Alias('Connection','Session')]
        [BlueCat] $BlueCatSession = $Script:BlueCatSession,

        [switch]$PassThru
    )

    begin { Get-CallerPreference -Cmdlet $PSCmdlet -SessionState $ExecutionContext.SessionState }

    process {
        if ($Name -and !$BlueCatSession.idConfig) {
            throw "Must set config first to set view by Name"
        }

        if ($PSCmdlet.ParameterSetName -eq 'ByID') {
            $Query = "getEntityById?id=$($id)"
            $BlueCatReply = Invoke-BlueCatApi -Method Get -Request $Query -BlueCatSession $BlueCatSession
            if (-not $BlueCatReply.id) {
                throw "$($BlueCatReply) View #$($ID) not found!"
            }
            if ($BlueCatReply.type -ne 'View') {
                throw "$($BlueCatReply) Entity #$($ID) ($($BlueCatReply.name)) is not a View!"
            }

            $Query = "getParent?entityId=$($ID)"
            $parent = Invoke-BlueCatApi -Connection $BlueCatSession -Method Get -Request $Query
            if ($parent.type -eq 'Configuration') {
                $BlueCatSession | Set-BlueCatConfig -ID $parent.id
            } else {
                throw "Parent of $($BlueCatSession.View) is not a Configuration! $($parent)"
            }
        } else {
            $Query = "getEntityByName?parentId=$($BlueCatSession.idConfig)&type=View&name=$($Name)"
            $BlueCatReply = Invoke-BlueCatApi -Method Get -Request $Query -BlueCatSession $BlueCatSession
            if (-not $BlueCatReply.id) {
                throw "$($BlueCatReply) View $($name) not found!"
            }
        }

        $BlueCatSession.idView = $BlueCatReply.id
        $BlueCatSession.View = $BlueCatReply.name
        Write-Verbose "Set-BlueCatView: Selected View #$($BlueCatSession.idView) as '$($BlueCatSession.View)'"

        if ($PassThru) {
            $BlueCatReply | Convert-BlueCatReply -BlueCatSession $BlueCatSession
        }
    }
}
