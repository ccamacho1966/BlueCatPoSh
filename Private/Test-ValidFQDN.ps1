function Test-ValidFQDN
{
    [CmdletBinding()]

    Param(
        [Parameter(Mandatory,Position=0,ValueFromPipeline)]
        [ValidateNotNullOrEmpty()]
        [Alias('Name')]
        [string] $FQDN
    )

    begin { Get-CallerPreference -Cmdlet $PSCmdlet -SessionState $ExecutionContext.SessionState } 

    process {
        $CleanedName = ($FQDN.Trim()).TrimEnd('\.')

        if (-not $CleanedName.Contains('.')) {
            throw "Invalid FQDN: $($CleanedName)"
        }

        $CleanedName
    }
}
