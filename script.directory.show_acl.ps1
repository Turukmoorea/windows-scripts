param (
    [string]$parentPath
)

# Check if argument parentPath is given.
if ($null -eq $parentPath -or $parentPath.Trim() -eq "") {
    $parentPath = Get-Location
}

# Convert relative path to absolute path
if (-not [System.IO.Path]::IsPathRooted($parentPath)) {
    try {
        $resolvedPath = Resolve-Path -Path $parentPath -ErrorAction Stop
        if ($null -ne $resolvedPath) {
            $parentPath = $resolvedPath.ProviderPath
        }
    } catch {
        Write-Output "Error: Path does not exist."
        exit
    }
}