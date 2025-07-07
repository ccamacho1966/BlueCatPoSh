function Set-BlueCatConfig {
    [cmdletbinding()]
    param(
        [Parameter(Mandatory,Position=0,ParameterSetName='ByName')]
        [Alias('ConfigName')]
        [string] $Name,

        [Parameter(Mandatory,Position=0,ParameterSetName='ByID')]
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
        } else {
            $Query = "getEntityByName?parentId=0&type=Configuration&name=$($Name)"
        }

        $BlueCatReply = Invoke-BlueCatApi -Method Get -Request $Query -BlueCatSession $BlueCatSession

        if (-not $BlueCatReply.id) {
            if ($PSCmdlet.ParameterSetName -eq 'ByID') {
                throw "Configuration #$($ID) not found: $($BlueCatReply)"
            } else {
                throw "Configuration '$($Name)' not found: $($BlueCatReply)"
            }
        }

        $BlueCatSession.idConfig = $BlueCatReply.id
        $BlueCatSession.Config = $BlueCatReply.name
        Write-Verbose "$($thisFN): Selected Conf #$($BlueCatReply.id) as '$($BlueCatReply.name)'"

        if ($PassThru) {
            $BlueCatSession | Get-BlueCatConfig
        }
    }
}
