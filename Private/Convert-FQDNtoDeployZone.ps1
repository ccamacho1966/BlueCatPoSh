function Convert-FQDNtoDeployZone {
    [cmdletbinding(DefaultParameterSetName='byID')]
    param(
        [Parameter(Mandatory)]
        [string] $FQDN,

        [Parameter(ParameterSetName='byObj',Mandatory)]
        [ValidateNotNullOrEmpty()]
        [PsCustomObject] $View,

        [Parameter(ParameterSetName='byID')]
        [Alias('ID')]
        [int] $ViewID,

        [Parameter(DontShow)]
        [switch] $Quiet,

        [Parameter()]
        [Alias('Connection','Session')]
        [BlueCat] $BlueCatSession = $Script:defaultBlueCat
    )

    begin { Get-CallerPreference -Cmdlet $PSCmdlet -SessionState $ExecutionContext.SessionState } 

    process {
        if ($View.id) {
            # View object passed to function, select the ID
            $ViewID = $View.id
        }

        if (-not $ViewID) {
            # If no View ID has been set by this point, try to use the default
            $BlueCatSession | Confirm-Settings -View
            $ViewID = $BlueCatSession.idView
        }

        $zPath = $FQDN.TrimEnd('\.').Split('\.')
        [array]::Reverse($zPath)

        $zDig = $true
        $result = $null
        $notZone = $null

        # Set the starting point for the zone/FQDN search to the View
        $zId = $ViewID

        foreach ($bit in $zPath) {
            if ($zDig) {
                # save the result in case this is the last bit of the zone path
                $lastResult = $result
                $Query = "getEntityByName?parentId=$($zId)&type=Zone&name=$($bit)"
                $result = Invoke-BlueCatApi -BlueCatSession $BlueCatSession -Method Get -Request $Query
                # $result.id is 0 if this bit isn't part of a valid zone path
                # stop digging for zones and assume the rest of the path is host
                if ($result.id -eq 0) {
                    $zDig = $false
                    # load the value of bit into the first section of 'notZone' ...aka hostname
                    $notZone = $bit
                    # lastResult would only be null if we never found any zone path!
                    if ($null -eq $lastResult) {
                        $zObj = $null
                    } else {
                        $zObj = $lastResult | Convert-BlueCatReply -BlueCatSession $BlueCatSession
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
        if ($lastResult -and !$notZone) {
            $zObj = $result | Convert-BlueCatReply -BlueCatSession $BlueCatSession
            # set notZone to a blank string and retrieve the zone info!
            $notZone = ''
            if ($zObj.property.deployable -eq 'false') {
                $notZone = "$($bit).$($zObj.property.absoluteName)"
                $zObj = $null
            } # zone not deployable
        }

        # Retrieve the view object
        $View = Get-BlueCatView -ViewID $ViewID -BlueCatSession $BlueCatSession

        $ZIobj = New-Object -TypeName psobject
        $ZIobj | Add-Member -MemberType NoteProperty -Name name      -Value ($FQDN.TrimEnd('\.'))
        $ZIobj | Add-Member -MemberType NoteProperty -Name type      -Value 'ZoneInfo'
        $ZIobj | Add-Member -MemberType NoteProperty -Name zone      -Value $zObj
        $ZIobj | Add-Member -MemberType NoteProperty -Name config    -Value $View.config
        $ZIobj | Add-Member -MemberType NoteProperty -Name view      -Value $View
        $ZIobj | Add-Member -MemberType NoteProperty -Name shortName -Value $notZone

        $ZIobj
    }
} # Private Function Convert-FQDNtoDeployZone
