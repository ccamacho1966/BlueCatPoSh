function Invoke-BlueCatApi {
<#
.SYNOPSIS
    Directly invoke the BlueCat v1 REST API
.DESCRIPTION
    Invoke-BlueCatApi is an underlying function that directly invokes the v1 REST API of the BlueCat IPAM appliance.

    This cmdlet takes the 'Request' parameter and applies it to the path "https://$SERVER/Services/REST/v1/" and can accept Get, Post, and Put calls currently.
.PARAMETER Method
    A string value representing REST method, currently 'Get', 'Post', 'Put', or 'Delete'.
.PARAMETER Request
    A string value representing the API call attached to the v1 REST API.
.PARAMETER Body
    A string value representing the literal body of a Put or Post request.
.PARAMETER BlueCatSession
    A BlueCat object representing the session to be used for this object creation.
.EXAMPLE
    PS> $Results = Invoke-BlueCatApi -Method Get -Request 'getSystemInfo'

    Invokes the v1 REST API endpoint 'getSystemInfo' and stores the reply in the $Results variable.
    BlueCatSession will default to the current default session.
.INPUTS
    None.
.OUTPUTS
    Varies depending on the reply from the API.
    If the API returns an integer, the output is an Int64.
    If the API returns a string, the output is a String.
    If the API returns JSON data, the output is a PSObject.
#>
    [CmdletBinding()]

    param(
        [ValidateSet('Get','Post','Put','Delete')]
        [string] $Method = 'Get',

        [Parameter(Mandatory, ValueFromPipeline)]
        [ValidateNotNullOrEmpty()]
        [string] $Request,

        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [string] $Body,

        [Parameter()]
        [Alias('Connection','Session')]
        [BlueCat] $BlueCatSession = $Script:BlueCatSession
    )

    begin {
        Get-CallerPreference -Cmdlet $PSCmdlet -SessionState $ExecutionContext.SessionState
        if (-not $BlueCatSession) { throw 'No active BlueCatSession found' }
    }

    process {
        $RestCall = @{
            Uri = "https://$($BlueCatSession.Server)/Services/REST/v1/$($Request)"
            Method = $Method
            ContentType = 'application/json'
            ErrorAction = 'Stop'
        }

        $verboseOutput = "Invoke-BlueCatApi: $($RestCall.Method.toUpper()) $($BlueCatSession.Server)/"
        if ($Request -match '^login?.*') {
            $verboseOutput += "login?username=$($BlueCatSession.UserName)&password=********"
        } else {
            $verboseOutput += "$($Request)"
            $RestCall.Add( 'Headers', @{'Authorization'=$BlueCatSession.Auth} )
        }

        if ($Body) {
            $RestCall.Add('Body', $Body)
            $verboseOutput += " with $($Body.Length)-byte payload"
        }

        Write-Verbose $verboseOutput
        try {
            Invoke-RestMethod @RestCall 4>$null
        } catch {
            if ('401' -eq ($_.Exception.Response.StatusCode.value__)) {
                Write-Verbose "Invoke-BlueCatApi: API token expired... Refresh/Retry!"
                $BlueCatSession.Refresh()
                $RestCall.Remove('Headers')
                $RestCall.Add('Headers',@{'Authorization'=$BlueCatSession.Auth})
                Invoke-RestMethod @RestCall 4>$null
            } else {
                throw "$($_.Exception.Response.StatusCode.value__): $($_.Exception.Response.StatusDescription)"
            }
        }
    }
}
