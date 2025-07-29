function Trace-BlueCatConfigFor {
    [CmdletBinding()]

    param(
        [Parameter(ValueFromPipeline)]
        [Alias('Connection','Session')]
        [BlueCat] $BlueCatSession = $Script:BlueCatSession,

        [Parameter(Position=0,Mandatory)]
        [ValidateRange(1, [int]::MaxValue)]
        [int] $ID
    )

    begin {
        Get-CallerPreference -Cmdlet $PSCmdlet -SessionState $ExecutionContext.SessionState
        if (-not $BlueCatSession) { throw 'No active BlueCatSession found' }
    }

    process {
        $traceId = $ID
        do {
            $Query = "getParent?entityId=$($traceId)"
            $parent = Invoke-BlueCatApi -BlueCatSession $BlueCatSession -Method Get -Request $Query
            if (-not $parent.id) {
                throw "Entity Id $($traceId) not found!"
            }
            if ($parent.type -ne 'Configuration') {
                $traceId = $parent.id
            }
        } while ($parent.type -ne 'Configuration')
    
        $newObj = New-Object -TypeName psobject
        $newObj | Add-Member -MemberType NoteProperty -Name 'id'   -Value $parent.id
        $newObj | Add-Member -MemberType NoteProperty -Name 'name' -Value $parent.name
        $newObj | Add-Member -MemberType NoteProperty -Name 'type' -Value $parent.type

        $newObj
    }
}
