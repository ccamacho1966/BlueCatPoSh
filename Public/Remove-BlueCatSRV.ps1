function Remove-BlueCatSRV {
    [CmdletBinding(DefaultParameterSetName='byID')]

    param(
        [Parameter(ParameterSetName='byID',Mandatory)]
        [ValidateRange(1, [int]::MaxValue)]
        [Alias('EntityID')]
        [int] $ID,

        [Parameter(ParameterSetName='byObj',Mandatory,ValueFromPipeline)]
        [ValidateNotNullOrEmpty()]
        [Alias('Entity')]
        [PSCustomObject] $Object,

        [Parameter(ParameterSetName='byNameViewID',Mandatory)]
        [Parameter(ParameterSetName='byNameViewObj',Mandatory)]
        [ValidateNotNullOrEmpty()]
        [Alias('SRVName')]
        [string] $Name,

        [Parameter(ParameterSetName='byNameViewID')]
        [ValidateRange(1, [int]::MaxValue)]
        [int] $ViewID,

        [Parameter(ParameterSetName='byNameViewObj',Mandatory)]
        [ValidateNotNullOrEmpty()]
        [PSCustomObject] $View,

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

        if ($Name) {
            # Convert the Name into an Entity Object to use the object logic

            if ($ViewID) {
                # Convert the ViewID into a View Object
                $View = Get-BlueCatView -ViewID $ViewID -BlueCatSession $BlueCatSession
            } elseif (-not $View) {
                # No View ID or Object - Attempt to use the default view
                $BlueCatSession | Confirm-Settings -View
                $View = $BlueCatSession.view
                Write-Verbose "$($thisFN): Using default view '$($View.name)' (ID:$($View.id))"
            }

            # Validate the View Object
            if (-not $View.ID) {
                $FailureMessage = "$($thisFN): Invalid View Object"
                Write-Verbose $FailureMessage
                throw $FailureMessage
            }

            # Validate the View Object is the correct Entity Type
            if ($View.type -ne 'View') {
                $FailureMessage = "$($thisFN): Not a View - $($View.Name) is type '$($View.type)'"
                Write-Verbose $FailureMessage
                throw $FailureMessage
            }

            $BlueCatReply = Get-BlueCatSRV -Name $Name -View $View -BlueCatSession $BlueCatSession

            if ($BlueCatReply.Count -eq 1) {
                # Only 1 record so update $Object and continue
                $Object = $BlueCatReply[0]
            } elseif ($BlueCatReply.Count -gt 1) {
                # Multiple SRV records so call this function recursively
                foreach ($SRVRecord in $BlueCatReply) {
                    Remove-BlueCatSRV -Object $SRVRecord -BlueCatSession $BlueCatSession
                }

                # All SRV records have been submitted for deletion so return now
                return
            }

            # 0 records returned will result in a NULL $Object and the next code block will throw an error
        }

        if (-not $Object) {
            if ($ID) {
                $FailureMessage = "$($thisFN): Failed to convert Entity ID #$($ID) to an SRV Record"
            } else {
                $FailureMessage = "$($thisFN): Failed to convert Name '$($Name)' in View '$($View.name)' to an SRV Record"
            }
            Write-Verbose $FailureMessage
            throw $FailureMessage
        }

        if (-not $Object.ID) {
            $FailureMessage = "$($thisFN): Invalid SRV Object"
            Write-Verbose $FailureMessage
            throw $FailureMessage
        }

        if ($Object.type -ne 'SRVRecord') {
            $FailureMessage = "$($thisFN): Not an SRV Record - $($Object.Name) is type '$($Object.type)'"
            Write-Verbose $FailureMessage
            throw $FailureMessage
        }

        $DeleteSRV = @{
            ID             = $Object.ID
            BlueCatSession = $BlueCatSession
        }

        Write-Verbose "$($thisFN): Deleting SRV record for '$($Object.Name)' (ID:$($Object.ID))"
        Remove-BlueCatEntityById @DeleteSRV
    }
}
