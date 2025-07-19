function Add-BlueCatIP4Block {
<#
.SYNOPSIS
    Create a new IP4 Block definition.
.DESCRIPTION
    The Add-BlueCatIP4Block cmdlet will create a new IP4 Block definition.

    IP4 Blocks can be created directly under configurations or other larger IP4 Blocks. They can contain smaller IP4 Blocks or IP4 Networks. They are a required building block in the BlueCat IPAM system as IP4 Networks cannot be defined directly under a Configuration.
.PARAMETER Name
    (Optional) A string value representing the name for the new IP4 Block
.PARAMETER CIDR
    A string value representing an IP4 block using CIDR notation.
.PARAMETER StartIP
    A string value representing the first IP address in the IP4 block (Range Definition).
.PARAMETER EndIP
    A string value representing the last IP address in the IP4 block (Range Definition).
.PARAMETER ParentID
    An integer value representing the entity ID of the desired parent configuration or IP4 block.

    If a Parent is not specified, the cmdlet will attempt to use the default session configuration. If no default configuration has been set, the cmdlet will throw an error.
.PARAMETER BlueCatSession
    A BlueCat object representing the session to be used for this object creation.
.PARAMETER PassThru
    A switch that causes a PSCustomObject representing the new IP4 Block to be returned.
.EXAMPLE
    PS> Add-BlueCatIP4Block -CIDR '10.90.0.0/16'

    Create an unnamed IP4 Block for CIDR 10.90.0.0/16 using the default BlueCat session and default Configuration.
.EXAMPLE
    PS> Add-BlueCatIP4Block -Start 10.10.8.0 -End 10.10.13.255 -Name 'Database Networks' -Parent 1414 -BlueCatSession $Session4 -PassThru

    Create a ranged IP4 Block 10.10.8.0-10.10.13.255 named 'Database Networks'.
    Place the new IP4 Block under the IP4 Block with entity ID #1414.
    Use the BlueCat session associated with the BlueCat object $Session4.
    Return a PSCustomObject representing the new IP4 Block.
.INPUTS
    None
.OUTPUTS
    None, by default.

    If the '-PassThru' switch is used, a PSCustomObject representing the new IP4 Block will be returned.
#>
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
        [Alias('StartAddress','Start')]
        [string] $StartIP,

        [Parameter(Mandatory,ParameterSetName='Range')]
        [ValidateNotNullOrEmpty()]
        [Alias('EndAddress','End')]
        [string] $EndIP,

        [Parameter()]
        [ValidateRange(1, [int]::MaxValue)]
        [Alias('Parent')]
        [int] $ParentID,

        [Parameter()]
        [ValidateNotNullOrEmpty()]
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

        if (-not $ParentID) {
            $BlueCatSession | Confirm-Settings -Config
            $ParentID = $BlueCatSession.idConfig
        }

        # Confirm that the provided parent ID is for an IP4 block or Configuration
        $BlockCheck = Get-BlueCatEntityById -ID $ParentID -BlueCatSession $BlueCatSession
        if ($BlockCheck.type -notin ('IP4Block','Configuration')) {
            throw "ID:$($ParentID) type is not IP4Block or Configuration (Type: $($BlockCheck.type))"
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
            $Query = "addIP4BlockByCIDR?parentId=$($ParentID)&CIDR=$($CIDR)"
            Write-Verbose "$($thisFN): Add CIDR block $($CIDR) to $($BlockDescription)"
        } else {
            $Query = "addIP4BlockByRange?parentId=$($ParentID)&start=$($StartIP)&end=$($EndIP)"
            Write-Verbose "$($thisFN): Add range $($StartIP)-$($EndIP) to $($BlockDescription)"
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
        $BlueCatReply = Invoke-BlueCatApi -Method Post -Request $Query -BlueCatSession $BlueCatSession
        if (-not $BlueCatReply) {
            throw "$($thisFN): Failed to create new IP4 block"
        }

        if ($PassThru) {
            Get-BlueCatEntityById -ID $BlueCatReply -BlueCatSession $BlueCatSession
        }
    }
}
