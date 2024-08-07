param (
    [string]$parentPath,
    [bool]$prompt = $true
)

function Resolve-ParentPath {
    param ([string]$parentPath)
    if ($null -eq $parentPath -or $parentPath.Trim() -eq "") {
        $parentPath = Get-Location
    }
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
    return $parentPath
}

function Get-ChildDirectories {
    param ([string]$parentPath)
    return Get-ChildItem -Path $parentPath -Directory | Select-Object -ExpandProperty Name
}

function Validate-Directories {
    param (
        [string]$parentPath,
        [string[]]$childDirectories
    )
    $selectedDirectories = @()
    $invalidDirectories = @()
    foreach ($childDirectory in $childDirectories) {
        $fullPath = Join-Path -Path $parentPath -ChildPath $childDirectory
        if (Test-Path -Path $fullPath) {
            $selectedDirectories += $childDirectory
        } else {
            $invalidDirectories += $childDirectory
        }
    }
    return [PSCustomObject]@{
        Selected = $selectedDirectories
        Invalid = $invalidDirectories
    }
}

function Output-Directories {
    param (
        [string[]]$directories,
        [string]$message
    )
    if ($directories.Count -gt 0) {
        Write-Output "$($directories.Count) $message"
        $i = 0
        $directories | ForEach-Object {
            Write-Output "   $i. $_"
            $i++
        }
    } else {
        Write-Output "No valid directories to select."
        exit
    }
}

function Prompt-For-Deletion {
    param (
        [string]$parentPath,
        [string[]]$selectedDirectories
    )
    $deleteAll = Read-Host "Do you want to delete all selected directories? (yes/no)"
    if ($deleteAll -eq "yes") {
        $selectedDirectories | ForEach-Object {
            Remove-Item -Path (Join-Path -Path $parentPath -ChildPath $_) -Recurse -Force
            Write-Output "Deleted directory: $_"
        }
    } else {
        $selectedToDelete = Read-Host "Enter the indices of directories to delete, separated by commas (e.g., 0,1)"
        $indices = $selectedToDelete -split "," | ForEach-Object { [int]$_.Trim() }
        foreach ($index in $indices) {
            if ($index -ge 0 -and $index -lt $selectedDirectories.Count) {
                $dirToDelete = $selectedDirectories[$index]
                Remove-Item -Path (Join-Path -Path $parentPath -ChildPath $dirToDelete) -Recurse -Force
                Write-Output "Deleted directory: $dirToDelete"
            } else {
                Write-Output "Invalid index: $index"
            }
        }
    }
}

# Hauptskript
$parentPath = Resolve-ParentPath -parentPath $parentPath
$childDirectories = Get-ChildDirectories -parentPath $parentPath
$validationResult = Validate-Directories -parentPath $parentPath -childDirectories $childDirectories

Output-Directories -directories $validationResult.Selected -message "selected directories in ${parentPath}:"

if ($prompt) {
    Prompt-For-Deletion -parentPath $parentPath -selectedDirectories $validationResult.Selected
}
