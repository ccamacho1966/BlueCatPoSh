<#
.SYNOPSIS
PowerShell module that implements access to the BlueCat API

.DESCRIPTION
BlueCat API class library and supporting functions.

Author: Christopher Camacho
#>

$Script:ModuleVersion = '3.0.0'

<#
[using module] doesn't consistently import classes or enumerations defined in
nested modules or in scripts that are dot-sourced into the root module. Define
classes and enumerations that you want to be available to users outside of the
module directly in the root module.
#>

class BlueCat {
    hidden static [int] $NextIndex = 1
    hidden [string] $idTag
    [string] $Server
    [psobject] $Property
    hidden [string] $Properties
    [string] $Username
    hidden [PSCredential] $Credential
    hidden [string] $Auth = ''
    [datetime] $SessionStart
    [datetime] $SessionRefresh
    [int] $SessionCount = 0
    [PSCustomObject] $View = $null
    [PSCustomObject] $Config = $null

    BlueCat([string]$Server, [pscredential]$Credential) {
        $this.Server     = $Server
        $this.Credential = $Credential
        $this.Username   = $Credential.UserName

        $this.Login()

        $this.Properties = Invoke-BlueCatApi -Method Get -Request 'getSystemInfo' -Connection $this
        $this.Property   = Convert-BlueCatPropertyString -PropertyString $this.Properties
        $this.idTag      = "$([BlueCat]::NextIndex)-$($this.Username)@$($this.Server)"
        [BlueCat]::NextIndex++
        [string[]] $propList = @('Server','Username','Config','View')
        [Management.Automation.PSMemberInfo[]]$visProp = [System.Management.Automation.PSPropertySet]::new('DefaultDisplayPropertySet',$propList)
        $this | Add-Member -MemberType MemberSet -Name PSStandardMembers -Value $visProp -PassThru
    } # BlueCat Class Constructor

    [void]Refresh() { $this.Login() }

    hidden [void]Login() {
        $uriPass = [uri]::EscapeDataString($this.Credential.GetNetworkCredential().Password)
        $Login="login?username=$($this.Credential.UserName)&password=$($uriPass)"
        try {
            $response = Invoke-BlueCatApi -Method Get -Request $Login -Connection $this
            $this.SessionRefresh = Get-Date
            if ($this.SessionCount -lt 1) {
                $this.SessionStart = $this.SessionRefresh
            }
            $this.Auth = "BAMAuthToken: $($response.Split(" ")[3])"
            $this.SessionCount++
        } catch {
            $this.Auth = ''
            $loginError = [Exception]::new($_)
            $loginErrorRecord = [System.Management.Automation.ErrorRecord]::new(
                $loginError,
                'LoginFailure',
                [System.Management.Automation.ErrorCategory]::AuthenticationError,
                $this
            )
            $PSCmdlet.ThrowTerminatingError($loginErrorRecord)
        }
    } # Private Method Login()
}

# Build lists of function and class definition files
$folderList = @('Private','Public')
foreach ($folder in $folderList) {
    $fileList = @( Get-ChildItem -Path "$($PSScriptRoot)\$($folder)\*.ps1" -Recurse -ErrorAction SilentlyContinue )
    foreach ($import in $fileList) {
        try {
            . $import.FullName
            Write-Verbose "Imported $($folder) file $($import.FullName)"
            if ($folder -eq 'Public') {
                Export-ModuleMember -Function $import.BaseName
                Write-Verbose "Exported public function $($import.BaseName)"
            }
        } catch {
            Write-Error -Message "Failed to import $($folder) file $($import.BaseName): $_"
        }
    }
}

New-Alias -Name Add-BlueCatCNAME -Value Add-BlueCatAlias
New-Alias -Name Get-BlueCatCNAME -Value Get-BlueCatAlias
New-Alias -Name Set-BlueCatDefaultConnection -Value Set-BlueCatConnection
Export-ModuleMember -Alias '*'

# Force TLS 1.2
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

# Private module list of all active BlueCat sessions
[BlueCat[]]$Script:BlueCatAllSessions = @()

# The default BlueCat session in use
[BlueCat]$Script:BlueCatSession = $null
Export-ModuleMember -Variable BlueCatSession

# Read in or create an initial config file and variable

