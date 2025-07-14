Function Get-BlueCatSRV {
    [CmdletBinding()]

    param(
        [Parameter(Mandatory)]
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
                throw "Invalid View object passed to $($thisFN)!"
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

        # Use the resolved zone info to build a new query and retrieve the SRV record(s)
        $Query = "getEntitiesByName?parentId=$($Resolved.zone.id)&type=SRVRecord&start=0&count=100&name=$($Resolved.shortName)"
        [PSCustomObject[]] $BlueCatReply = Invoke-BlueCatApi -Method Get -Request $Query -BlueCatSession $BlueCatSession

        if ($BlueCatReply.Count) {
            # Loop through the results and build an object
            [PSCustomObject[]] $SRVList = @()
            foreach ($entry in $BlueCatReply) {
                $SRVentry  = $entry | Convert-BlueCatReply -BlueCatSession $BlueCatSession
                $SRVrecord = @{
                    id       = $SRVentry.id
                    target   = $SRVentry.property.linkedRecordName
                    port     = $SRVentry.property.port
                    priority = $SRVentry.property.priority
                    weight   = $SRVentry.property.weight
                }
                if ($SRVentry.property.ttl) {
                    $SRVrecord.ttl = $SRVentry.property.ttl
                }
                Write-Verbose "$($thisFN): SRV ID:$($SRVrecord.id) for $($FQDN) links to $($SRVrecord.target):$($SRVrecord.port) (Priority=$($SRVrecord.priority), Weight=$($SRVrecord.weight))"
                $SRVList += [PSCustomObject] $SRVrecord
            }
            $SRVobj = New-Object -TypeName PSCustomObject
            $SRVobj | Add-Member -MemberType NoteProperty -Name name      -Value $FQDN
            $SRVobj | Add-Member -MemberType NoteProperty -Name type      -Value 'SRVList'
            $SRVobj | Add-Member -MemberType NoteProperty -Name SRVList   -Value $SRVList
            $SRVobj | Add-Member -MemberType NoteProperty -Name shortName -Value $Resolved.shortName
            $SRVobj | Add-Member -MemberType NoteProperty -Name zone      -Value $Resolved.zone
            $SRVobj | Add-Member -MemberType NoteProperty -Name config    -Value $Resolved.config
            $SRVobj | Add-Member -MemberType NoteProperty -Name view      -Value $Resolved.view

            # Return the SRV object to caller
            $SRVobj
        }
    }
}
