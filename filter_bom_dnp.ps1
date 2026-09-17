param(
    [Parameter(Mandatory = $true)]
    [string]$BomPath,

    [Parameter(Mandatory = $true)]
    [string]$PlacementPath,

    [Parameter(Mandatory = $true)]
    [string]$OutputPath
)

# The placement export is produced with --exclude-dnp, so its Designator
# column is the authoritative set of components that should be placed.
$placedReferences = @{}
Import-Csv -LiteralPath $PlacementPath | ForEach-Object {
    $reference = ([string]$_.Designator).Trim()
    if ($reference) {
        $placedReferences[$reference] = $true
    }
}

$filtered = Import-Csv -LiteralPath $BomPath | Where-Object {
    $references = ([string]$_.Designator) -split '\s+'
    @($references | Where-Object { $placedReferences.ContainsKey($_.Trim()) }).Count -gt 0
}

$filtered | Export-Csv -LiteralPath $OutputPath -NoTypeInformation -Encoding UTF8
