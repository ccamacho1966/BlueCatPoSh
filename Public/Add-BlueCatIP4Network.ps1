function Add-BlueCatIP4Network {
    [cmdletbinding(DefaultParameterSetName='CIDRstr')]
    param(
        [Parameter(Mandatory)]
        [int] $BlockID,

        [Parameter(Mandatory)]
        [string] $CIDR,

        [Parameter(Mandatory,ParameterSetName='CIDRobj')]
        [psobject] $PropertyObject,

        [ValidateNotNullOrEmpty()]
        [Parameter(ParameterSetName='CIDRstr')]
        [string] $PropertyString,

        [Parameter()]
        [Alias('Connection','Session')]
        [BlueCat] $BlueCatSession = $Script:BlueCatSession,

        [Parameter(DontShow)]
        [switch] $Quiet,

        [switch] $PassThru
    )

    begin { Get-CallerPreference -Cmdlet $PSCmdlet -SessionState $ExecutionContext.SessionState } 

    process {
        if ($PropertyObject) {
            $PropertyString = $PropertyObject | Convert-BlueCatPropertyObject
        }

        Write-Verbose "Add-BlueCatIP4Network: Create network [$($CIDR)] under block ID #$($BlockID)"
        $Uri = "addIP4Network?blockId=$($BlockID)&CIDR=$($CIDR)"
        if ($PropertyString) {
            Write-Verbose "Add-BluecatIP4Network: New property string [$($PropertyString)]"
            $Uri += "&properties=$($PropertyString)"
        }

        $result = Invoke-BlueCatApi -BlueCatSession $BlueCatSession -Method Post -Request $Uri
        if (-not $result) {
            throw "Add-BlueCatIP4Network: Failed to create new IP4 network $($CIDR) in block #$($BlockID)"
        }

        if ($PassThru) { Get-BlueCatEntityById -BlueCatSession $BlueCatSession -ID $result }
    }
}
