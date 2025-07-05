Function Get-BlueCatMX {
    [cmdletbinding()]
    param(
        [Parameter(Mandatory)]
        [Alias('HostName')]
        [string] $Name,

        [Parameter(ParameterSetName='ViewID')]
        [int]$ViewID,

        [Parameter(ParameterSetName='ViewObj',Mandatory)]
        [ValidateNotNullOrEmpty()]
        [PSCustomObject] $View,

        [Parameter(ValueFromPipeline)]
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
        $FQDN = $Name.TrimEnd('\.')

        # Standardize lookups and retrieved information
        $Resolved = Resolve-BlueCatFQDN -FQDN $FQDN -ViewID $ViewID -BlueCatSession $BlueCatSession

        # Warn that a possibly conflicting external host record was also found
        if ($Resolved.external) {
            Write-Warning "$($thisFN): Found External Host '$($Resolved.name)' (ID:$($Resolved.external.id))"
        }

        # Use the resolved zone info to build a new query and retrieve the MX record(s)
        $Query = "getEntitiesByName?parentId=$($Resolved.zone.id)&type=MXRecord&start=0&count=100&name=$($Resolved.shortName)"
        $result = Invoke-BlueCatApi -Method Get -Request $Query -BlueCatSession $BlueCatSession

        if ($result.Count) {
            # Loop through the results and build an object
            [PSCustomObject[]] $MXarray = @()
            foreach ($bit in $result.SyncRoot) {
                $MXentry = $bit | Convert-BlueCatReply -BlueCatSession $BlueCatSession
                Write-Verbose "$($thisFN): Selected MX #$($MXentry.id) as $($MXentry.property.linkedRecordName) (Priority $($MXentry.property.priority)) for $($MXentry.name)"
                $MXarray += $MXentry
            }
            $MXobj = New-Object -TypeName PSCustomObject
            $MXobj | Add-Member -MemberType NoteProperty -Name name      -Value $Name.TrimEnd('\.')
            $MXobj | Add-Member -MemberType NoteProperty -Name type      -Value 'MXList'
            $MXobj | Add-Member -MemberType NoteProperty -Name MXList    -Value $MXarray
            $MXobj | Add-Member -MemberType NoteProperty -Name zone      -Value $Resolved.zone
            $MXobj | Add-Member -MemberType NoteProperty -Name config    -Value $Resolved.config
            $MXobj | Add-Member -MemberType NoteProperty -Name view      -Value $Resolved.view
            $MXobj | Add-Member -MemberType NoteProperty -Name shortName -Value $Resolved.shortName
            $MXobj | Add-Member -MemberType NoteProperty -Name Count     -Value $result.Count
            $MXobj | Add-Member -MemberType NoteProperty -Name Length    -Value $result.Length

            # Return the MX object to caller
            $MXobj
        }
    }
}
