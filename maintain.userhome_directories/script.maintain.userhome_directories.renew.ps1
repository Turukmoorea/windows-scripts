<#header ==========================================================================================
.SCRIPTNAME
    script.maintain.userhome_directories.ps1

.VERSION
    1.0

.AUTHOR
    Turukmoorea (github.com/turukmoorea)

.DESCRIPTION
    This script iterates through all subdirectories of a specified parent directory, validates the paths and ACLs,
    and provides the option to delete empty directories or those with unresolved security IDs (SIDs).
    It offers an interactive interface that allows users to decide whether certain directories should be deleted.
#>

#param ============================================================================================
param (
    [switch]$help,  # Switch to trigger the help page.
    [switch]$h,     # Alternative switch to trigger the help page (alias).

    [string]$mode = "maintain",          # Mode of operation, with a default value of "maintain".
    [string]$parentPath = $(Get-Location), # The parent directory path to operate on, defaulting to the current directory.
    [bool]$prompt = $true,               # Flag indicating whether to prompt the user for confirmation.
    [string]$emptyDirectories = "retain"  # Specifies how to handle empty directories, defaulting to "retain".
)

#Helppage =========================================================================================
# Function to display the help page.
function Show-Helppage {
    Write-Output ""
    Write-Output "#Helppage =========================================================================================="
    Write-Output "Usage: <scriptname> [parameters]"
    
    $table = @()
    
    # Define the parameters and descriptions to be displayed in the help page.
    $table += [PSCustomObject]@{Parameter = "-help, -h   "; Options = ""; Default = ""; Description = "Display this help page." }
    $table += [PSCustomObject]@{Parameter = "-mode <string>   "; Options = "maintain, show, show all   "; Default = "maintain"; Description = "Select the script mode." }
    $table += [PSCustomObject]@{Parameter = "-parentPath <string>   "; Options = ""; Default = "current path   "; Description = "The absolute or relative parent directory path to access." }
    $table += [PSCustomObject]@{Parameter = "-prompt <bool>   "; Options = "0, `$false, 1, `$true   "; Default = "true   "; Description = "Flag indicating whether to prompt the user for confirmation." }
    $table += [PSCustomObject]@{Parameter = "-emptyDirectories <string>   "; Options = "retain, delete   "; Default = "retain   "; Description = "Specifies how to handle empty directories." }
    
    # Display the table in a formatted way.
    $table | Format-Table -AutoSize
}

# Function to display exit codes and their meanings.
function Show-AllExitCode {
    Write-Output ""
    Write-Output "#All Exit-Codes ===================================================================================="
    $table = @()
    
    # Add rows to the exit code table.
    $table += [PSCustomObject]@{Code = "100"; Row = "69"; Function = "Show-Helppage Trigger" }
    
    # Display the table in a formatted way.
    $table | Format-Table -AutoSize
    Write-Output ""
}

# Check if the help or alias parameters are provided, and if so, display the help page and exit.
if ($help -or $h) {
    Show-Helppage
    Show-AllExitCode
    exit 100
}

#Ignore-List ======================================================================================
# Function to get a list of security identifiers (SIDs) that should be ignored.
function Get-IgnoreList {
    $ignoreList = [PSCustomObject]@{
        SID = @(
            "S-1-1-0",   # Everyone
            "S-1-5-18",  # NT AUTHORITY\SYSTEM
            "S-1-5-32-544" # BUILTIN\Administrators
        )
    }
    return $ignoreList
}

#Functions ========================================================================================

