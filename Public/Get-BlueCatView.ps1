function Get-BlueCatView {
<#
.SYNOPSIS
    Retrieve one or more BlueCat View objects.
.DESCRIPTION
    The Get-BlueCatView cmdlet allows the retrieval of BlueCat View objects.

    A specific view can be retrieved directly by entity ID or by combining a view name with a configuration reference.

    Using the -All switch allows the retrieval of all views linked to a specific configuration. When -All is combined with -EveryConfig the cmdlet will retrieve a complete list of all views in all configurations on the IPAM appliance.
.PARAMETER Name
    A string value representing the name of the desired view.

    Looking up a view by name requires a valid configuration reference. This can be provided as an object (-Config), an entity ID (-ConfigID), or by the BlueCatSession default configuration.
.PARAMETER ViewID
    An integer value representing the entity ID of the desired view.
.PARAMETER Config
    A PSCustomObject representing the desired configuration.
.PARAMETER ConfigID
    An integer value representing the entity ID of the desired configuration.
.PARAMETER All
    A switch that indicates the cmdlet should return all views in a specific configuration.
.PARAMETER EveryConfig
    A switch that when combined with -All indicates that all views in all configurations should be returned.
.PARAMETER BlueCatSession
    A BlueCat object representing the session to be used for this entity lookup.
.EXAMPLE
    PS> Get-BlueCatView

    Returns a PSCustomObject representing the default view for the default BlueCat session, or NULL if one is not set.
.EXAMPLE
    PS> Get-BlueCatView -Name 'Partners' -ConfigID 12345 -BlueCatSession $Session8

    Returns a PSCustomObject representing the 'Partners' view under configuration #12345 on BlueCat session $Session8. Returns NULL if the view is not found.
.EXAMPLE
    PS> Get-BlueCatView -Config $MyConfigObj -All -BlueCatSession $Session3

    Returns a list of PSCustomObjects representing all views under the configuration object $MyConfigObj on BlueCat session $Session3. Returns NULL if the configuration has no views configured.
.EXAMPLE
    PS> Get-BlueCatView -All -EveryConfig

    Returns a list of PSCustomObjects representing all views under all configurations on the default BlueCat session. Returns NULL if there are no views in any configuration.
.INPUTS
    BlueCat object representing the session to be used for this entity lookup.
.OUTPUTS
    One or more PSCustomObjects representing BlueCat views.
#>
    [CmdletBinding(DefaultParameterSetName='ViewNameConfigID')]

    param(
        [Parameter(Position=0,ParameterSetName='ViewNameConfigID')]
        [Parameter(Position=0,ParameterSetName='ViewNameConfigObj')]
        [ValidateNotNullOrEmpty()]
        [Alias('ViewName')]
        [string] $Name,

        [Parameter(Position=0,ParameterSetName='ViewID',Mandatory)]
        [ValidateRange(1, [int]::MaxValue)]
        [Alias('ID')]
        [int] $ViewID,

        [Parameter(ParameterSetName='AllConfigObj',Mandatory)]
        [Parameter(ParameterSetName='ViewNameConfigObj',Mandatory)]
        [ValidateNotNullOrEmpty()]
        [PsCustomObject] $Config,

        [Parameter(ParameterSetName='AllConfigID')]
        [Parameter(ParameterSetName='ViewNameConfigID')]
        [ValidateRange(1, [int]::MaxValue)]
        [int] $ConfigID,

        [Parameter(ParameterSetName='AllConfigObj',Mandatory)]
        [Parameter(ParameterSetName='AllConfigID',Mandatory)]
        [Parameter(ParameterSetName='All',Mandatory)]
        [switch] $All,

        [Parameter(ParameterSetName='All',Mandatory)]
        [switch] $EveryConfig,

        [Parameter(ValueFromPipeline)]
        [Alias('Connection','Session')]
        [BlueCat] $BlueCatSession = $Script:BlueCatSession
    )

    begin { Get-CallerPreference -Cmdlet $PSCmdlet -SessionState $ExecutionContext.SessionState } 

    process {
        $thisFN = (Get-PSCallStack)[0].Command

        if ($All) {
            if ($EveryConfig) {
                # Every View in Every Config
                Write-Verbose "$($thisFN)(ALL): All Views in Every Config"
                [PsCustomObject[]] $ConfigList = Get-BlueCatConfig -All -BlueCatSession $BlueCatSession
            } elseif ($Config) {
                # Every View in a specific Config (object input)
                [PsCustomObject[]] $ConfigList = $Config
            } else {
                # Get all views in a specific Config ID (or the default configuration, if set)
                if (-not $ConfigID) {
                    $ConfigID = $BlueCatSession.idConfig
                }

                if ($ConfigID) {
                    [PsCustomObject[]] $ConfigList = Get-BlueCatConfig -ConfigID $ConfigID -BlueCatSession $BlueCatSession
                } else {
                    Write-Warning "$($thisFN)(ALL): No config specified and no default config is set"
                    return
                }
            }

            # loop through selected config objects and pull all views from each
            [PSCustomObject[]] $ViewList = @()
            foreach ($cfg in $ConfigList) {
                Write-Verbose "$($thisFN): ALL Views in Configuration '$($cfg.name)' (ID:$($cfg.id))"
                $Url = "getEntities?parentId=$($cfg.id)&start=0&count=100&type=View"
                $BlueCatReply = Invoke-BlueCatApi -Method Get -Request $Url -BlueCatSession $BlueCatSession

                # Stack an array of all BlueCat Views in this Configuration
                $ViewList += $BlueCatReply | Convert-BlueCatReply -BlueCatSession $BlueCatSession
            }
            if ($ViewList.Count) {
                # Return the array of views, if any have been found.
                $ViewList
            }
        } else {
            if ($Name) {
                # Find a view using the supplied name
                if ($Config.ID) {
                    # Use the Config ID supplied with the object
                    $ConfigID = $Config.ID
                }
                if (-not $ConfigID) {
                    # No Config ID or Object was supplied so try to use the session default
                    $ConfigID = $BlueCatSession.idConfig
                }
                if ($ConfigID) {
                    # Attempt to retrieve the view if we have a config to search in
                    $objView = Get-BlueCatEntityByName -Name $Name -ParentID $ConfigID -EntityType 'View' -Connection $BlueCatSession
                }
            } else {
                # Find a view using an ID, if supplied
                if ((-not $ViewID) -and ($BlueCatSession.idView)) {
                    # No ID was supplied, but there is a default View so use that
                    Write-Verbose "$($thisFN): Using default view for lookup"
                    $ViewID = $BlueCatSession.idView
                }
                if ($ViewID) {
                    # Lookup the View by the selected ID, otherwise do nothing and return NULL
                    $objView = Get-BlueCatEntityById -ID $ViewID -BlueCatSession $BlueCatSession
                    if ($objView.type -ne 'View') {
                        # The supplied ID was not a View!
                        throw "Entity #$($ViewID) ($($result.name)) is not a View: $($result)"
                    }
                } else {
                    Write-Verbose "$($thisFN): No parameters provided and no default view is set"
                }
            }

            # Return the View object (or NULL)
            $objView
        }
    }
}
