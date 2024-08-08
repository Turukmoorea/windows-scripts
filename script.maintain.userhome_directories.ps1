# This script performs operations on directories. 
# It takes two parameters: a parent path and a boolean flag for prompting the user.

param (
    [string]$parentPath,  # The parent directory path to operate on.
    [bool]$prompt = $true  # A flag to determine whether to prompt the user for confirmation.
)

# Function to resolve and validate the parent path.
function Resolve-ParentPath {
    param ([string]$parentPath)
    
    # If the parent path is null or empty, use the current directory.
    if ($null -eq $parentPath -or $parentPath.Trim() -eq "") {
        $parentPath = Get-Location
    }
    
    # Check if the path is absolute. If not, resolve it to an absolute path.
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
    return $parentPath  # Return the resolved parent path.
}

# Function to get the names of child directories within the parent path.
function Get-ChildDirectories {
    param ([string]$parentPath)
    return Get-ChildItem -Path $parentPath -Directory | Select-Object -ExpandProperty Name
}

# Function to validate the existence of child directories.
function Validate-Directories {
    param (
        [string]$parentPath,
        [string[]]$childDirectories
    )
    
    # Arrays to hold valid and invalid directories.
    $selectedDirectories = @()
    $invalidDirectories = @()
    
    # Check each child directory to see if it exists.
    foreach ($childDirectory in $childDirectories) {
        $fullPath = Join-Path -Path $parentPath -ChildPath $childDirectory
        if (Test-Path -Path $fullPath) {
            $selectedDirectories += $childDirectory
        } else {
            $invalidDirectories += $childDirectory
        }
    }
    
    # Return a custom object containing both valid and invalid directories.
    return [PSCustomObject]@{
        Selected = $selectedDirectories
        Invalid = $invalidDirectories
    }
}

# Function to output the list of directories.
function Output-Directories {
    param (
        [string[]]$directories,  # List of directories to output.
        [string]$message  # Message to display with the directories.
    )
    
    # If there are directories to output, display them.
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

# Function to prompt the user for directory deletion.
function Prompt-For-Deletion {
    param (
        [string]$parentPath,  # The parent path containing the directories.
        [string[]]$selectedDirectories  # List of directories to consider for deletion.
    )
    
    # Ask the user if they want to delete all selected directories.
    $deleteAll = Read-Host "Do you want to delete all selected directories? (yes/no)"
    if ($deleteAll -eq "yes") {
        # If yes, delete each directory.
        $selectedDirectories | ForEach-Object {
            Remove-Item -Path (Join-Path -Path $parentPath -ChildPath $_) -Recurse -Force
            Write-Output "Deleted directory: $_"
        }
    } else {
        # Otherwise, prompt for specific directories to delete.
        $selectedToDelete = Read-Host "Enter the indices of directories to delete, separated by commas (e.g., 0,1)"
        $indices = $selectedToDelete -split "," | ForEach-Object { [int]$_.Trim() }
        
        # Delete the specified directories by index.
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

# Main script execution starts here.

# Resolve the parent path to an absolute path.
$parentPath = Resolve-ParentPath -parentPath $parentPath

# Get the list of child directories within the parent path.
$childDirectories = Get-ChildDirectories -parentPath $parentPath

# Validate the directories and separate valid from invalid ones.
$validationResult = Validate-Directories -parentPath $parentPath -childDirectories $childDirectories

# Output the list of valid directories.
Output-Directories -directories $validationResult.Selected -message "selected directories in ${parentPath}:"

# Prompt the user for deletion if the prompt flag is set.
#if ($prompt) {
#    Prompt-For-Deletion -parentPath $parentPath -selectedDirectories $validationResult.Selected
#}
