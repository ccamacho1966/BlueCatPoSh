function Remove-BlueCatMX {
<#
.SYNOPSIS
    Remove one of more MX records
.DESCRIPTION
    The Remove-BlueCatMX cmdlet allows the removal of DNS MX records.
.PARAMETER Name
    A string value representing the FQDN of the MX records to be removed.

    NOTE: This will remove ALL MX records for the named FQDN.
.PARAMETER ID
    An integer value representing the entity ID of the MX record to be removed.
.PARAMETER Object
    A PSCustomObject representing the MX record to be removed.
.PARAMETER ViewID
    An integer value representing the entity ID of the desired view.
.PARAMETER View
    A PSCustomObject representing the desired view.
.PARAMETER BlueCatSession
    A BlueCat object representing the session to be used for this object operation.
.EXAMPLE
    PS> Remove-BlueCatMX -Name server1.example.com

    Removes all MX records for 'server1.example.com' or throws an error if none are found.
    BlueCatSession will default to the current default session.
    View will default to the BlueCatSession default view.
.EXAMPLE
    PS> Remove-BlueCatMX -Name server9.example.com -ViewID 23456 -BlueCatSession $Session3

    Removes all MX records for 'server9.example.com' or throws an error if none are found.
    Use the BlueCatSession associated with $Session3 to perform this operation.
    The record will be searched for in view 23456.
.EXAMPLE
    PS> Remove-BlueCatMX -ID 10129

    Removes the MX record with entity ID 10129 or throws an error if the MX record is not found.
    BlueCatSession will default to the current default session.
    View will be automatically selected based on the entity ID.
.EXAMPLE
    PS> $MXObject | Remove-BlueCatMX

    Removes the MX record represented by $MXObject which is passed on the pipeline.
    BlueCatSession will default to the current default session.
    View will be automatically selected based on the entity information.
.INPUTS
    PSCustomObject representing the MX record to be removed.
.OUTPUTS
    None
#>
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
        [Alias('MXName')]
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

            $BlueCatReply = Get-BlueCatMX -Name $Name -View $View -BlueCatSession $BlueCatSession

            if ($BlueCatReply.Count -eq 1) {
                # Only 1 record so update $Object and continue
                $Object = $BlueCatReply[0]
            } elseif ($BlueCatReply.Count -gt 1) {
                # Multiple MX records so call this function recursively
                foreach ($MXRecord in $BlueCatReply) {
                    Remove-BlueCatMX -Object $MXRecord -BlueCatSession $BlueCatSession
                }

                # All MX records have been submitted for deletion so return now
                return
            }

            # 0 records returned will result in a NULL $Object and the next code block will throw an error
        }

        if (-not $Object) {
            if ($ID) {
                $FailureMessage = "$($thisFN): Failed to convert Entity ID #$($ID) to an MX Record"
            } else {
                $FailureMessage = "$($thisFN): Failed to convert Name '$($Name)' in View '$($View.name)' to an MX Record"
            }
            Write-Verbose $FailureMessage
            throw $FailureMessage
        }

        if (-not $Object.ID) {
            $FailureMessage = "$($thisFN): Invalid MX Object"
            Write-Verbose $FailureMessage
            throw $FailureMessage
        }

        if ($Object.type -ne 'MXRecord') {
            $FailureMessage = "$($thisFN): Not an MX Record - $($Object.Name) is type '$($Object.type)'"
            Write-Verbose $FailureMessage
            throw $FailureMessage
        }

        $DeleteMX = @{
            ID             = $Object.ID
            BlueCatSession = $BlueCatSession
        }

        Write-Verbose "$($thisFN): Deleting MX record for '$($Object.Name)' (ID:$($Object.ID))"
        Remove-BlueCatEntityById @DeleteMX
    }
}