#Resolve-AbsolutePath -----------------------------------------------------------------------------
# Function to resolve and validate the provided path.
function Resolve-AbsolutePath {
    param ([string]$inputPath)

    # Check if the path is absolute. If not, resolve it to an absolute path.
    if (-not [System.IO.Path]::IsPathRooted($inputPath)) {
        try {
            # Attempt to resolve the path to an absolute path.
            $resolvedPath = Resolve-Path -Path $inputPath -ErrorAction Stop

            # If the path was successfully resolved, log and return it.
            if ($null -ne $resolvedPath) {
                $outputPath = $resolvedPath.ProviderPath
            }
        }
        catch {
            # If resolving the path fails, output an error and exit.
            Write-Output "Error: Absolute path cannot be resolved."
            exit 101
        }
    }
    else {
        # If the input path is already absolute, just return it.
        $outputPath = $inputPath
    }

    return $outputPath  # Return the resolved absolute path.
}

#Get-SubDirectories -------------------------------------------------------------------------------
# Function to get the names of subdirectories within the specified base path.
function Get-SubItems {
    param ([string]$basePath)  # The base directory path.
    
    # Get all items and filter only directories
    $subItems = Get-ChildItem -Path $basePath | Where-Object { $_.PSIsContainer } | Select-Object -ExpandProperty Name
    return $subItems
}

#Invoke-SubDirectories ----------------------------------------------------------------------------
# Function to validate subdirectory paths within the base path.
function Invoke-SubItems {
    param (
        [string]$basePath,  # The base directory path.
        [string[]]$subItems # The subdirectory paths to validate.
    )

    # Arrays to hold valid and invalid paths.
    $validPaths = @()
    $invalidPaths = @()
    
    # Iterate through each subdirectory and check if it exists.
    foreach ($subItem in $subItems) {
        $fullPath = Join-Path -Path $basePath -ChildPath $subItem
        if (Test-Path -Path $fullPath) {
            $validPaths += $fullPath
        }
        else {
            $invalidPaths += $fullPath
        }
    }
    
    # Return a custom object containing both valid and invalid paths.
    $result = [PSCustomObject]@{
        Valid   = $validPaths
        Invalid = $invalidPaths
    }
    return $result
}

#Convert-SID --------------------------------------------------------------------------------------
# Function to resolve a SID to a human-readable account name.
function Resolve-SID {
    param (
        [string]$sid  # The SID to resolve.
    )
    try {
        # Attempt to translate the SID into an NT account name.
        $sidObject = New-Object System.Security.Principal.SecurityIdentifier($sid)
        $ntAccount = $sidObject.Translate([System.Security.Principal.NTAccount])
        $result = [PSCustomObject]@{
            Valid = $true
            Value = $ntAccount
        }
        return $result
    }
    catch {
        # If translation fails, return the error message.
        $result = [PSCustomObject]@{
            Valid = $false
            Value = $null
            ErrorMessage = $_.Exception.Message
        }
        return $result
    }
}

# Select-ToProcessedPaths -----------------------------------------------------------------------------------
# Function to process a list of paths and select those to be further validated or deleted.
function Select-ToProcessedPaths {
    param (
        [string[]]$paths  # The list of paths to process.
    )

    $results = @()
    
    foreach ($path in $paths) {
        # Check if the directory is empty.
        $items = Get-ChildItem -Path $path -Force -ErrorAction SilentlyContinue
        $isEmpty = -not ($items | Where-Object { $_.PSIsContainer -or $_.Length -gt 0 })
        
        # Get the Access Control List (ACL) and filter out ignored SIDs.
        $acl = Get-Acl -Path $path
        $aclEntries = $acl.Access | Where-Object {
            $identityReference = $_.IdentityReference
            $sid = $null
            if ($identityReference -ne $null) {
                $sid = $identityReference.Translate([System.Security.Principal.SecurityIdentifier]).Value
            }
            $ignoreSIDs -notcontains $sid
        } | ForEach-Object {
            "$($_.IdentityReference)"
        }
        
        # Convert ACL entries to a comma-separated string.
        $aclString = $aclEntries -join ", "

        # Check if there are unresolved SIDs.
        $unresolvedSIDs = $acl.Access | Where-Object {
            $sid = $null
            if ($_.IdentityReference -ne $null) {
                $sid = $_.IdentityReference.Translate([System.Security.Principal.SecurityIdentifier]).Value
            }
            ($ignoreSIDs -notcontains $sid) -and -not (Resolve-SID -sid $sid)
        }
        
        # Include directories based on specified conditions.
        if ($emptyDirectories -eq "delete") {
            if ($isEmpty -or $unresolvedSIDs.Count -gt 0) {
                $results += [PSCustomObject]@{
                    Path  = $path
                    Name  = [System.IO.Path]::GetFileName($path)
                    Empty = $isEmpty
                    ACL   = $aclString
                }
            }
        } else {
            if (($isEmpty -and $unresolvedSIDs.Count -gt 0) -or -not $isEmpty -and $unresolvedSIDs.Count -gt 0) {
                $results += [PSCustomObject]@{
                    Path  = $path
                    Name  = [System.IO.Path]::GetFileName($path)
                    Empty = $isEmpty
                    ACL   = $aclString
                }
            }
        }
    }
    
    return $results
}

