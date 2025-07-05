function Set-BlueCatView {
    [cmdletbinding()]
    param(
        [Parameter(Mandatory,Position=0,ParameterSetName='ByName')]
        [string] $Name,

        [Parameter(Mandatory,Position=0,ParameterSetName='ByID')]
        [int] $ID,

        [Parameter(ValueFromPipeline,Position=1)]
        [Alias('Connection','Session')]
        [BlueCat] $BlueCatSession = $Script:BlueCatSession,

        [switch]$PassThru
    )

    begin { Get-CallerPreference -Cmdlet $PSCmdlet -SessionState $ExecutionContext.SessionState }

    process {
        if ($Name -and !$BlueCatSession.idConfig) { throw "Must set config first to set view by Name" }

        if ($PSCmdlet.ParameterSetName -eq 'ByID') {
            $Query = "getEntityById?id=$($id)"
            $result = Invoke-BlueCatApi -BlueCatSession $BlueCatSession -Method Get -Request $Query
            if (-not $result.id) { throw "$($result) View #$($ID) not found!" }
            if ($result.type -ne 'View') { throw "$($result) Entity #$($ID) ($($result.name)) is not a View!" }

            $Query = "getParent?entityId=$($ID)"
            $parent = Invoke-BlueCatApi -Connection $BlueCatSession -Method Get -Request $Query
            if ($parent.type -eq 'Configuration') {
                $BlueCatSession | Set-BlueCatConfig -ID $parent.id
            } else {
                throw "Parent of $($BlueCatSession.View) is not a Configuration! $($parent)"
            }
        } else {
            $Query = "getEntityByName?parentId=$($BlueCatSession.idConfig)&type=View&name=$($Name)"
            $result = Invoke-BlueCatApi -BlueCatSession $BlueCatSession -Method Get -Request $Query
            if (-not $result.id) {
                throw "$($result) View $($name) not found!"
            }
        }

        $BlueCatSession.idView = $result.id
        $BlueCatSession.View = $result.name
        Write-Verbose "Set-BlueCatView: Selected View #$($BlueCatSession.idView) as '$($BlueCatSession.View)'"

        if ($PassThru) { $BlueCatSession | Get-BlueCatView }
    }
}
