function Get-BlueCatEntities {
    [CmdletBinding()]

    param(
        [Parameter(Mandatory)]
        [Alias('ParentID')]
        [int] $Parent,

        [Parameter(Mandatory)]
        [string] $EntityType,

        [Parameter()]
        [ValidateRange(0, [int]::MaxValue)]
        [int] $Start = 0,

        [Parameter()]
        [ValidateRange(1, 100)]
        [int] $Count = 10,

        [Parameter()]
        [Alias('Connection','Session')]
        [BlueCat] $BlueCatSession = $Script:BlueCatSession
    )

    begin { Get-CallerPreference -Cmdlet $PSCmdlet -SessionState $ExecutionContext.SessionState }

    process {
        $thisFN = (Get-PSCallStack)[0].Command

        Write-Verbose "$($thisFN): EntityType='$($EntityType)', Parent='$($Parent)', Start=$($Start), Count=$($Count)"

        if ($EntityType -eq 'Configuration') {
            if ($Parent) {
                Write-Warning "Ignoring Parent ID for EntityType=Configuration lookup..."
            }
            $Parent=0
        }

        $Query = "getEntities?parentId=$($Parent)&type=$($EntityType)&start=$($Start)&count=$($Count)"
        [PSCustomObject[]] $BlueCatReply = Invoke-BlueCatApi -Method Get -Request $Query -BlueCatSession $BlueCatSession

        Write-Verbose "$($thisFN): Retrieved $($BlueCatReply.Count) records"

        if ($BlueCatReply) {
            $BlueCatReply | Convert-BlueCatReply -BlueCatSession $BlueCatSession
        }
    }
}
