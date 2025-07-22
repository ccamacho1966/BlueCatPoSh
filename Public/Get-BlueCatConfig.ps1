function Get-BlueCatConfig {
<#
.SYNOPSIS
    Retrieve one or more BlueCat Configuration objects.
.DESCRIPTION
    The Get-BlueCatConfig cmdlet allows the retrieval of BlueCat Configuration objects.

    A specific configuration can be retrieved by entity ID or configuration name.

    Using the -All switch allows the retrieval of all configurations defined on an IPAM appliance.
.PARAMETER Name
    A string value representing the name of the desired configuration.
.PARAMETER ConfigID
    An integer value representing the entity ID of the desired configuration.
.PARAMETER All
    A switch that indicates the cmdlet should return all configurations on an IPAM appliance.
.PARAMETER BlueCatSession
    A BlueCat object representing the session to be used for this entity lookup.
.EXAMPLE
    PS> Get-BlueCatConfig

    Returns a PSCustomObject representing the default configuration for the default BlueCat session, or NULL if one is not set.
.EXAMPLE
    PS> Get-BlueCatConfig -Name 'Public' -BlueCatSession $Session4

    Returns a PSCustomObject representing the 'Public' configuration on BlueCat session $Session4. Returns NULL if the configuration is not found.
.EXAMPLE
    PS> Get-BlueCatConfig -All

    Returns a list of PSCustomObjects representing all configurations on the default BlueCat session. Returns NULL if there are no configurations configured.
.INPUTS
    BlueCat object representing the session to be used for this entity lookup.
.OUTPUTS
    One or more PSCustomObjects representing BlueCat configurations.
#>
    [CmdletBinding(DefaultParameterSetName='byID')]

    param(
        [Parameter(ParameterSetName='byName',Mandatory)]
        [ValidateNotNullOrEmpty()]
        [Alias('ConfigName')]
        [string] $Name,

        [Parameter(ParameterSetName='byID')]
        [Alias('ID')]
        [ValidateRange(1, [int]::MaxValue)]
        [int] $ConfigID,

        [Parameter(ParameterSetName='All')]
        [switch] $All,

        [Parameter(ValueFromPipeline,Position=0)]
        [Alias('Connection','Session')]
        [BlueCat] $BlueCatSession = $Script:BlueCatSession
    )

    process {
        $thisFN = (Get-PSCallStack)[0].Command

        if ($All) {
            Write-Verbose "$($thisFN): ALL"
            $Url = 'getEntities?parentId=0&start=0&count=100&type=Configuration'
            $BlueCatReply = Invoke-BlueCatApi -Method Get -Request $Url -BlueCatSession $BlueCatSession

            # Return an array of all BlueCat Configurations on this appliance
            [PSCustomObject[]] ($BlueCatReply | Convert-BlueCatReply -BlueCatSession $BlueCatSession)
        } else {
            if ($Name) {
                # Attempt to lookup by name
                Write-Verbose "$($thisFN): Name='$($Name)'"
                $objConf = Get-BlueCatEntityByName -Name $Name -EntityType 'Configuration' -BlueCatSession $BlueCatSession
            } else {
                if ($ConfigID) {
                    Write-Verbose "$($thisFN): ID='$($ConfigID)'"
                } elseif ($BlueCatSession.Config) {
                    $ConfigID = $BlueCatSession.Config.id
                    Write-Verbose "$($thisFN): Default Config ($($ConfigID))"
                } else {
                    Write-Verbose "$($thisFN): No parameters provided and no default config is set"
                }

                if ($ConfigID) {
                    # Attempt to lookup by ID
                    $objConf = Get-BlueCatEntityById -ID $ConfigID -BlueCatSession $BlueCatSession
                    if ($objConf.type -ne 'Configuration') {
                        # This object is not a configuration - throw an error!
                        throw "$($objConf.name) (ID #$($ConfigID)) is not a Configuration! (type='$($objConf.type)')"
                    }
                }
            }

            # Return configuration object (or NULL)
            $objConf
        }
    }
}
