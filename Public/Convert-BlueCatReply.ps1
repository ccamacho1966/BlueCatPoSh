function Convert-BlueCatReply {
    [cmdletbinding()]
    param(
        [Parameter()]
        [Alias('Connection','Session')]
        [BlueCat] $BlueCatSession = $Script:BlueCatSession,

        [Parameter(ValueFromPipeline,Mandatory)]
        [psobject] $RawObject,

        [Alias('Config')]
        [psobject] $Configuration,

        [psobject] $View
    )

    begin { Get-CallerPreference -Cmdlet $PSCmdlet -SessionState $ExecutionContext.SessionState }

    process {
        if ($Configuration) { $configObj = $Configuration}
        else { $configObj = ($BlueCatSession | Get-BlueCatConfig) }

        if ($View) { $viewObj = $View }
        else { $viewObj = ($BlueCatSession | Get-BlueCatView) }

        $newObj = New-Object -TypeName psobject
        if ($RawObject.type -eq 'Configuration') {
            $newObj | Add-Member -MemberType NoteProperty -Name 'id'   -Value $RawObject.id
            $newObj | Add-Member -MemberType NoteProperty -Name 'name' -Value $RawObject.name
            $newObj | Add-Member -MemberType NoteProperty -Name 'type' -Value $RawObject.type
        } elseif ($RawObject.type -eq 'View') {
            $newObj | Add-Member -MemberType NoteProperty -Name 'id' -Value $RawObject.id
            $newObj | Add-Member -MemberType NoteProperty -Name 'name' -Value $RawObject.name
            $newObj | Add-Member -MemberType NoteProperty -Name 'type' -Value $RawObject.type
            $configObj = Get-BlueCatParent -Connection $BlueCatSession -id $RawObject.id
            $newObj | Add-Member -MemberType NoteProperty -Name 'config' -Value $configObj
        } else {
            foreach ($bit in $RawObject.PsObject.Properties) {
                if ($bit.Name -eq 'properties') {
                    if ($null -eq $bit.Value) {
                        $newPropObj = $null
                    } else {
                        $newPropObj = Convert-BlueCatPropertyString -PropertyString $bit.Value
                        if ($newPropObj.addresses) {
                            $addrObj = ($newPropObj.addresses -split ',' | Where-Object -FilterScript { $_ })
                            $newPropObj | Add-Member -MemberType NoteProperty -Name 'address' -Value $addrObj
                        }
                    }
                    if ($RawObject.type -match '^IP4[BN].*') {
                        if ($newPropObj.CIDR) {
                            $specs = [PSCustomObject]@{'type'='CIDR'; 'spec'=$($newPropObj.CIDR)}
                        } else {
                            $specs = [PSCustomObject]@{'type'='Range'; 'spec'="$($newPropObj.start)-$($newPropObj.end)"}
                        }
                        $newPropObj | Add-Member -MemberType NoteProperty -Name ($RawObject.type.toLower()) -Value $specs
                    }
                    $newObj | Add-Member -MemberType NoteProperty -Name 'property' -Value $newPropObj
                }
                $newObj | Add-Member -MemberType NoteProperty -Name $bit.Name -Value $bit.Value
            }

            # Create a 'shortName' field and replace the default name field with the absolute name
            if (($newObj.type -eq 'Zone') -or ($newObj.type -match '.*Record$')) {
                $newObj | Add-Member -MemberType NoteProperty -Name 'shortName' -Value $newObj.name
                if ($newObj.property.absoluteName) { $newObj.name = $newObj.property.absoluteName }
            }

            Switch ($newObj.type) {
                {$_ -eq 'PublishedServerInterface'} {
                } # Do not include config or view references

                {($_ -eq 'Server') -or ($_ -match '^IP4[BNA].*')} {
                    $newObj | Add-Member -MemberType NoteProperty -Name config -Value $($configObj)
                } # Only include config reference

                default {
                    $newObj | Add-Member -MemberType NoteProperty -Name config -Value $($configObj)
                    $newObj | Add-Member -MemberType NoteProperty -Name view   -Value $($viewObj)
                } # By default include both a config and view reference
            } # conditionally add config and view references to objects
        }

        # Return the converted reply
        $newObj
    }
}