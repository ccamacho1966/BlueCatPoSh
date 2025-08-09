function Remove-BlueCatIP4Block {
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
