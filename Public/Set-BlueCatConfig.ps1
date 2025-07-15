function Set-BlueCatConfig {
<#
.SYNOPSIS
    Sets the default BlueCat configuration for an active BlueCat session.
.DESCRIPTION
    The SetBlueCatConfig cmdlet accepts either the name of the desired configuration as a string
    or the entity ID as an integer and sets/updates the default configuration for a specified or
    the default BlueCat session. Once updated, the default configuration can be retrieved by the
    Get-BlueCatConfig cmdlet or directly referenced as $BlueCatSession.config (the configuration
    name as a string) or $BlueCatSession.idConfig (the entity ID as an integer).
.PARAMETER Name
    A string value representing the name of the desired configuration.
.PARAMETER ID
    An integer value representing the entity ID of the desired configuration.
.PARAMETER BlueCatSession
    A BlueCat object representing the session to be updated.
.PARAMETER PassThru
    A switch that causes a PSCustomObject representing the configuration to be returned.
.EXAMPLE
    PS> Set-BlueCatConfig -Name 'Public'

    Updates the default configuration on the default BlueCat session to be 'Public'.
.EXAMPLE
    PS> Set-BlueCatConfig -ID 12345 -BlueCatSession $MyOtherBlueCatSession

    Updates the default configuration for $MyOtherBlueCatSession to entity ID 12345.
    If entity ID 12345 is not a configuration, an error will be thrown by the cmdlet.
.EXAMPLE
    PS> $UpdatedConfig = $AnotherSession | Set-BlueCatConfig -Name 'Private' -PassThru

    Pipes the session $AnotherSession to Set-BlueCatConfig and updates it to the configuration
    named 'Private'. Since the '-PassThru' switch is specified, a new PSCustomObject representing
    the configuration is returned and stored in the variable $UpdatedConfig.
.INPUTS
    [BlueCat] object can be piped to Set-BlueCatConfig as the session to be updated.
.OUTPUTS
    None, by default.

    If the '-PassThru' switch is used, a PSCustomObject representing the configuration will be returned.
#>
    [CmdletBinding()]

    param(
        [Parameter(Mandatory,Position=0,ParameterSetName='ByName')]
        [Alias('ConfigName')]
        [string] $Name,

        [Parameter(Mandatory,Position=0,ParameterSetName='ByID')]
        [ValidateRange(1, [int]::MaxValue)]
        [Alias('ConfigID')]
        [int] $ID,

        [Parameter(ValueFromPipeline,Position=1)]
        [Alias('Connection','Session')]
        [BlueCat] $BlueCatSession = $Script:BlueCatSession,

        [switch] $PassThru
    )

    begin { Get-CallerPreference -Cmdlet $PSCmdlet -SessionState $ExecutionContext.SessionState }

    process {
        $thisFN = (Get-PSCallStack)[0].Command

        if ($PSCmdlet.ParameterSetName -eq 'ByID') {
            $Query = "getEntityById?id=$($ID)"
            $ErrorPrefix = "Configuration #$($ID)"
        } else {
            $Query = "getEntityByName?parentId=0&type=Configuration&name=$($Name)"
            $ErrorPrefix = "Configuration '$($Name)'"
        }

        $BlueCatReply = Invoke-BlueCatApi -Method Get -Request $Query -BlueCatSession $BlueCatSession

        if (-not $BlueCatReply.id) {
            throw "$($ErrorPrefix) not found: $($BlueCatReply)"
        } elseif ($BlueCatReply.type -ne 'Configuration') {
            throw "Entity $($ID) is now a Configuration (Type:$($BlueCatReply.type))"
        }

        $BlueCatSession.idConfig = $BlueCatReply.id
        $BlueCatSession.Config   = $BlueCatReply.name
        Write-Verbose "$($thisFN): Selected ID:$($BlueCatReply.id) as Configuration '$($BlueCatReply.name)'"

        if ($PassThru) {
            $BlueCatReply | Convert-BlueCatReply -BlueCatSession $BlueCatSession
        }
    }
}
