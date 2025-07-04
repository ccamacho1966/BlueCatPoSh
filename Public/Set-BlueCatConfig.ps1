function Set-BlueCatConfig {
    [cmdletbinding()]
    param(
        [Parameter(Mandatory,Position=0,ParameterSetName='ByName')]
        [string] $Name,

        [Parameter(Mandatory,Position=0,ParameterSetName='ByID')]
        [int] $ID,

        [Parameter(ValueFromPipeline,Position=1)]
        [Alias('Connection','Session')]
        [BlueCat] $BlueCatSession = $Script:BlueCatSession,

        [switch] $PassThru
    )

    begin { Get-CallerPreference -Cmdlet $PSCmdlet -SessionState $ExecutionContext.SessionState }

    process {
        if ($PSCmdlet.ParameterSetName -eq 'ByID') { $Query = "getEntityById?id=$($ID)" }
        else { $Query = "getEntityByName?parentId=0&type=Configuration&name=$($Name)" }

        $result = Invoke-BlueCatApi -BlueCatSession $BlueCatSession -Method Get -Request $Query

        if (-not $result.id) {
            if ($PSCmdlet.ParameterSetName -eq 'ByID') { Throw "Configuration #$($ID) not found: $($result)" }
            else { Throw "Configuration '$($Name)' not found: $($result)" }
        }

        $BlueCatSession.idConfig = $result.id
        $BlueCatSession.Config = $result.name
        Write-Verbose "Set-BlueCatConfig: Selected Conf #$($result.id) as '$($result.name)'"

        if ($PassThru) { $BlueCatSession | Get-BlueCatConfig }
    }
}
