Function Get-BlueCatMX {
    [CmdletBinding()]

    param(
        [Parameter(Mandatory)]
        [Alias('HostName')]
        [string] $Name,

        [Parameter(ParameterSetName='ViewID')]
        [ValidateRange(1, [int]::MaxValue)]
        [int] $ViewID,

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
            Write-Verbose "$($thisFN): Using default view '$($BlueCatSession.View.name)' (ID:$($BlueCatSession.View.id))"
            $ViewID = $BlueCatSession.View.id
        }

        # Trim any trailing dots from the name for consistency/display purposes
        $FQDN = $Name | Test-ValidFQDN

        # Standardize lookups and retrieved information
        $Resolved = Resolve-BlueCatFQDN -FQDN $FQDN -ViewID $ViewID -BlueCatSession $BlueCatSession

        # Warn that a possibly conflicting external host record was also found
        if ($Resolved.external) {
            Write-Warning "$($thisFN): Found External Host '$($Resolved.name)' (ID:$($Resolved.external.id))"
        }

        # Use the resolved zone info to build a new query and retrieve the MX record(s)
        $Query = "getEntitiesByName?parentId=$($Resolved.zone.id)&type=MXRecord&start=0&count=100&name=$($Resolved.shortName)"
        [PSCustomObject[]] $BlueCatReply = Invoke-BlueCatApi -Method Get -Request $Query -BlueCatSession $BlueCatSession

        if ($BlueCatReply.Count) {
            # Loop through the results and build an object
            [PSCustomObject[]] $MXList = @()
            foreach ($entry in $BlueCatReply) {
                $MXentry = $entry | Convert-BlueCatReply -BlueCatSession $BlueCatSession
                $MXrecord = @{
                    id       = $MXentry.id
                    relay    = $MXentry.property.linkedRecordName
                    priority = $MXentry.property.priority
                }
                if ($MXentry.property.ttl) {
                    $MXrecord.ttl = $MXentry.property.ttl
                }
                Write-Verbose "$($thisFN): Selected MX #$($MXrecord.id) for $($FQDN) ($($MXrecord.relay) Priority $($MXentry.property.priority)) for $($MXentry.name)"
                $MXList += $MXrecord
            }
            $MXobj = New-Object -TypeName PSCustomObject
            $MXobj | Add-Member -MemberType NoteProperty -Name name      -Value $FQDN
            $MXobj | Add-Member -MemberType NoteProperty -Name type      -Value 'MXList'
            $MXobj | Add-Member -MemberType NoteProperty -Name MXList    -Value $MXList
            $MXobj | Add-Member -MemberType NoteProperty -Name shortName -Value $Resolved.shortName
            $MXobj | Add-Member -MemberType NoteProperty -Name zone      -Value $Resolved.zone
            $MXobj | Add-Member -MemberType NoteProperty -Name config    -Value $Resolved.config
            $MXobj | Add-Member -MemberType NoteProperty -Name view      -Value $Resolved.view

            # Return the MX object to caller
            $MXobj
        }
    }
}
