function Remove-BlueCatEntityById {
<#
.SYNOPSIS
    Remove any BlueCat Entity
.DESCRIPTION
    The Remove-BlueCatEntityById cmdlet allows the removal of any BlueCat entity.

    No sanity checking is performed by the library when deleting objects by Entity ID.
.PARAMETER ID
    An integer value representing the ID of the entity to be removed.
.PARAMETER Options
    A hashtable representing options to be passed directly to the BlueCat API.
.PARAMETER BlueCatSession
    A BlueCat object representing the session to be used for this operation.
.EXAMPLE
    PS> Remove-BlueCatEntityById -ID 10182

    Removes the entity with ID 10182 or throws an error if the entity is not found.
    BlueCatSession will default to the current default session.
.EXAMPLE
    PS> Remove-BlueCatEntityById -ID 10222 -Options @{ 'deleteOrphanedIPAddresses'=$true }

    Removes the entity with ID 10222 or throws an error if the entity is not found.
    API call will be made with "?deleteOrphanedIPAddresses=true" appended to the Uri.
    BlueCatSession will default to the current default session.
.INPUTS
    None
.OUTPUTS
    None
#>
    [CmdletBinding()]

    param(
        [Parameter(Mandatory)]
        [Alias('EntityID')]
        [ValidateRange(1, [int]::MaxValue)]
        [int] $ID,

        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [hashtable] $Options,

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

        Write-Verbose "$($thisFN): ID=$($ID)"

        $DeleteObject = @{
            Method         = 'Delete'
            BlueCatSession = $BlueCatSession
        }

        if ($Options) {
            # Handling options means using the deleteWithOptions API call
            $DeleteObject.Request = "deleteWithOptions?objectId=$($ID)"

            #Process Options hashtable
            foreach ($item in $Options.GetEnumerator()) {
                $thisKey = $item.key

                if ($item.Value.GetType().Name -eq 'Boolean') {
                    $thisValue = $item.Value.toString().toLower()
                } else {
                    $thisValue = $item.Value
                }

                $DeleteObject.Request += "&$($thisKey)=$($thisValue)"
            }
        } else {
            # Default delete API call with no options
            $DeleteObject.Request = "delete?objectId=$($ID)"
        }

        $BlueCatReply = Invoke-BlueCatApi @DeleteObject

        if ($BlueCatReply) {
            Write-Warning "$($thisFN): Unexpected reply: $($BlueCatReply)"
        }
    }
}
