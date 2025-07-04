function Get-BlueCatView {
    [cmdletbinding(DefaultParameterSetName='ViewNameConfigID')]
    param(
        [Parameter(Position=0,ParameterSetName='ViewNameConfigID')]
        [Parameter(Position=0,ParameterSetName='ViewNameConfigObj')]
        [ValidateNotNullOrEmpty()]
        [Alias('ViewName')]
        [string] $Name,

        [Parameter(ParameterSetName='AllConfigObj',Mandatory)]
        [Parameter(ParameterSetName='ViewNameConfigObj',Mandatory)]
        [ValidateNotNullOrEmpty()]
        [PsCustomObject] $Config,

        [Parameter(ParameterSetName='AllConfigID')]
        [Parameter(ParameterSetName='ViewNameConfigID')]
        [int] $ConfigID,

        [Parameter(Position=0,ParameterSetName='ViewID',Mandatory)]
        [Alias('ID')]
        [int] $ViewID,

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
        if ($All) {
            if ($EveryConfig) {
                # Every View in Every Config
                Write-Verbose 'Get-BlueCatView(ALL): All Views in Every Config'
                [PsCustomObject[]] $ConfigList = Get-BlueCatConfig -All -BlueCatSession $BlueCatSession
            } elseif ($Config) {
                # Every View in a specific Config (object input)
                [PsCustomObject[]] $ConfigList = $Config
            } else {
                # Get all views in a specific Config ID (or the default configuration, if set)
                if (-not $ConfigID) { $ConfigID = $BlueCatSession.idConfig }

                if ($ConfigID) {
                    [PsCustomObject[]] $ConfigList = Get-BlueCatConfig -ConfigID $ConfigID -BlueCatSession $BlueCatSession
                } else {
                    Write-Warning 'Get-BlueCatView(ALL): No config specified and no default config is set'
                    return
                }
            }

            # loop through selected config objects and pull all views from each
            foreach ($cfg in $ConfigList) {
                Write-Verbose "Get-BlueCatView: ALL Views in Configuration '$($cfg.name)' (ID:$($cfg.id))"
                $Url = "getEntities?parentId=$($cfg.id)&start=0&count=100&type=View"
                $BlueCatReply = Invoke-BlueCatApi -Method Get -Request $Url -BlueCatSession $BlueCatSession

                # Stack an array of all BlueCat Views in this Configuration
                $BlueCatReply | Convert-BlueCatReply -BlueCatSession $BlueCatSession
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
                    $objView = Get-BlueCatEntityByName -Connection $BlueCatSession -Name $Name -ParentID $ConfigID -EntityType 'View'
                }
            } else {
                # Find a view using an ID, if supplied
                if ((-not $ViewID) -and ($BlueCatSession.idView)) {
                    # No ID was supplied, but there is a default View so use that
                    Write-Verbose 'Get-BlueCatView: Using default view for lookup'
                    $ViewID = $BlueCatSession.idView
                }
                if ($ViewID) {
                    # Lookup the View by the selected ID, otherwise do nothing and return NULL
                    $objView = Get-BlueCatEntityById -BlueCatSession $BlueCatSession -ID $ViewID
                    if ($objView.type -ne 'View') {
                        # The supplied ID was not a View!
                        throw "Entity #$($ViewID) ($($result.name)) is not a View: $($result)"
                    }
                } else {
                    Write-Verbose 'Get-BlueCatView: No parameters provided and no default view is set'
                }
            }

            # Return the View object (or NULL)
            $objView
        }
    }
}
