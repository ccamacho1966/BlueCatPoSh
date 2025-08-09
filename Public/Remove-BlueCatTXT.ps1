function Remove-BlueCatTXT {
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
        [Alias('TXTName')]
        [string] $Name,

        [Parameter(ParameterSetName='byNameViewID',Mandatory)]
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

            if ($View) {
                if (-not $View.ID) {
                    $FailureMessage = "$($thisFN): Invalid View Object"
                    Write-Verbose $FailureMessage
                    throw $FailureMessage
                }

                if ($View.type -ne 'View') {
                    $FailureMessage = "$($thisFN): Not a View - $($View.Name) is type '$($View.type)'"
                    Write-Verbose $FailureMessage
                    throw $FailureMessage
                }
            } else {
                $View = Get-BlueCatView -ViewID $ViewID -BlueCatSession $BlueCatSession
            }

            $BlueCatReply = Get-BlueCatTXT -Name $Name -View $View -BlueCatSession $BlueCatSession

            if ($BlueCatReply.Count -eq 1) {
                # Only 1 record so update $Object and continue
                $Object = $BlueCatReply[0]
            } elseif ($BlueCatReply.Count -gt 1) {
                # Multiple TXT records so call this function recursively
                foreach ($TXTRecord in $BlueCatReply) {
                    Remove-BlueCatTXT -Object $TXTRecord -BlueCatSession $BlueCatSession
                }

                # All TXT records have been submitted for deletion so return now
                return
            }

            # 0 records returned will result in a NULL $Object and the next code block will throw an error
        }

        if (-not $Object) {
            if ($ID) {
                $FailureMessage = "$($thisFN): Failed to convert Entity ID #$($ID) to a TXT Record"
            } else {
                $FailureMessage = "$($thisFN): Failed to convert Name '$($Name)' in View '$($View.name)' to a TXT Record"
            }
            Write-Verbose $FailureMessage
            throw $FailureMessage
        }

        if (-not $Object.ID) {
            $FailureMessage = "$($thisFN): Invalid TXT Object"
            Write-Verbose $FailureMessage
            throw $FailureMessage
        }

        if ($Object.type -ne 'TXTRecord') {
            $FailureMessage = "$($thisFN): Not a TXT Record - $($Object.Name) is type '$($Object.type)'"
            Write-Verbose $FailureMessage
            throw $FailureMessage
        }

        $DeleteTXT = @{
            ID             = $Object.ID
            BlueCatSession = $BlueCatSession
        }

        Write-Verbose "$($thisFN): Deleting TXT record for '$($Object.Name)' (ID:$($Object.ID))"
        Remove-BlueCatEntityById @DeleteTXT
    }
}
