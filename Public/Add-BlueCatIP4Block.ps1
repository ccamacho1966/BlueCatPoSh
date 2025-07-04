function Add-BlueCatIP4Block {
    [cmdletbinding()]
    param(
        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [string] $Name,

        [parameter(Mandatory,ParameterSetName='CIDRObj')]
        [parameter(Mandatory,ParameterSetName='CIDRStr')]
        [ValidateNotNullOrEmpty()]
        [string] $CIDR,

        [parameter(Mandatory,ParameterSetName='RangeObj')]
        [parameter(Mandatory,ParameterSetName='RangeStr')]
        [ValidateNotNullOrEmpty()]
        [string] $Start,

        [parameter(Mandatory,ParameterSetName='RangeObj')]
        [parameter(Mandatory,ParameterSetName='RangeStr')]
        [ValidateNotNullOrEmpty()]
        [string] $End,

        [int] $Parent,

        [parameter(ParameterSetName='CIDRStr')]
        [parameter(ParameterSetName='RangeStr')]
        [string] $PropertyString,

        [parameter(Mandatory,ParameterSetName='CIDRObj')]
        [parameter(Mandatory,ParameterSetName='RangeObj')]
        [PSCustomObject] $PropertyObject,

        [Parameter()]
        [Alias('Connection','Session')]
        [BlueCat] $BlueCatSession = $Script:BlueCatSession,

        [switch] $PassThru
    )

    begin { Get-CallerPreference -Cmdlet $PSCmdlet -SessionState $ExecutionContext.SessionState } 

    process {
        $BlueCatSession | Confirm-Settings -Config

        if (-not $Parent) { $Parent = $BlueCatSession.idConfig }

        if ($CIDR) {
            $Query = "addIP4BlockByCIDR?parentId=$($Parent)&CIDR=$($CIDR)"
            Write-Verbose "Attempting to add CIDR block: $($CIDR) to entity #$($Parent)"
        } else {
            $Query = "addIP4BlockByRange?parentId=$($Parent)&start=$($Start)&end=$($End)"
            Write-Verbose "Attempting to add range: $($Start)-$($End) to entity #$($Parent)"
        }

        if ($PropertyObject) {
            $PropertyString = $PropertyObject | Convert-BlueCatPropertyObject
        }

        if ($PropertyString -or $Name) {
            $Query += "&properties="
            if ($PropertyString) { $Query += $PropertyString }
            if ($Name)           { $Query += "name=$([uri]::EscapeDataString($Name))|" }
        }

        Write-Verbose "$Query"
        $result = Invoke-BlueCatApi -BlueCatSession $BlueCatSession -Method Post -Request $Query
        if (-not $result) {
            throw "Add-BlueCatIP4Block: Failed to create new IP4 block"
        }

        if ($PassThru) { Get-BlueCatEntityById -BlueCatSession $BlueCatSession -ID $result }
    }
}
