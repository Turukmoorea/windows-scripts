param (
    # Defines the parent directory path as an input parameter
    [string]$parentPath,

    # Defines an array of subdirectory names as input parameters
    #[string[]]$childDirectories,

    [bool]$prompt = $true
)

# Check if the parentPath argument is given. If not, use the current path.
if ($null -eq $parentPath -or $parentPath.Trim() -eq "") {
    # Set parentPath to the current directory
    $parentPath = Get-Location
}

# Output the input parameters for debugging
# Write-Output "parentPath: $parentPath"
# Write-Output "prompt: $prompt"

# Convert relative path to absolute path
if (-not [System.IO.Path]::IsPathRooted($parentPath)) {
    try {
        # Attempt to resolve the absolute path for parentPath
        $resolvedPath = Resolve-Path -Path $parentPath -ErrorAction Stop
        if ($null -ne $resolvedPath) {
            # Set parentPath to the resolved absolute path
            $parentPath = $resolvedPath.ProviderPath
        }
    } catch {
        # Output an error message if the path does not exist
        Write-Output "Error: Path does not exist."
        exit
    }
}

# Get all child directories if none are specified
#if ($null -eq $childDirectories -or $childDirectories.Count -eq 0) {
    # List all subdirectories in the parentPath and extract their names
    $childDirectories = Get-ChildItem -Path $parentPath -Directory | Select-Object -ExpandProperty Name
#}

# Initialize arrays to store the processed and invalid directories
$selectedDirectories = @()
$invalidDirectories = @()

# Iterate over each subdirectory in the childDirectories array
foreach ($childDirectory in $childDirectories) {
    # Create the full path for the current subdirectory
    $fullPath = Join-Path -Path $parentPath -ChildPath $childDirectory
    
    # Check if the directory is a valid path
    if (Test-Path -Path $fullPath) {
        # Add the name of the current subdirectory to the processed directories array
        $selectedDirectories += $childDirectory
        # Write-Output "Valid path: $fullPath"
    } else {
        # Add the name of the current subdirectory to the invalid directories array
        $invalidDirectories += $childDirectory
        # Write-Output "Invalid path: $fullPath"
    }
}

# Output the selected directories
if ($selectedDirectories.Count -gt 0) {
    if ($selectedDirectories.Count -eq 1) {
        Write-Output "$($selectedDirectories.Count) selected directory in ${parentPath}:"
    } else {Write-Output "$($selectedDirectories.Count) selected directories in ${parentPath}:"}

    $i = 0
    $selectedDirectories | ForEach-Object {
        Write-Output "   $i. $_"
        $i++
    }
} else {
    Write-Output "No valid directories to select."
    exit
}

# Placeholder
Write-Output ""

# Output the invalid directories
# if ($invalidDirectories.Count -gt 0) {
#    Write-Output ""
#    Write-Output "Invalid directories in ${parentPath}:"
#    $invalidDirectories | ForEach-Object {
#        Write-Output "->  $_"
#    }
#}

# Prompt user for deletion if prompt is true
if ($prompt -eq $true) {
    $deleteAll = Read-Host "Do you want to delete all selected directories? (yes/no)"
    if ($deleteAll -eq "yes") {
        # Delete all selected directories
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
