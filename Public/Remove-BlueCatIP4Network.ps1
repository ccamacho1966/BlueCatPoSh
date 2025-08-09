function Remove-BlueCatIP4Network {
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
