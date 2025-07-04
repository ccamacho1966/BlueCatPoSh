function Get-BlueCatConfig {
    [cmdletbinding(DefaultParameterSetName='byID')]

    param(
        [Parameter(ParameterSetName='byName',Mandatory)]
        [ValidateNotNullOrEmpty()]
        [Alias('ConfigName')]
        [string] $Name,

        [Parameter(ParameterSetName='byID')]
        [Alias('ID')]
        [int] $ConfigID,

        [Parameter(ParameterSetName='All')]
        [switch] $All,

        [Parameter(ValueFromPipeline,Position=0)]
        [Alias('Connection','Session')]
        [BlueCat] $BlueCatSession = $Script:BlueCatSession
    )

    process {
        if ($All) {
            Write-Verbose 'Get-BlueCatConfig: ALL'
            $Url = 'getEntities?parentId=0&start=0&count=100&type=Configuration'
            $BlueCatReply = Invoke-BlueCatApi -Method Get -Request $Url -BlueCatSession $BlueCatSession

            # Return an array of all BlueCat Configurations on this appliance
            $BlueCatReply | Convert-BlueCatReply -BlueCatSession $BlueCatSession
        } else {
            if ($Name) {
                # Attempt to lookup by name
                Write-Verbose "Get-BlueCatConfig: Name='$($Name)'"
                $objConf = Get-BlueCatEntityByName -Name $Name -EntityType 'Configuration' -BlueCatSession $BlueCatSession
            } else {
                if ($ConfigID) {
                    Write-Verbose "Get-BlueCatConfig: ID='$($ConfigID)'"
                } elseif ($BlueCatSession.idConfig) {
                    $ConfigID = $BlueCatSession.idConfig
                    Write-Verbose "Get-BlueCatConfig: Default Config ($($ConfigID))"
                } else {
                    Write-Verbose 'Get-BlueCatConfig: No parameters provided and no default config is set'
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
