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

        $Zone = Resolve-BlueCatZone -Name $FQDN -View $View -BlueCatSession $BlueCatSession

        if ($FQDN -eq $Zone.name) {
            $ShortName = ''
        } else {
            $ShortName = $FQDN -replace "\.$($Zone.name)$", ''
        }

        $FQDNobj = New-Object -TypeName PSCustomObject
        $FQDNobj | Add-Member -MemberType NoteProperty -Name name      -Value $FQDN
        $FQDNobj | Add-Member -MemberType NoteProperty -Name type      -Value 'FQDN'
        $FQDNobj | Add-Member -MemberType NoteProperty -Name shortName -Value $ShortName

        if ($Zone) {
            $FQDNobj | Add-Member -MemberType NoteProperty -Name zone -Value $Zone
            $Query = "getEntityByName?parentId=$($Zone.id)&type=HostRecord&name=$($FQDNobj.shortName)"
            $BlueCatReply = Invoke-BlueCatApi -Method Get -Request $Query -Connection $BlueCatSession
            if ($BlueCatReply.id) {
                $HostObj = $BlueCatReply | Convert-BlueCatReply -BlueCatSession $BlueCatSession
                Write-Verbose "$($thisFN): Selected Host #$($HostObj.id) as '$($HostObj.name)'"
                $FQDNobj | Add-Member -MemberType NoteProperty -Name host -Value $HostObj
            } else {
                Write-Verbose "$($thisFN): No host record found in internal zone"
            }
        }

        # Search for an external host record matching the requested FQDN
        try {
            Write-Verbose "$($thisFN): Searching for External Host records..."
            $ExternalHost = Get-BlueCatExternalHost -Name $FQDNobj.name -View $View -BlueCatSession $BlueCatSession
            if ($ExternalHost) {
                Write-Verbose "$($thisFN): Selected External Host #$($ExternalHost.id) as '$($ExternalHost.name)'"
                $FQDNobj | Add-Member -MemberType NoteProperty -Name external -Value $ExternalHost
            }
        } catch {
            # Continue processing
        }

        if ($HostObj -and $ExternalHost) {
            Write-Warning "$($thisFN): Found internal and external host records for '$($FQDNobj.name)'"
        }

        # Search for a CNAME/Alias if there is a deployable zone
        if ($Zone) {
            Write-Verbose "$($thisFN): Searching for CNAME/Alias records..."
            $Query = "getEntityByName?parentId=$($Zone.id)&type=AliasRecord&name=$($ShortName)"
            $BlueCatReply = Invoke-BlueCatApi -Method Get -Request $Query -BlueCatSession $BlueCatSession

            if ($BlueCatReply.id) {
                $AliasObj = $BlueCatReply | Convert-BlueCatReply -BlueCatSession $BlueCatSession
                Write-Verbose "$($thisFN): Selected Alias #$($AliasObj.id) as '$($AliasObj.name)' (points to $($AliasObj.property.linkedRecordName))"
                $FQDNobj | Add-Member -MemberType NoteProperty -Name alias -Value $AliasObj
            }
        }

        $FQDNobj | Add-Member -MemberType NoteProperty -Name config -Value $View.config
        $FQDNobj | Add-Member -MemberType NoteProperty -Name view   -Value $View

        $FQDNobj
    }
}
