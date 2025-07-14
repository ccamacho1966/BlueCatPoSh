function Get-BlueCatView {
    [CmdletBinding(DefaultParameterSetName='ViewNameConfigID')]

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
        [ValidateRange(1, [int]::MaxValue)]
        [int] $ConfigID,

        [Parameter(Position=0,ParameterSetName='ViewID',Mandatory)]
        [ValidateRange(1, [int]::MaxValue)]
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
            foreach ($cfg in $ConfigList) {
                Write-Verbose "$($thisFN): ALL Views in Configuration '$($cfg.name)' (ID:$($cfg.id))"
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
