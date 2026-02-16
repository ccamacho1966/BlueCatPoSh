function Remove-BlueCatSOA {
        [CmdletBinding(DefaultParameterSetName='byID')]

    param(
        [Parameter(ParameterSetName='byID',Mandatory)]
        [ValidateRange(1, [int]::MaxValue)]
        [Alias('EntityID','SOAID','ZoneID')]
        [int] $ID,

        [Parameter(ParameterSetName='byObj',Mandatory,ValueFromPipeline)]
        [ValidateNotNullOrEmpty()]
        [Alias('Entity','SOA','Zone')]
        [PSCustomObject] $Object,

        [Parameter(ParameterSetName='byNameViewID',Mandatory)]
        [Parameter(ParameterSetName='byNameViewObj',Mandatory)]
        [ValidateNotNullOrEmpty()]
        [Alias('ZoneName')]
        [string] $Name,

        [Parameter(ParameterSetName='byNameViewID')]
        [ValidateRange(1, [int]::MaxValue)]
        [int] $ViewID,

        [Parameter(ParameterSetName='byNameViewObj',Mandatory)]
        [ValidateNotNullOrEmpty()]
        [PSCustomObject] $View,

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

        if ($ID) {
            # Convert the Entity ID into an Entity Object to use the object logic
            $Object = Get-BlueCatEntityById -ID $ID -BlueCatSession $BlueCatSession
        }

        if ($Name) {
            # Translate zone name into a zone object
            $SoaLookup = @{
                Name               = $Name
                BlueCatSession     = $BlueCatSession
            }
            if ($View) {
                $SoaLookup.View   = $View
            }
            if ($ViewID) {
                $SoaLookup.ViewID = $ViewID
            }
            $Object = Get-BlueCatSOA @SoaLookup
        }

        if (-not $Object) {
            if ($ID) {
                $FailureMessage = "$($thisFN): Failed to convert Entity ID #$($ID) to SOA Record"
            } else {
                $FailureMessage = "$($thisFN): Failed to convert Name '$($Name)' in View '$($View.name)' to SOA Record"
            }
            Write-Verbose $FailureMessage
            throw $FailureMessage
        }

        if (-not $Object.ID) {
            $FailureMessage = "$($thisFN): Invalid SOA Object"
            Write-Verbose $FailureMessage
            throw $FailureMessage
        }

        if ($Object.type -ne 'StartOfAuthority') {
            $FailureMessage = "$($thisFN): Not SOA Record - $($Object.Name) is type '$($Object.type)'"
            Write-Verbose $FailureMessage
            throw $FailureMessage
        }

        $DeleteSOA = @{
            ID             = $Object.ID
            BlueCatSession = $BlueCatSession
        }

        Write-Verbose "$($thisFN): Deleting SOA record for '$($Object.Name)' (ID:$($Object.ID))"
        Remove-BlueCatEntityById @DeleteSOA
    }
}
