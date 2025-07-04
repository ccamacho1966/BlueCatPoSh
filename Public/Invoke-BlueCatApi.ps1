function Invoke-BlueCatApi {
    [cmdletbinding()]
    param(
        [Parameter()]
        [Alias('Connection','Session')]
        [BlueCat] $BlueCatSession = $Script:BlueCatSession,

        [ValidateSet('Get','Post','Put')]
        [string] $Method = 'Get',

        [Parameter(Mandatory, ValueFromPipeline)]
        [string] $Request,

        [string] $Body
    )

    begin { Get-CallerPreference -Cmdlet $PSCmdlet -SessionState $ExecutionContext.SessionState } 

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
