function Add-BlueCatIP4Block {
    [CmdletBinding()]

    param(
        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [string] $Name,

        [Parameter(Mandatory,ParameterSetName='CIDR')]
        [ValidateNotNullOrEmpty()]
        [string] $CIDR,

        [Parameter(Mandatory,ParameterSetName='Range')]
        [ValidateNotNullOrEmpty()]
        [Alias('StartAddress')]
        [string] $Start,

        [Parameter(Mandatory,ParameterSetName='Range')]
        [ValidateNotNullOrEmpty()]
        [Alias('EndAddress')]
        [string] $End,

        [int] $Parent,

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

        if (-not $Parent) {
            $BlueCatSession | Confirm-Settings -Config
            $Parent = $BlueCatSession.idConfig
        }

        # Confirm that the provided parent ID is for an IP4 block or Configuration
        $BlockCheck = Get-BlueCatEntityById -ID $Parent -BlueCatSession $BlueCatSession
        if ($BlockCheck.type -notin ('IP4Block','Configuration')) {
            throw "ID:$($Parent) type is not IP4Block or Configuration (Type: $($BlockCheck.type))"
        }

        if ($CIDR) {
            $Query = "addIP4BlockByCIDR?parentId=$($Parent)&CIDR=$($CIDR)"
            Write-Verbose "Attempting to add CIDR block: $($CIDR) to entity #$($Parent)"
        } else {
            $Query = "addIP4BlockByRange?parentId=$($Parent)&start=$($Start)&end=$($End)"
            Write-Verbose "Attempting to add range: $($Start)-$($End) to entity #$($Parent)"
        }

        if ($Property.Name -and $Name) {
            Write-Warning "$($thisFN): Overwriting Property.Name ($($Property.Name)) with specified name ($($Name))"
            $Property.Name = $Name
        } elseif ($Property -and $Name) {
            $Property | Add-Member -MemberType NoteProperty -Name 'name' -Value $Name
        } elseif ($Name) {
            $Property = [PSCustomObject] @{ name = $Name }
        }

        if ($Property.Name) {
            $Property.Name = [uri]::EscapeDataString($Property.Name)
        }

        if ($Property) {
            $PropertyString = $Property | Convert-BlueCatPropertyObject
        }

        if ($PropertyString) {
            $Query += "&properties=$($PropertyString)"
        }

        Write-Verbose "$Query"
        $BlueCatReply = Invoke-BlueCatApi -BlueCatSession $BlueCatSession -Method Post -Request $Query
        if (-not $BlueCatReply) {
            throw "$($thisFN): Failed to create new IP4 block"
        }

        if ($PassThru) {
            Get-BlueCatEntityById -ID $BlueCatReply -BlueCatSession $BlueCatSession
        }
    }
}
