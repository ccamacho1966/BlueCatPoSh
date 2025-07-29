function Add-BlueCatIP4Network {
<#
.SYNOPSIS
    Create a new IP4 Network definition.
.DESCRIPTION
    The Add-BlueCatIP4Network cmdlet will create a new IP4 Network definition.

    IP4 Networks can only be created directly under IP4 Blocks. The IP4 Network must fit entirely with the parent IP4 Block.
.PARAMETER Name
    (Optional) A string value representing the name for the new IP4 Block
.PARAMETER CIDR
    A string value representing an IP4 block using CIDR notation.
.PARAMETER ParentID
    An integer value representing the entity ID of the desired parent configuration or IP4 block.

    If a Parent is not specified, the cmdlet will attempt to use the default session configuration. If no default configuration has been set, the cmdlet will throw an error.
.PARAMETER BlueCatSession
    A BlueCat object representing the session to be used for this object creation.
.PARAMETER PassThru
    A switch that causes a PSCustomObject representing the new IP4 Block to be returned.
.EXAMPLE
    PS> Add-BlueCatIP4Network -CIDR '10.90.10.0/24' -ParentID 1490

    Create an unnamed IP4 Network for CIDR 10.90.10.0/24 using the default BlueCat session.
    Place the new IP4 Network under the IP4 Block with entity ID #1490.
.EXAMPLE
    PS> Add-BlueCatIP4Block -CIDR 10.10.11.0/24 -Name 'Oracle Databases' -Parent 1491 -BlueCatSession $Session4 -PassThru

    Create an IP4 Network 10.10.11.0/24 named 'Oracle Databases'.
    Place the new IP4 Network under the IP4 Block with entity ID #1491.
    Use the BlueCat session associated with the BlueCat object $Session4.
    Return a PSCustomObject representing the new IP4 Network.
.INPUTS
    None
.OUTPUTS
    None, by default.

    If the '-PassThru' switch is used, a PSCustomObject representing the new IP4 Block will be returned.
#>
    [CmdletBinding()]

    Param(
        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [string] $Name,

        [Parameter(Mandatory)]
        [Alias('Network')]
        [string] $CIDR,

        [Parameter(Mandatory)]
        [ValidateRange(1, [int]::MaxValue)]
        [Alias('Parent','BlockID')]
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

    begin {
        Get-CallerPreference -Cmdlet $PSCmdlet -SessionState $ExecutionContext.SessionState
        if (-not $BlueCatSession) { throw 'No active BlueCatSession found' }
    }

    process {
        $thisFN = (Get-PSCallStack)[0].Command

        # Confirm that the provided parent ID is for an IP4 block
        $BlockCheck = Get-BlueCatEntityById -ID $ParentID -BlueCatSession $BlueCatSession
        if ($BlockCheck.type -ne 'IP4Block') {
            throw "ID:$($ParentID) type is not IP4Block (Type: $($BlockCheck.type))"
        }

        if ($BlockCheck.property.CIDR) {
            $BlockDescription = "$($BlockCheck.property.CIDR)"
        } elseif ($BlockCheck.property.start) {
            $BlockDescription = "$($BlockCheck.property.start)-$($BlockCheck.property.end)"
        }
        Write-Verbose "$($thisFN): Add IP4 Network $($CIDR) to IP4Block $($BlockDescription) (ID:$($ParentID))"

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

        Write-Verbose "$($thisFN): Create network [$($CIDR)] under block ID #$($ParentID)"
        $Uri = "addIP4Network?blockId=$($ParentID)&CIDR=$($CIDR)"
        if ($PropertyString) {
            Write-Verbose "$($thisFN): New property string [$($PropertyString)]"
            $Uri += "&properties=$($PropertyString)"
        }

        $BlueCatReply = Invoke-BlueCatApi -Method Post -Request $Uri -BlueCatSession $BlueCatSession
        if (-not $BlueCatReply) {
            throw "Failed to create new IP4 network $($CIDR) in block #$($ParentID)"
        }

        if ($PassThru) {
            Get-BlueCatEntityById -ID $BlueCatReply -BlueCatSession $BlueCatSession
        }
    }
}
