param (
    [string]$parentPath,  # The parent directory path to operate on.
    [bool]$prompt = $true,  # A flag indicating whether to prompt the user for confirmation.
    [string]$emptyDirectories = "delete"  # A string parameter to specify how to handle empty directories.
)

# Function to resolve and validate the provided path.
function Resolve-AbsolutePath {
    param ([string]$inputPath)  # The input path to resolve.
    
    # If the input path is null or empty, use the current directory.
    if ($null -eq $inputPath -or $inputPath.Trim() -eq "") {
        $inputPath = Get-Location
    }
    
    # Check if the path is absolute. If not, resolve it to an absolute path.
    if (-not [System.IO.Path]::IsPathRooted($inputPath)) {
        try {
            $resolvedPath = Resolve-Path -Path $inputPath -ErrorAction Stop
            if ($null -ne $resolvedPath) {
                $inputPath = $resolvedPath.ProviderPath
            }
        } catch {
            Write-Output "Error: Path does not exist."
            exit
        }
    }
    return $inputPath  # Return the resolved input path.
}

# Function to get the names of subdirectories within the specified base path.
function Get-SubDirectories {
    param ([string]$basePath)  # The base directory path.
    return Get-ChildItem -Path $basePath -Directory | Select-Object -ExpandProperty FullName
}

# Function to validate the existence of the subdirectories.
function PreValidate-Paths {
    param (
        [string]$basePath,  # The base directory path.
        [string[]]$subPaths  # The subdirectory paths to validate.
    )
    
    # Arrays to hold valid and invalid paths.
    $validPaths = @()
    $invalidPaths = @()
    
    # Check each subdirectory path to see if it exists.
    foreach ($subPath in $subPaths) {
        $fullPath = Join-Path -Path $basePath -ChildPath $subPath
        if (Test-Path -Path $fullPath) {
            $validPaths += $subPath
        } else {
            $invalidPaths += $subPath
        }
    }
    
    # Return a custom object containing both valid and invalid paths.
    return [PSCustomObject]@{
        Valid = $validPaths
        Invalid = $invalidPaths
    }
}

# Function to validate empty directories or directories without AD-user
function Validate-Paths {
    param (
        [string[]]$subDirectoryPaths  # Array of subdirectory paths to validate.
    )
    
    $results = @()

    foreach ($path in $subDirectoryPaths) {
        # Check if the directory is empty by looking for any files or subdirectories
        $items = Get-ChildItem -Path $path -Force -ErrorAction SilentlyContinue
        $isEmpty = if ($items.Count -eq 0) {$true} else {$false}

        # Retrieve the directory's permissions
        $acl = Get-Acl -Path $path
        $aclEntries = $acl.Access | ForEach-Object {
            "$($_.IdentityReference)"
        }
        $aclString = $aclEntries -join ", "
            
        # Add results
        $results += [PSCustomObject]@{
            Path = $path
            Empty = $isEmpty
            ACL = $aclString
        }
    }
    
    return $results
}

# Function to display the list of paths with a message.
function Display-Paths {
    param (
        [PSCustomObject[]]$paths,  # List of paths with ACL or empty directory to display.
        [string]$parentPath 
    )

    # If there are paths to display, list them with their indices.
    if ($paths.Count -gt 0) {
        Write-Output "$($paths.Count) directories found:"
        $i = 0
        $paths | ForEach-Object {
            if ($null -ne $_.Path -and $_.Path -ne "") {
                $lastFolderName = Split-Path -Leaf $_.Path
                $emptyFolder = if ($_.Empty -eq $true) {"empty"} else {"content"} 
                Write-Output "   $i. $lastFolderName - $emptyFolder - ACL: $($_.ACL)"
            } else {
                Write-Output "   $i. Invalid path found"
            }
            $i++
        }
    } else {
        Write-Output "No valid paths to select."
        return
    }
}

# Function to prompt the user for path deletion.
function Confirm-Deletion {
    param (
        [string]$basePath,  # The base directory path containing the paths to delete.
        [PSCustomObject[]]$pathsToDelete  # List of paths to consider for deletion.
    )
    
    # Display the list of paths to delete
    $i = 0
    $pathsToDelete | ForEach-Object {
        Write-Output "$i. $($_.Path)"
        $i++
    }

    # Ask the user if they want to delete all selected paths.
    $deleteAll = Read-Host "Do you want to delete all selected paths? (yes/no)"
    if ($deleteAll -eq "yes") {
        # If yes, delete each path.
        $pathsToDelete | ForEach-Object {
            Remove-Item -Path $_.Path -Recurse -Force
            Write-Output "Deleted path: $($_.Path)"
        }
    } else {
        # Otherwise, prompt for specific paths to delete.
        $selectedToDelete = Read-Host "Enter the indices of paths to delete, separated by commas (e.g., 0,1)"
        $indices = $selectedToDelete -split "," | ForEach-Object { [int]$_.Trim() }
        
        # Delete the specified paths by index.
        foreach ($index in $indices) {
            if ($index -ge 0 -and $index -lt $pathsToDelete.Count) {
                $pathToDelete = $pathsToDelete[$index].Path
                Remove-Item -Path $pathToDelete -Recurse -Force
                Write-Output "Deleted path: $pathToDelete"
            } else {
                Write-Output "Invalid index: $index"
            }
        }
    }
}

# Main script execution starts here.

# Resolve the parent path to an absolute path.
$parentPath = Resolve-AbsolutePath -inputPath $parentPath

# Get the list of subdirectories within the parent path.
$childDirectories = Get-SubDirectories -basePath $parentPath

# Validate the subdirectories and separate valid from invalid ones.
$preValidationResult = PreValidate-Paths -basePath $parentPath -subPaths $childDirectories

# Get the list of valid subdirectory paths for further validation.
$validSubDirectoryPaths = $preValidationResult.Valid | ForEach-Object {
    Join-Path -Path $parentPath -ChildPath $_
}

# Validate the subdirectories with empty directory and without active user.
$validationResult = Validate-Paths -subDirectoryPaths $validSubDirectoryPaths

# Display the list of valid subdirectories along with their ACLs.
Display-Paths -paths $validationResult -parentPath $parentPath

# Prompt the user for deletion if the prompt flag is set.
if ($prompt) {
    $pathsToDelete = $validationResult | Where-Object { $_.Empty -eq $true }
    Confirm-Deletion -basePath $parentPath -pathsToDelete $pathsToDelete
}
