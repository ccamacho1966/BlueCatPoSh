function Remove-BlueCatEntityById {
    [CmdletBinding()]

    param(
        [parameter(Mandatory)]
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
