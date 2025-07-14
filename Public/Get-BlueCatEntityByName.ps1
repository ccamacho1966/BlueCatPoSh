function Get-BlueCatEntityByName {
    [CmdletBinding()]

    param(
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [Alias('EntityName')]
        [string] $Name,

        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string] $EntityType,

        [Parameter()]
        [ValidateRange(1, [int]::MaxValue)]
        [int] $ParentID,

        [Parameter()]
        [Alias('Connection','Session')]
        [BlueCat] $BlueCatSession = $Script:BlueCatSession
    )

    begin { Get-CallerPreference -Cmdlet $PSCmdlet -SessionState $ExecutionContext.SessionState }

    process {
        $thisFN = (Get-PSCallStack)[0].Command

        $verboseOutput = "$($thisFN): Name='$($Name)', EntityType='$($EntityType)'"
        if ($ParentID) { $verboseOutput += ", ParentID='$($ParentID)'" }
        Write-Verbose $verboseOutput

        if ($EntityType -eq 'Configuration') {
            if ($ParentID) {
                Write-Warning "Ignoring ParentID for EntityType=Configuration lookup..."
            }
            $ParentID=0
        } elseif (-not $ParentID) {
            $BlueCatSession | Confirm-Settings -Config
            $ParentID = $BlueCatSession.idConfig
        }

        $Query = "getEntityByName?parentId=$($ParentID)&name=$($Name)&type=$($EntityType)"
        $result = Invoke-BlueCatApi -Method Get -Request $Query -BlueCatSession $BlueCatSession
        if (-not $result.id) {
            throw "$($EntityType) $($Name) not found: $($result)"
        }
        Write-Verbose "$($thisFN): Selected $($result.type) #$($result.id) as $($result.name)"

        $result | Convert-BlueCatReply -BlueCatSession $BlueCatSession
    }
}
