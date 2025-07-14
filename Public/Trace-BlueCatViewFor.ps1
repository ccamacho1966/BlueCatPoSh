function Trace-BlueCatViewFor {
    [CmdletBinding()]

    param(
        [parameter(ValueFromPipeline)]
        [Alias('Connection','Session')]
        [BlueCat] $BlueCatSession = $Script:BlueCatSession,

        [parameter(Mandatory)]
        [ValidateRange(1, [int]::MaxValue)]
        [int] $ID
    )

    begin { Get-CallerPreference -Cmdlet $PSCmdlet -SessionState $ExecutionContext.SessionState }

    process {
        $traceId = $ID
        do {
            $Query = "getParent?entityId=$($traceId)"
            $parent = Invoke-BlueCatApi -BlueCatSession $BlueCatSession -Method Get -Request $Query
            if (-not $parent.id) {
                throw "Entity Id $($traceId) not found!"
            }
            if ($parent.type -ne 'View') {
                $traceId = $parent.id
            }
        } while ($parent.type -ne 'View')
    
    
        $newObj = New-Object -TypeName psobject
        $newObj | Add-Member -MemberType NoteProperty -Name 'id'     -Value $parent.id
        $newObj | Add-Member -MemberType NoteProperty -Name 'name'   -Value $parent.name
        $newObj | Add-Member -MemberType NoteProperty -Name 'type'   -Value 'View'
        $newObj | Add-Member -MemberType NoteProperty -Name 'config' -Value (Get-BlueCatParent -id ($parent.id) -BlueCatSession $BlueCatSession)

        $newObj
    }
}
