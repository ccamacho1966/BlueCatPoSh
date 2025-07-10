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

        $BlockDescription = "$($BlockCheck.type) "
        if ($BlockCheck.name) {
            # Build description based on name
            $BlockDescription += $BlockCheck.name
        } else {
            # Configurations must be named, so this is an unnamed block
            if ($BlockCheck.property.CIDR) {
                $BlockDescription += $BlockCheck.property.CIDR
            } elseif ($BlockCheck.property.start) {
                $BlockDescription += "$($BlockCheck.property.start)-$($BlockCheck.property.end)"
            }
        }
        $BlockDescription += " (ID:$($BlockCheck.id))"

        if ($CIDR) {
            $Query = "addIP4BlockByCIDR?parentId=$($Parent)&CIDR=$($CIDR)"
            Write-Verbose "$($thisFN): Add CIDR block $($CIDR) to $($BlockDescription)"
        } else {
            $Query = "addIP4BlockByRange?parentId=$($Parent)&start=$($Start)&end=$($End)"
            Write-Verbose "$($thisFN): Add range $($Start)-$($End) to $($BlockDescription)"
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
