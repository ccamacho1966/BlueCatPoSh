function Get-BlueCatExternalHost {
    [CmdletBinding(DefaultParameterSetName='ViewID')]

    param(
        [Parameter(Mandatory, ValueFromPipeline)]
        [Alias('ExternalHost')]
        [string] $Name,

        [Parameter(ParameterSetName='ViewID')]
        [ValidateRange(1, [int]::MaxValue)]
        [int]$ViewID,

        [Parameter(ParameterSetName='ViewObj',Mandatory)]
        [ValidateNotNullOrEmpty()]
        [PSCustomObject] $View,

        [Parameter()]
        [Alias('Connection','Session')]
        [BlueCat] $BlueCatSession = $Script:BlueCatSession
    )

    begin { Get-CallerPreference -Cmdlet $PSCmdlet -SessionState $ExecutionContext.SessionState }

    process {
        $thisFN = (Get-PSCallStack)[0].Command

        if ($View) {
            # A view object has been passed in so test its validity
            if (-not $View.ID) {
                # This is not a valid view object!
                throw "Invalid View object passed to function!"
            }
            # Use the view ID from the View object
            $ViewID = $View.ID
        }

        if (-not $ViewID) {
            # No view ID has been passed in so attempt to use the default view
            $BlueCatSession | Confirm-Settings -View
            Write-Verbose "$($thisFN): Using default view '$($BlueCatSession.View.name)' (ID:$($BlueCatSession.View.id))"
            $ViewID = $BlueCatSession.View.id
        }

        $xHost = $Name | Test-ValidFQDN

        $Query = "getEntityByName?parentId=$($ViewID)&name=$($xHost)&type=ExternalHostRecord"
        $BlueCatReply = Invoke-BlueCatApi -Method Get -Request $Query -BlueCatSession $BlueCatSession

        if (-not $BlueCatReply.id) {
            # Record not found. Return nothing/null.
            Write-Verbose "$($thisFN): External Host Record for '$($xHost)' not found: $($BlueCatReply)"
        } else {
            # Found the external host - return the result
            Write-Verbose "$($thisFN): Selected #$($BlueCatReply.id) as '$($BlueCatReply.name)'"

            # Build the full object and return
            $BlueCatReply | Convert-BlueCatReply -BlueCatSession $BlueCatSession
        }
    }
}
