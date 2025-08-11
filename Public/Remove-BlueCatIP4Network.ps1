function Remove-BlueCatIP4Network {
<#
.SYNOPSIS
    Remove an IP4 Network definition
.DESCRIPTION
    The Remove-BlueCatIP4Network cmdlet allows the removal of an IP4 Network definition.
.PARAMETER CIDR
    A string value that represents the IP4 Network in CIDR notation, such as '10.10.10.0/24'.
.PARAMETER ID
    An integer value representing the entity ID of the IP4 Network to be removed.
.PARAMETER Object
    A PSCustomObject representing the IP4 Network to be removed.
.PARAMETER Parent
    A PSCustomObject that represents the IP4 Block or Configuration to be searched.

    If the supplied parent is not the direct parent of the IP4 Network then Get-BlueCatIPContainerByIP will be used to search for the IP4 Network under the parent.
    If the parent is not supplied for a CIDR Network then the library will attempt to use the default configuration as the parent.
.PARAMETER ParentID
    An integer value that represents the entity ID of the IP4 Block or Configuration to be searched.

    If the supplied parent is not the direct parent of the CIDR Network then Get-BlueCatIPContainerByIP will be used to search for the IP4 Network under the parent.
.PARAMETER BlueCatSession
    A BlueCat object representing the session to be used for this object operation.
.EXAMPLE
    PS> Remove-BlueCatIP4Network -ParentID 1148 -CIDR '10.20.10.0/24'

    Removes the IP4 Network '10.20.10.0/24' or throws an error if the IP4 Network is not found.
    BlueCatSession will default to the current default session.
    The record will be searched for under entity ID 1218.
    An error will be thrown if entity ID 1148 is not an IP4 Block or Configuration.
.EXAMPLE
    PS> Remove-BlueCatIP4Network -Parent $BigIP4Block -CIDR '10.10.10.0/24' -BlueCatSession $Session3

    Removes the IP4 Network '10.10.10.0/24' or throws an error if the IP4 Network is not found.
    Use the BlueCatSession associated with $Session3 to perform this operation.
    The record will be searched for under the entity represented by $BigIP4Block.
.EXAMPLE
    PS> Remove-BlueCatIP4Network -ID 1219

    Removes the IP4 Network with entity ID 1219 or throws an error if the IP4 Network is not found.
    BlueCatSession will default to the current default session.
    Parent will be automatically selected based on the entity ID.
.EXAMPLE
    PS> $IP4Network | Remove-BlueCatIP4Network

    Removes the IP4 Network represented by $IP4Network which is passed on the pipeline.
    BlueCatSession will default to the current default session.
    Parent will be automatically selected based on the entity information.
.INPUTS
    PSCustomObject representing the IP4 Network to be removed.
.OUTPUTS
    None
#>
    [CmdletBinding(DefaultParameterSetName='byID')]
    param(
        [Parameter(ParameterSetName='byID',Mandatory)]
        [ValidateRange(1, [int]::MaxValue)]
        [Alias('EntityID','NetworkID')]
        [int] $ID,

        [Parameter(ParameterSetName='byObj',Mandatory,ValueFromPipeline)]
        [ValidateNotNullOrEmpty()]
        [Alias('Entity','Network','IP4Network')]
        [PSCustomObject] $Object,

        [Parameter(Mandatory,ParameterSetName='byCIDRParentID')]
        [Parameter(Mandatory,ParameterSetName='byCIDRParentObj')]
        [ValidateNotNullOrEmpty()]
        [string] $CIDR,

        [Parameter(Mandatory,ParameterSetName='byCIDRParentID')]
        [Alias('ContainerID')]
        [ValidateRange(1, [int]::MaxValue)]
        [int] $ParentID,

        [Parameter(Mandatory,ParameterSetName='byCIDRParentObj')]
        [Alias('Container')]
        [ValidateNotNullOrEmpty()]
        [PSCustomObject] $Parent,

        [Parameter()]
        [Alias('Connection','Session')]
        [BlueCat] $BlueCatSession = $Script:BlueCatSession
    )

    begin {
        Get-CallerPreference -Cmdlet $PSCmdlet -SessionState $ExecutionContext.SessionState
        if (-not $BlueCatSession) { throw 'No active BlueCatSession found' }
    }

    process {
        $thisFN = (Get-PSCallStack)[0].Command

        if ($ID) {
            # Convert the Entity ID into an Entity Object to use the object logic
            $Object = Get-BlueCatEntityById -ID $ID -BlueCatSession $BlueCatSession
        }

        if ($CIDR) {
            # Convert the supplied CIDR into an IP4Network Object
            if ($ParentID) {
                # Convert the Parent ID into a Parent Object
                $Parent = Get-BlueCatEntityById -ID $ParentID -BlueCatSession $BlueCatSession
            } elseif (-not $Parent) {
                # No Parent ID or Object - Attempt to use the default configuration
                $BlueCatSession | Confirm-Settings -Config
                $Parent = $BlueCatSession.config
                Write-Verbose "$($thisFN): Using default configuration '$($Parent.name)' (ID:$($Parent.id))"
            }

            # Validate the Parent Object
            if (-not $Parent.ID) {
                $FailureMessage = "$($thisFN): Invalid Parent Object"
                Write-Verbose $FailureMessage
                throw $FailureMessage
            }

            # Validate the Parent is an IP4 Block or Configuration
            if ($Parent.type -notin ('IP4Block','Configuration')) {
                $FailureMessage = "$($thisFN): Parent not an IP4Block or Configuration - $($Parent.Name) is type '$($Parent.type)'"
                Write-Verbose $FailureMessage
                throw $FailureMessage
            }

            # Is the Parent an IP4 Block..?
            if ($Parent.type -eq 'IP4Block') {
                # Try a direct grab of the IP4 Network
                $Object = Get-BlueCatIP4Networks -Block $Parent -CIDR $CIDR -BlueCatSession $BlueCatSession
            }

            if (-not $Object) {
                # Try Get-BlueCatIPContainerByIP to find a match
                $SearchParms = @{
                    Parent         = $Parent
                    Address        = (($CIDR -split '/')[0])
                    Type           = 'IP4Network'
                    BlueCatSession = $BlueCatSession
                }
                $Object  = Get-BlueCatIPContainerByIP @SearchParms
            }

            # If we couldn't find an IP4 Network the next code block will throw an error
        }

        # If we have no IP4 Network object by this point, throw a terminating error
        if (-not $Object) {
            if ($ID) {
                $FailureMessage = "$($thisFN): Failed to convert Entity ID #$($ID) to an IP4 Network"
            } else {
                $FailureMessage = "$($thisFN): Failed to convert CIDR '$($CIDR)' under $($Parent.type) '$($Parent.name)' to an IP4 Network"
            }
            Write-Verbose $FailureMessage
            throw $FailureMessage
        }

        if (-not $Object.ID) {
            $FailureMessage = "$($thisFN): Invalid IP4 Network Object"
            Write-Verbose $FailureMessage
            throw $FailureMessage
        }

        if ($Object.type -ne 'IP4Network') {
            $FailureMessage = "$($thisFN): Not an IP4 Network - $($Object.Name) is type '$($Object.type)'"
            Write-Verbose $FailureMessage
            throw $FailureMessage
        }

        $DeleteIP4 = @{
            ID             = $Object.ID
            BlueCatSession = $BlueCatSession
        }

        Write-Verbose "$($thisFN): Deleting IP4 Network '$($Object.Name)' (ID:$($Object.ID))"
        Remove-BlueCatEntityById @DeleteIP4
    }
}