# Function to display the list of paths with a message.
function Show-ValidatedPaths {
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
                Directory = $_.Name  # Only show the directory name.
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
function Remove-Directories {
    param (
        [string]$basePath,  # The base directory path containing the paths to delete.
        [PSCustomObject[]]$pathsToDelete  # List of paths to consider for deletion.
    )
    
    # Ask the user if they want to delete all selected paths.
    $deleteAll = Read-Host "Do you want to delete all selected paths? (yes/no)"
    if ($deleteAll -eq "yes") {
        # If yes, delete each path.
        $pathsToDelete | ForEach-Object {
            Remove-Item -Path $_.Path -Recurse -Force
            Write-Output "Deleted path: $($_.Name)"
        }
    } else {
        # Otherwise, prompt for specific paths to delete.
        $selectedToDelete = Read-Host "Enter the indices of paths to delete, separated by commas (e.g., 0,1)"
        $indices = $selectedToDelete -split "," | ForEach-Object { [int]$_.Trim() }
        
        # Delete the specified paths by index.
        foreach ($index in $indices) {
            if ($index -ge 0 -and $index -lt $pathsToDelete.Count) {
                $pathToDelete = $pathsToDelete[$index]
                Remove-Item -Path $pathToDelete.Path -Recurse -Force
                Write-Output "Deleted path: $($pathToDelete.Name)"
            } else {
                Write-Output "Invalid index: $index"
            }
        }
    }
}

#Mainscript =======================================================================================
# Main script logic starts here.

# Resolve the parent path to an absolute path.
$parentPath = Resolve-AbsolutePath -inputPath $parentPath

# Get the list of subdirectories within the parent path.
$childItems = Get-SubItems -basePath $parentPath

# Validate subdirectory paths.
$validatedPaths = Invoke-SubItems -basePath $parentPath -subItems $childItems

# Get the list of SIDs to ignore.
$ignoreSIDs = (Get-IgnoreList).SID

# Determine the script mode and take action accordingly.
switch ($mode) {
    "maintain" {
        # In "maintain" mode, process and display the paths, then prompt for deletion.
        $selectedPaths = Select-ToProcessedPaths -paths $validatedPaths.Valid

        Show-ValidatedPaths -paths $selectedPaths -message "Directories found in ${parentPath}:"
        
        Remove-Directories -basePath $parentPath -pathsToDelete $selectedPaths

        break
    }

    "show" {
        # In "show" mode, just process and display the paths without deletion.
        $selectedPaths = Select-ToProcessedPaths -paths $validatedPaths.Valid

        Show-ValidatedPaths -paths $selectedPaths -message "Directories found in ${parentPath}:"
        
        break
    }

    "show all" {
        # In "show all" mode, display all validated paths.
        Show-ValidatedPaths -paths $validatedPaths.Valid -message "Directories found in ${parentPath}:"

        break
    }

    default {
        Write-Output "Invalid mode selected."
        break
    }
}
