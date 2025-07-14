function Set-BlueCatView {
    [CmdletBinding()]

    param(
        [Parameter(Mandatory,Position=0,ParameterSetName='ByName')]
        [Alias('ViewName')]
        [string] $Name,

        [Parameter(Mandatory,Position=0,ParameterSetName='ByID')]
        [ValidateRange(1, [int]::MaxValue)]
        [Alias('ViewID')]
        [int] $ID,

        [Parameter(ValueFromPipeline,Position=1)]
        [Alias('Connection','Session')]
        [BlueCat] $BlueCatSession = $Script:BlueCatSession,

        [switch]$PassThru
    )

    begin { Get-CallerPreference -Cmdlet $PSCmdlet -SessionState $ExecutionContext.SessionState }

    process {
        if ($Name -and !$BlueCatSession.idConfig) {
            throw "Must set config first to set view by Name"
        }

        if ($PSCmdlet.ParameterSetName -eq 'ByID') {
            $Query = "getEntityById?id=$($id)"
            $BlueCatReply = Invoke-BlueCatApi -Method Get -Request $Query -BlueCatSession $BlueCatSession
            if (-not $BlueCatReply.id) {
                throw "$($BlueCatReply) View #$($ID) not found!"
            }
            if ($BlueCatReply.type -ne 'View') {
                throw "$($BlueCatReply) Entity #$($ID) ($($BlueCatReply.name)) is not a View!"
            }

            $Query = "getParent?entityId=$($ID)"
            $parent = Invoke-BlueCatApi -Connection $BlueCatSession -Method Get -Request $Query
            if ($parent.type -eq 'Configuration') {
                $BlueCatSession | Set-BlueCatConfig -ID $parent.id
            } else {
                throw "Parent of $($BlueCatSession.View) is not a Configuration! $($parent)"
            }
        } else {
            $Query = "getEntityByName?parentId=$($BlueCatSession.idConfig)&type=View&name=$($Name)"
            $BlueCatReply = Invoke-BlueCatApi -Method Get -Request $Query -BlueCatSession $BlueCatSession
            if (-not $BlueCatReply.id) {
                throw "$($BlueCatReply) View $($name) not found!"
            }
        }

        $BlueCatSession.idView = $BlueCatReply.id
        $BlueCatSession.View = $BlueCatReply.name
        Write-Verbose "Set-BlueCatView: Selected View #$($BlueCatSession.idView) as '$($BlueCatSession.View)'"

        if ($PassThru) {
            $BlueCatReply | Convert-BlueCatReply -BlueCatSession $BlueCatSession
        }
    }
}
