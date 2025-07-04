function Resolve-BlueCatFQDN {
    [cmdletbinding(DefaultParameterSetName='ViewID')]
    param(
        [parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string] $FQDN,

        [Parameter(ParameterSetName='ViewID')]
        [int]$ViewID,

        [Parameter(ParameterSetName='ViewObj',Mandatory)]
        [ValidateNotNullOrEmpty()]
        [PSCustomObject] $View,

        [Parameter()]
        [Alias('Connection','Session')]
        [BlueCat] $BlueCatSession = $Script:BlueCatSession,

        [parameter(DontShow)]
        [switch] $Quiet
    )

    begin { Get-CallerPreference -Cmdlet $PSCmdlet -SessionState $ExecutionContext.SessionState } 

    process {
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
            $ViewID = $BlueCatSession.idView
        }

        if (-not $View) {
            $View = Get-BlueCatView -ID $ViewID -BlueCatSession $BlueCatSession
        }

        # Set the starting point for the zone/FQDN search to the View
        $zId = $ViewID

        $FQDN = $FQDN.TrimEnd('\.')
        Write-Verbose "Resolve-BlueCatFQDN: Searching database for '$($FQDN)'"

        $zPath = $FQDN.Split('\.')
        [array]::Reverse($zPath)

        $zDig = $true
        $result = $null
        $notZone = $null
        foreach ($bit in $zPath) {
            if ($zDig) {
                # save the result in case this is the last bit of the zone path
                $lastResult = $result
                $Query = "getEntityByName?parentId=$($zId)&type=Zone&name=$($bit)"
                $result = Invoke-BlueCatApi -Connection $BlueCatSession -Method Get -Request $Query
                # $result.id is 0 if this bit isn't part of a valid zone path
                # stop digging for zones and assume the rest of the path is host
                if (-not $result.id) {
                    $zDig = $false
                    # load the value of bit into the first section of 'notZone' ...aka hostname
                    $notZone = $bit
                    # lastResult would only be null if we never found any zone path!
                    if (-not $lastResult) {
                        $zObj = $null
                    } else {
                        $zObj = Convert-BlueCatReply -Connection $BlueCatSession -RawObject $lastResult
                        # we matched a path, but not a deployable zone...
                        # put the entire path into 'notZone' and null out the zone object
                        if ($zObj.property.deployable -eq 'false') {
                            $notZone = "$($bit).$($zObj.property.absoluteName)"
                            $zObj = $null
                        } # zone not deployable
                    } # $lastResult is $null
                } # $result.id is 0 - zone not found

                # update the parent to this new zone and continue processing
                $zId=$result.id
            } # if ($zDig)
            else {
                # we're done zone digging - append everything else to 'notZone'
                $notZone = "$($bit).$($notZone)"
            }
        } # foreach ($bit in $zPath)

        # we matched a deployable zone exactly - hostname same as zone!
        if ($lastResult -and ($null -eq $notZone)) {
            $zObj = $result | Convert-BlueCatReply -BlueCatSession $BlueCatSession
            # set notZone to a blank string and retrieve the zone info!
            $notZone = ''
            if ($zObj.property.deployable -eq 'false') {
                $notZone = "$($bit).$($zObj.property.absoluteName)"
                $zObj = $null
            } # zone not deployable
        }

        $FQDNobj = New-Object -TypeName PSCustomObject
        $FQDNobj | Add-Member -MemberType NoteProperty -Name name      -Value $FQDN
        $FQDNobj | Add-Member -MemberType NoteProperty -Name type      -Value FQDN
        $FQDNobj | Add-Member -MemberType NoteProperty -Name shortName -Value $notZone

        $hObj = $null
        if ($zObj) {
            if (!$Quiet) {
                Write-Verbose "Resolve-BlueCatFQDN: Selected Zone #$($zObj.id) as '$($zObj.name)'"
            }
            $Query = "getEntityByName?parentId=$($zObj.id)&type=HostRecord&name=$($FQDNobj.shortName)"
            $result = Invoke-BlueCatApi -Connection $BlueCatSession -Method Get -Request $Query
            if ($result.id) {
                $hObj = $result | Convert-BlueCatReply -BlueCatSession $BlueCatSession
                if (!$Quiet) {
                    Write-Verbose "Resolve-BlueCatFQDN: Selected Host #$($hObj.id) as '$($hObj.name)'"
                }
            } elseif (!$Quiet) {
                Write-Verbose "Resolve-BlueCatFQDN: No host record found in internal zone"
            }
        }

        $FQDNobj | Add-Member -MemberType NoteProperty -Name zone -Value $zObj
        $FQDNobj | Add-Member -MemberType NoteProperty -Name host -Value $hObj

        try {
            $xhObj = Get-BlueCatExternalHost -BlueCatSession $BlueCatSession -Name $FQDNobj.name 4>$null
            if (!$Quiet) {
                Write-Verbose "Resolve-BlueCatFQDN: Selected External Host #$($xhObj.id) as '$($xhObj.name)'"
            }
        } catch {
            $xhObj = $null
        }

        if ($hObj -and $xhObj) {
            if (!$Quiet) {
                Write-Warning "Resolve-BlueCatFQDN: Found internal and external host records for '$($FQDNobj.name)'"
            }
        }

        $FQDNobj | Add-Member -MemberType NoteProperty -Name external -Value $xhObj

        $Query = "getEntityByName?parentId=$($FQDNobj.zone.id)&type=AliasRecord&name=$($FQDNobj.shortName)"
        $result = Invoke-BlueCatApi -BlueCatSession $BlueCatSession -Method Get -Request $Query

        if ($result.id) {
            $AliasObj = $result | Convert-BlueCatReply -BlueCatSession $BlueCatSession
            Write-Verbose "Resolve-BlueCatFQDN: Selected Alias #$($AliasObj.id) as '$($AliasObj.name)' (points to $($AliasObj.property.linkedRecordName))"
            $FQDNobj | Add-Member -MemberType NoteProperty -Name alias -Value $AliasObj
        }

        $FQDNobj | Add-Member -MemberType NoteProperty -Name config -Value $View.config
        $FQDNobj | Add-Member -MemberType NoteProperty -Name view   -Value $View

        $FQDNobj
    }
}
