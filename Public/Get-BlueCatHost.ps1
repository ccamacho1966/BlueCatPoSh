function Get-BlueCatHost {
    [CmdletBinding(DefaultParameterSetName='ViewID')]

    param(
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [Alias('HostName')]
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
            Write-Verbose "$($thisFN): Using default view '$($BlueCatSession.View)' (ID:$($BlueCatSession.idView))"
            $ViewID = $BlueCatSession.idView
        }

        # Trim any trailing dots from the name for consistency/display purposes
        $FQDN = $Name | Test-ValidFQDN

        # Standardize lookups and retrieved information
        $Resolved = Resolve-BlueCatFQDN -FQDN $FQDN -ViewID $ViewID -BlueCatSession $BlueCatSession

        # Warn that a possibly conflicting external host record was also found
        if ($Resolved.external) {
            Write-Warning "$($thisFN): Found External Host '$($Resolved.name)' (ID:$($Resolved.external.id))"
        }

        # Validate that a host object was returned
        $HostObj = $Resolved.host
        if (!$HostObj.id) { throw "No Host record found for $($FQDN)" }

        # Reduce redundant API calls by using zone information returned by Resolve-BlueCatFQDN
        $HostObj | Add-Member -MemberType NoteProperty -Name zone -Value $Resolved.zone
        Write-Verbose "$($thisFN): Selected #$($HostObj.id) as '$($HostObj.name)' (Zone #$($HostObj.zone.id) as '$($HostObj.zone.name)')"

        # Return the host object to caller
        $HostObj
    }
}
