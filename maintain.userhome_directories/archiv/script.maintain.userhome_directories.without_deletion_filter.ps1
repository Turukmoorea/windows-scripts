param (
    [string]$parentPath,  # The parent directory path to operate on. This parameter specifies the directory within which operations will be performed.
    [bool]$prompt = $true,  # A flag indicating whether to prompt the user for confirmation. If set to true, the script will prompt the user before performing certain actions.
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
    return Get-ChildItem -Path $basePath -Directory | Select-Object -ExpandProperty Name
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

function Validate-Paths {
    param (
        [string]$emptyDirectories,  # A string parameter to specify how to handle empty directories.
        [string[]]$Paths  # Array of subdirectory paths to validate.
    )
    
    $results = @()
    
    # Liste der zu ignorierenden SIDs
    $ignoreSIDs = @(
        "S-1-1-0",  # Everyone
        "S-1-5-18", # NT AUTHORITY\SYSTEM
        "S-1-5-32-544" # BUILTIN\Administrators
    )
    
    # Function to check if SID can be resolved
    function Is-SIDResolved {
        param (
            [string]$sid
        )
        try {
            $sidObject = New-Object System.Security.Principal.SecurityIdentifier($sid)
            $sidObject.Translate([System.Security.Principal.NTAccount])
            return $true
        } catch {
            return $false
        }
    }
    
    # For each subdirectory path, get the ACL and format the output.
    foreach ($path in $Paths) {
        # Check if the directory is empty
        $items = Get-ChildItem -Path $path -Force -ErrorAction SilentlyContinue
        $isEmpty = -not ($items | Where-Object { $_.PSIsContainer -or $_.Length -gt 0 })
        
        # Get ACL and filter out ignored SIDs and check if SID is resolved
        $acl = Get-Acl -Path $path
        $aclEntries = $acl.Access | Where-Object {
            $sid = $_.IdentityReference.Translate([System.Security.Principal.SecurityIdentifier]).Value
            ($ignoreSIDs -notcontains $sid) -and (Is-SIDResolved -sid $sid)
        } | ForEach-Object {
            "$($_.IdentityReference)"
        }
        $aclString = $aclEntries -join ", "
        
        # Create a custom object with the path, its empty status, and its ACL string.
        $results += [PSCustomObject]@{
            Path  = [System.IO.Path]::GetFileName($path)  # Only show the directory name.
            Empty = $isEmpty
            ACL   = $aclString
        }
    }
    
    return $results
}

# Function to display the list of paths with a message.
function Display-Paths {
    param (
        [PSCustomObject[]]$paths,  # List of paths with ACL to display.
        [string]$message  # Message to display with the paths.
    )
    
    # If there are paths to display, list them with their indices.
    if ($paths.Count -gt 0) {
        Write-Output "----------------------------------------------------------------------"
        Write-Output "$($paths.Count) $message"
        $pathsTable = @()
        $i = 0
        $paths | ForEach-Object {
            $emptyFolder = if ($_.Empty -eq $true) {"empty"} else {"not empty"}
            $pathsTable += [PSCustomObject]@{
                Index = $i
                Directory = $_.Path
                Status = $emptyFolder
                ACL = $_.ACL
            }
            $i++
        }
        
        $pathsTable | Format-Table -AutoSize
    } else {
        Write-Output "No valid paths to select."
        exit
    }
}


# Function to prompt the user for path deletion.
function Confirm-Deletion {
    param (
        [string]$basePath,  # The base directory path containing the paths to delete.
        [string[]]$pathsToDelete  # List of paths to consider for deletion.
    )
    
    # Ask the user if they want to delete all selected paths.
    Write-Output "----------------------------------------------------------------------"
    $deleteAll = Read-Host "Do you want to delete all selected paths? (yes/no)"
    if ($deleteAll -eq "yes") {
        # If yes, delete each path.
        $pathsToDelete | ForEach-Object {
            Remove-Item -Path (Join-Path -Path $basePath -ChildPath $_) -Recurse -Force
            Write-Output "Deleted path: $_"
        }
    } else {
        # Otherwise, prompt for specific paths to delete.
        $selectedToDelete = Read-Host "Enter the indices of paths to delete, separated by commas (e.g., 0,1)"
        $indices = $selectedToDelete -split "," | ForEach-Object { [int]$_.Trim() }
        
        # Delete the specified paths by index.
        foreach ($index in $indices) {
            if ($index -ge 0 -and $index -lt $pathsToDelete.Count) {
                $pathToDelete = $pathsToDelete[$index]
                Remove-Item -Path (Join-Path -Path $basePath -ChildPath $pathToDelete) -Recurse -Force
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
$validationResult = Validate-Paths -Paths $validSubDirectoryPaths -emptyDirectories $emptyDirectories

# Display the list of valid subdirectories along with their ACLs.
Display-Paths -paths $validationResult -message "directories found in ${parentPath}:"

# Prompt the user for deletion if the prompt flag is set.
#if ($prompt) {
#    Confirm-Deletion -basePath $parentPath -pathsToDelete $validationResult | Select-Object -ExpandProperty Path
#}
