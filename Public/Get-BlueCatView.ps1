function Get-BlueCatView {
    [cmdletbinding(DefaultParameterSetName='ViewNameConfigID')]
    param(
        [Parameter(Position=0,ParameterSetName='ViewNameConfigID')]
        [Parameter(Position=0,ParameterSetName='ViewNameConfigObj')]
        [ValidateNotNullOrEmpty()]
        [Alias('ViewName')]
        [string] $Name,

        [Parameter(Mandatory,ParameterSetName='ViewNameConfigObj')]
        [PsCustomObject] $Config,

        [Parameter(ParameterSetName='ViewNameConfigID')]
        [int] $ConfigID,

        [Parameter(Mandatory,Position=0,ParameterSetName='ViewID')]
        [Alias('ViewID')]
        [int] $ID,

        [Parameter(ValueFromPipeline)]
        [Alias('Connection','Session')]
        [BlueCat] $BlueCatSession = $Script:BlueCatSession
    )

    begin { Get-CallerPreference -Cmdlet $PSCmdlet -SessionState $ExecutionContext.SessionState } 

    process {
        if ($Name) {
            # Find a view using the supplied name
            if ($Config.ID) {
                # Use the Config ID supplied with the object
                $ConfigID = $Config.ID
            }
            if (-not $ConfigID) {
                # No Config ID or Object was supplied so we must have a valid default or throw an error
                $BlueCatSession | Confirm-Settings -Config
                $ConfigID = $BlueCatSession.idConfig
            }
            $objView = Get-BlueCatEntityByName -Connection $BlueCatSession -Name $Name -ParentID $ConfigID -EntityType 'View'
        } else {
            # Find a view using an ID, if supplied
            if ((-not $ID) -and ($BlueCatSession.idView)) {
                # No ID was supplied, but there is a default View so use that
                $ID = $BlueCatSession.idView
            }
            if ($ID) {
                # Lookup the View by the selected ID, otherwise do nothing and return NULL
                $objView = Get-BlueCatEntityById -BlueCatSession $BlueCatSession -ID $ID
                if ($objView.type -ne 'View') {
                    # The supplied ID was not a View!
                    throw "Entity #$($ID) ($($result.name)) is not a View: $($result)"
                }
            }
        }

        # Return the View object (or NULL)
        $objView
    }
}
