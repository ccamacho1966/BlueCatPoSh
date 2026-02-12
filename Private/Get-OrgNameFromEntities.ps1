function Get-OrgNameFromEntities {
    param(
        [Parameter(Mandatory,ValueFromPipeline)]
        [ValidateNotNullOrEmpty()]
        [Object[]] $Entities
    )

    $thisFN = (Get-PSCallStack)[0].Command

    if (-not $Entities.Count) {
        throw "$($thisFN): Invalid Entities Array"
    }

    # Filter out anything other than 'registrant' class entities
    $Registrants = [Object[]]($Entities | Where-Object -Property roles -Contains 'registrant')
    if (-not $Registrants.Count) {
        Write-Warning "$($thisFN): No registrant data found"
        return
    }

    # This entry indicates an organization entity, rather than an individual
    $OrgEntry = @( 'kind','','text','org' )

    foreach ($Entry in $Registrants) {
        # Check each entry to see if its the organization entry
        foreach ($vCard in $Entry.vcardArray[1]) {
            # If it matches the $OrgEntry reference object we have found the owning organization
            if (-not (Compare-Object -ReferenceObject $OrgEntry -DifferenceObject $vCard)) {
                # Extract the 'fn' (Full Name) field to get the owning organization's name
                $OrgName = (($Entry.vcardArray[1] | Where-Object -FilterScript { $_[0] -eq 'fn' })[3])
                # Immediately exit and return the owning organization's name
                return $OrgName
            }
        }
    }

    Write-Warning "$($thisFN): No owning organization record found"
}
