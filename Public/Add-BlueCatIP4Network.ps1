function Add-BlueCatIP4Network {
    [CmdletBinding()]

    Param(
        [Parameter(Mandatory)]
        [Alias('BlockID')]
        [int] $Parent,

        [Parameter(Mandatory)]
        [Alias('Network')]
        [string] $CIDR,

        [Parameter()]
        [Alias('PropertyObject')]
        [PSCustomObject] $Property,

        [Parameter()]
        [Alias('Connection','Session')]
        [BlueCat] $BlueCatSession = $Script:BlueCatSession,

        [switch] $PassThru
    )

    begin { Get-CallerPreference -Cmdlet $PSCmdlet -SessionState $ExecutionContext.SessionState } 

    process {
        $thisFN = (Get-PSCallStack)[0].Command

        # Confirm that the provided parent ID is for an IP4 block
        $BlockCheck = Get-BlueCatEntityById -ID $Parent -BlueCatSession $BlueCatSession
        if ($BlockCheck.type -ne 'IP4Block') {
            throw "ID:$($Parent) type is not IP4Block (Type: $($BlockCheck.type))"
        }

        if ($Property) {
            $PropertyString = $Property | Convert-BlueCatPropertyObject
        }

        Write-Verbose "$($thisFN): Create network [$($CIDR)] under block ID #$($Parent)"
        $Uri = "addIP4Network?blockId=$($Parent)&CIDR=$($CIDR)"
        if ($PropertyString) {
            Write-Verbose "$($thisFN): New property string [$($PropertyString)]"
            $Uri += "&properties=$($PropertyString)"
        }

        $BlueCatReply = Invoke-BlueCatApi -Method Post -Request $Uri -BlueCatSession $BlueCatSession
        if (-not $BlueCatReply) {
            throw "Failed to create new IP4 network $($CIDR) in block #$($Parent)"
        }

        if ($PassThru) {
            Get-BlueCatEntityById -ID $BlueCatReply -BlueCatSession $BlueCatSession
        }
    }
}
