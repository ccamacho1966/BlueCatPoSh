function Resolve-BlueCatFQDN {
<#
.SYNOPSIS
    Searches the IPAM database for data related to the FQDN
.DESCRIPTION
    Resolve-BlueCatFQDN is a macro-function that searches the BlueCat database for a variety of information related to the supplied FQDN.

    This cmdlet will attempt to find the DNS zone that contains the supplied FQDN as well as Host records, External Host records, and CNAME/Alias records. It combines this data with related View and Configuration data before returning the macro-object to the caller. This permits the calling script to then test for the existance of member objects to determine if each type of record exists. The member object will be a complete object that can be directly referenced without additional API/function calls.

    Member objects include: zone, host, external, alias, view, config
.PARAMETER Name
    A string value representing the FQDN of the record to be searched for.
.PARAMETER ViewID
    An integer value representing the entity ID of the desired view.
.PARAMETER View
    A PSCustomObject representing the desired view.
.PARAMETER BlueCatSession
    A BlueCat object representing the session to be used for this object creation.
.EXAMPLE
    PS> $Results = Resolve-BlueCatFQDN -Name 'myhostname.example.com' -View 1818 -BlueCatSession $Session19

    PS> if ($Results.host) {
            Write-Output "Found a Host record (ID:$($Results.host.id)) for $($Results.name) in zone $($Results.zone.name) (ID:$($Results.zone.id))"
        }

    Searches the BlueCat database under view 1818 using BlueCat session $Session19 for 'myhostname.example.com'
    Stores the results of the cmdlet in the variable $Results
    Test members zone, host, external, and alias to see if matching records were found.
    Directly reference the member objects for further related data.
.INPUTS
    None.
.OUTPUTS
    PSCustomObject containing members:
     * [string] type = 'FQDN'
     * [string] name
     * [string] shortName
     * [PSCustomObject] zone
     * [PSCustomObject] host
     * [PSCustomObject] external
     * [PSCustomObject] alias
     * [PSCustomObject] view
     * [PSCustomObject] config
#>
    [CmdletBinding(DefaultParameterSetName='ViewID')]

    param(
        [parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [Alias('FQDN')]
        [string] $Name,

        [Parameter(ParameterSetName='ViewID')]
        [ValidateRange(1, [int]::MaxValue)]
        [int] $ViewID,

        [Parameter(ParameterSetName='ViewObj',Mandatory)]
        [ValidateNotNullOrEmpty()]
        [PSCustomObject] $View,

        [Parameter()]
        [Alias('Connection','Session')]
        [BlueCat] $BlueCatSession = $Script:BlueCatSession,

        [parameter(DontShow)]
        [switch] $Quiet
    )

    begin {
        Get-CallerPreference -Cmdlet $PSCmdlet -SessionState $ExecutionContext.SessionState
        if (-not $BlueCatSession) { throw 'No active BlueCatSession found' }
    }

    process {
        $thisFN = (Get-PSCallStack)[0].Command

        $FQDN = $Name | Test-ValidFQDN
        Write-Verbose "$($thisFN): Searching database for '$($FQDN)'"

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
            $ViewID = $BlueCatSession.View.id
            Write-Verbose "$($thisFN): Using default view $($BlueCatSession.View.name)"
        }

        if (-not $View) {
            $View = Get-BlueCatView -ID $ViewID -BlueCatSession $BlueCatSession
        }

        # Set the starting point for the zone/FQDN search to the View
        $zId = $ViewID

        $zPath = $FQDN.Split('\.')
        [array]::Reverse($zPath)

        $zDig = $true
        $result = $null
        $notZone = $null
        foreach ($bit in $zPath) {
            if ($zDig) {
                Write-Verbose "$($thisFN): Zone Trace is searching for component '$($bit)'..."
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
                        if (-not $zObj.property.deployable) {
                            Write-Verbose "$($thisFN): No deployable zone found for '$($bit).$($zObj.property.absoluteName)'"
                            $notZone = "$($bit).$($zObj.property.absoluteName)"
                            $zObj = $null
                        } # zone not deployable
                    } # $lastResult is $null
                } # $result.id is 0 - zone not found

                # update the parent to this new zone and continue processing
                $zId = $result.id
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
            if (-not $zObj.property.deployable) {
                $notZone = "$($bit).$($zObj.property.absoluteName)"
                $zObj = $null
            } # zone not deployable
        }

        $FQDNobj = New-Object -TypeName PSCustomObject
        $FQDNobj | Add-Member -MemberType NoteProperty -Name name      -Value $FQDN
        $FQDNobj | Add-Member -MemberType NoteProperty -Name type      -Value 'FQDN'
        $FQDNobj | Add-Member -MemberType NoteProperty -Name shortName -Value $notZone

        $hObj = $null
        if ($zObj) {
            Write-Verbose "$($thisFN): Selected Zone #$($zObj.id) as '$($zObj.name)'"
            $Query = "getEntityByName?parentId=$($zObj.id)&type=HostRecord&name=$($FQDNobj.shortName)"
            $result = Invoke-BlueCatApi -Connection $BlueCatSession -Method Get -Request $Query
            if ($result.id) {
                $hObj = $result | Convert-BlueCatReply -BlueCatSession $BlueCatSession
                Write-Verbose "$($thisFN): Selected Host #$($hObj.id) as '$($hObj.name)'"
            } else {
                Write-Verbose "$($thisFN): No host record found in internal zone"
            }
        }

        $FQDNobj | Add-Member -MemberType NoteProperty -Name zone -Value $zObj
        $FQDNobj | Add-Member -MemberType NoteProperty -Name host -Value $hObj

        # Search for an external host record matching the requested FQDN
        try {
            Write-Verbose "$($thisFN): Searching for External Host records..."
            $xhObj = Get-BlueCatExternalHost -BlueCatSession $BlueCatSession -Name $FQDNobj.name 4>$null
            if ($xhObj) {
                Write-Verbose "$($thisFN): Selected External Host #$($xhObj.id) as '$($xhObj.name)'"
            }
            $FQDNobj | Add-Member -MemberType NoteProperty -Name external -Value $xhObj
        } catch {
            $xhObj = $null
        }

        if ($hObj -and $xhObj) {
            Write-Warning "$($thisFN): Found internal and external host records for '$($FQDNobj.name)'"
        }

        # Search for a CNAME/Alias if there is a deployable zone
        if ($FQDNobj.zone.id) {
            Write-Verbose "$($thisFN): Searching for CNAME/Alias records..."
            $Query = "getEntityByName?parentId=$($FQDNobj.zone.id)&type=AliasRecord&name=$($FQDNobj.shortName)"
            $result = Invoke-BlueCatApi -BlueCatSession $BlueCatSession -Method Get -Request $Query

            if ($result.id) {
                Write-Verbose "$($thisFN): Resolving Alias #$($result.id)..."
                $AliasObj = $result | Convert-BlueCatReply -BlueCatSession $BlueCatSession
                Write-Verbose "$($thisFN): Selected Alias #$($AliasObj.id) as '$($AliasObj.name)' (points to $($AliasObj.property.linkedRecordName))"
                $FQDNobj | Add-Member -MemberType NoteProperty -Name alias -Value $AliasObj
            }
        }

        $FQDNobj | Add-Member -MemberType NoteProperty -Name config -Value $View.config
        $FQDNobj | Add-Member -MemberType NoteProperty -Name view   -Value $View

        $FQDNobj
    }
}
