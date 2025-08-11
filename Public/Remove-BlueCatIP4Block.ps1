function Remove-BlueCatIP4Block {
<#
.SYNOPSIS
    Remove an IP4 Block definition
.DESCRIPTION
    The Remove-BlueCatIP4Block cmdlet allows the removal of an IP4 Block definition.
.PARAMETER CIDR
    A string value that represents the IP4 Block in CIDR notation, such as '10.10.10.0/24'.
.PARAMETER StartIP
    A string value that represents the first IP4 Address in a Ranged IP4 Block.
.PARAMETER EndIP
    A string value that represents the last IP4 Address in a Ranged IP4 Block.
.PARAMETER ID
    An integer value representing the entity ID of the IP4 Block to be removed.
.PARAMETER Object
    A PSCustomObject representing the IP4 Block to be removed.
.PARAMETER Parent
    A PSCustomObject that represents the IP4 Block or Configuration to be searched.

    If the supplied parent is not the direct parent of the IP4 Block then Get-BlueCatIPContainerByIP will be used to search for the IP4 Block under the parent.
    If the parent is not supplied for a CIDR or StartIP-EndIP Block then the library will attempt to use the default configuration as the parent.
.PARAMETER ParentID
    An integer value that represents the entity ID of the IP4 Block or Configuration to be searched.

    If the supplied parent is not the direct parent of the IP4 Block then Get-BlueCatIPContainerByIP will be used to search for the IP4 Block under the parent.
.PARAMETER BlueCatSession
    A BlueCat object representing the session to be used for this object operation.
.EXAMPLE
    PS> Remove-BlueCatIP4Block -ParentID 1218 -CIDR '10.0.0.0/8'

    Removes the IP4 Block '10.0.0.0/8' or throws an error if the IP4 Block is not found.
    BlueCatSession will default to the current default session.
    The record will be searched for under entity ID 1218.
    An error will be thrown if entity ID 1218 is not an IP4 Block or Configuration.
.EXAMPLE
    PS> Remove-BlueCatIP4Block -Parent $BigIP4Block -StartIP '10.10.8.0' -EndIP '10.10.10.255' -BlueCatSession $Session3

    Removes the IP4 Block '10.10.8.0-10.10.10.255' or throws an error if the IP4 Block is not found.
    Use the BlueCatSession associated with $Session3 to perform this operation.
    The record will be searched for under the entity represented by $BigIP4Block.
.EXAMPLE
    PS> Remove-BlueCatIP4Block -ID 1019

    Removes the IP4 Block with entity ID 1019 or throws an error if the IP4 Block is not found.
    BlueCatSession will default to the current default session.
    Parent will be automatically selected based on the entity ID.
.EXAMPLE
    PS> $IP4Block | Remove-BlueCatIP4Block

    Removes the IP4 Block represented by $IP4Block which is passed on the pipeline.
    BlueCatSession will default to the current default session.
    Parent will be automatically selected based on the entity information.
.INPUTS
    PSCustomObject representing the IP4 Block to be removed.
.OUTPUTS
    None
#>
    [CmdletBinding(DefaultParameterSetName='byID')]

    param(
        [Parameter(ParameterSetName='byID',Mandatory)]
        [ValidateRange(1, [int]::MaxValue)]
        [Alias('EntityID','BlockID')]
        [int] $ID,

        [Parameter(ParameterSetName='byObj',Mandatory,ValueFromPipeline)]
        [ValidateNotNullOrEmpty()]
        [Alias('Entity','Block','IP4Block')]
        [PSCustomObject] $Object,

        [Parameter(Mandatory,ParameterSetName='byCIDRParentID')]
        [Parameter(Mandatory,ParameterSetName='byCIDRParentObj')]
        [ValidateNotNullOrEmpty()]
        [string] $CIDR,

        [Parameter(Mandatory,ParameterSetName='byRangeParentID')]
        [Parameter(Mandatory,ParameterSetName='byRangeParentObj')]
        [string] $StartIP,

        [Parameter(Mandatory,ParameterSetName='byRangeParentID')]
        [Parameter(Mandatory,ParameterSetName='byRangeParentObj')]
        [string] $EndIP,

        [Parameter(Mandatory,ParameterSetName='byCIDRParentID')]
        [Parameter(Mandatory,ParameterSetName='byRangeParentID')]
        [Alias('ContainerID')]
        [ValidateRange(1, [int]::MaxValue)]
        [int] $ParentID,

        [Parameter(Mandatory,ParameterSetName='byCIDRParentObj')]
        [Parameter(Mandatory,ParameterSetName='byRangeParentObj')]
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

        if ((-not $ID) -and (-not $Object)) {
            # Convert the supplied CIDR or Range into an IP4Block Object
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

            # Setup the Search Parameters
            $SearchParms = @{
                Parent         = $Parent
                BlueCatSession = $BlueCatSession
            }
            if ($CIDR) {
                $SearchParms.CIDR    = $CIDR
            } else {
                $SearchParms.StartIP = $StartIP
                $SearchParms.EndIP   = $EndIP
            }

            # Try a direct grab of the IP4 Block
            $Object = Get-BlueCatIP4Blocks @SearchParms

            if (-not $Object) {
                # Try Get-BlueCatIPContainerByIP to find a match
                $SearchParms = @{
                    Parent         = $Parent
                    Type           = 'IP4Block'
                    BlueCatSession = $BlueCatSession
                }
                if ($CIDR) {
                    $SearchParms.Address = (($CIDR -split '/')[0])
                } else {
                    $SearchParms.Address = $StartIP
                }
                $BlueCatReply = Get-BlueCatIPContainerByIP @SearchParms
                if ($CIDR -and ($BlueCatReply.property.CIDR -eq $CIDR)) {
                    $Object = $BlueCatReply
                } elseif (($BlueCatReply.property.start -eq $StartIP) -and ($BlueCatReply.property.end -eq $EndIP)) {
                    $Object = $BlueCatReply
                }
            }

            # If we couldn't find an IP4 Block the next code block will throw an error
        }

        # If we have no IP4 Block object by this point, throw a terminating error
        if (-not $Object) {
            if ($ID) {
                $FailureMessage = "$($thisFN): Failed to convert Entity ID #$($ID) to an IP4 Block"
            } elseif ($CIDR) {
                $FailureMessage = "$($thisFN): Failed to convert CIDR '$($CIDR)' under $($Parent.type) '$($Parent.name)' to an IP4 Block"
            } else {
                $FailureMessage = "$($thisFN): Failed to convert Range '$($StartIP)-$($EndIP)' under $($Parent.type) '$($Parent.name)' to an IP4 Block"
            }
            Write-Verbose $FailureMessage
            throw $FailureMessage
        }

        if (-not $Object.ID) {
            $FailureMessage = "$($thisFN): Invalid IP4 Block Object"
            Write-Verbose $FailureMessage
            throw $FailureMessage
        }

        if ($Object.type -ne 'IP4Block') {
            $FailureMessage = "$($thisFN): Not an IP4 Block - $($Object.Name) is type '$($Object.type)'"
            Write-Verbose $FailureMessage
            throw $FailureMessage
        }

        $DeleteIP4 = @{
            ID             = $Object.ID
            BlueCatSession = $BlueCatSession
        }

        Write-Verbose "$($thisFN): Deleting IP4 Block '$($Object.Name)' (ID:$($Object.ID))"
        Remove-BlueCatEntityById @DeleteIP4
    }
}
