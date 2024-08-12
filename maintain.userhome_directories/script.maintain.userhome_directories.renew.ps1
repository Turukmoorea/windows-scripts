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
    [switch]$help, # Switch to trigger the helppage.
    [switch]$h, # Switch to trigger the helppage.
    [switch]$debug, # Switch to trigger the debug mode.

    [string]$mode = "maintain", # Mode of operation, with a default value of "maintain".
    [string]$parentPath = $(Get-Location), # The parent directory path to operate on.
    [bool]$prompt = $true, # Flag indicating whether to prompt the user for confirmation.
    [string]$emptyDirectories = "retain"  # Specifies how to handle empty directories, defaulting to "retain".
)

$debugVarTable = @() # Initializes an empty, global debug table.

#Helppage =========================================================================================
# Function to display the helppage.
function Show-Helppage {
    Write-Output ""
    Write-Output "#Helppage =========================================================================================="
    Write-Output "Usage: <scriptname> [parameters]"
    
    $table = @()
    
    # Add rows to the table
    $table += [PSCustomObject]@{Parameter = "-help, -h   "; Options = ""; Default = ""; Description = "Display this help page." }
    $table += [PSCustomObject]@{Parameter = "-debug   "; Options = ""; Default = ""; Description = "Display all variable (step-by-step)" }
    $table += [PSCustomObject]@{Parameter = "-mode <string>   "; Options = "maintain, show, show all   "; Default = "maintain"; Description = "Select the script mode." }
    $table += [PSCustomObject]@{Parameter = "-parentPath <string>   "; Options = ""; Default = "current path   "; Description = "The absolute or relative parent directory path to access." }
    $table += [PSCustomObject]@{Parameter = "-prompt <bool>   "; Options = "0, `$false, 1, `$true   "; Default = "true   "; Description = "Flag indicating whether to prompt the user for confirmation." }
    $table += [PSCustomObject]@{Parameter = "-emptyDirectories <string>   "; Options = "retain, delete   "; Default = "retain   "; Description = "Specifies how to handle empty directories." }
    
    # Display the table
    $table | Format-Table -AutoSize
}

function Show-AllExitCode {
    Write-Output ""
    Write-Output "#All Exit-Codes ===================================================================================="
    $table = @()
    
    # Add rows to the table
    $table += [PSCustomObject]@{Code = ""; Row = ""; Function = "" }
    
    # Display the table
    $table | Format-Table -AutoSize
    Write-Output ""
}

# Check for help parameters and display the help page if any are found.
if ($help -or $h -or $question) {
    Show-Helppage
    Show-AllExitCode
    exit
}


#Ignore-List ======================================================================================

function Get-IgnoreList {
    $ignoreList = [PSCustomObject]@{
        SID = @(
            "S-1-1-0", # Everyone
            "S-1-5-18", # NT AUTHORITY\SYSTEM
            "S-1-5-32-544" # BUILTIN\Administrators
        )

        <#
        Next Item = @()
        #>
    }

    return $ignoreList
}


#Functions ========================================================================================

#Debug-Function -----------------------------------------------------------------------------------
function Write-DebugInfo {
    param (
        [string]$itemName,
        $itemValue,
        [string]$description
    )
    
    # Add rows to the table
    $debugVarTable += [PSCustomObject]@{Name = $itemName; Value = $itemValue; Description = $description }
}

function Show-DebugInfo() {
    Write-Host "#DEBUG-REPORT ======================================================================================"
    Write-Host "all variables"

    # Display the table
    $debugVarTable | Format-Table -AutoSize
}

Write-DebugInfo -itemName "debug" -itemValue $debug -description "Initial script parameter value"
Write-DebugInfo -itemName "mode" -itemValue $mode -description "Initial script parameter value"
Write-DebugInfo -itemName "parentPath" -itemValue $parentPath -description "Initial script parameter value"
Write-DebugInfo -itemName "prompt" -itemValue $prompt -description "Initial script parameter value"
Write-DebugInfo -itemName "emptyDirectories" -itemValue $emptyDirectories -description "Initial script parameter value"

#Resolve-AbsolutePath -----------------------------------------------------------------------------
# Function to resolve and validate the provided path.
function Resolve-AbsolutePath {
    param ([string]$inputPath)
    
    Write-DebugInfo -itemName "Resolve-AbsolutePath:inputPath" -itemValue $inputPath -description "Initial function parameter value"

    # Check if the path is absolute. If not, resolve it to an absolute path.
    if (-not [System.IO.Path]::IsPathRooted($inputPath)) {
        Write-DebugInfo -itemName "Resolve-AbsolutePath:inputPath" -itemValue $inputPath -description "The input path is an relative path."
        try {
            $resolvedPath = Resolve-Path -Path $inputPath -ErrorAction Stop
            Write-DebugInfo -itemName "Resolve-AbsolutePath:resolvedPath" -itemValue $resolvedPath -description ""

            if ($null -ne $resolvedPath) {
                $outputPath = $resolvedPath.ProviderPath
                Write-DebugInfo -itemName "Resolve-AbsolutePath:outputPath" -itemValue $outputPath -description "The output path could be resolved."
            }
        }
        catch {
            Write-Output "Error: Absolute path cannot be resolved."
            exit
        }
    }
    else {
        $outputPath = $inputPath
        Write-DebugInfo -itemName "Resolve-AbsolutePath" -itemValue $outputPath -description "The input path is an absolute path."
    }

    return $outputPath  # Return the resolved input path.
    Write-DebugInfo -itemName "Resolve-AbsolutePath:outputPath" -itemValue $outputPath -description "The function returned this value."
}

#Get-SubDirectories -------------------------------------------------------------------------------
# Function to get the names of subdirectories within the specified base path.
function Get-SubDirectories {
    param ([string]$basePath)  # The base directory path.
    return Get-ChildItem -Path $basePath -Directory | Select-Object -ExpandProperty Name
}

#Invoke-SubDirectories ----------------------------------------------------------------------------
function Invoke-SubDirectories {
    param (
        [string]$basePath, # The base directory path.
        [string[]]$childItems  # The subdirectory paths to validate.
    )

    # Arrays to hold valid and invalid paths.
    $validPaths = @()
    $invalidPaths = @()
    
    # Check each subdirectory path to see if it exists.
    foreach ($childItem in $childItems) {
        $fullPath = Join-Path -Path $basePath -ChildPath $childItems
        if (Test-Path -Path $fullPath) {
            $validPaths += $childItems
        }
        else {
            $invalidPaths += $childItems
        }
    }
    
    # Return a custom object containing both valid and invalid paths.
    return [PSCustomObject]@{
        Valid   = $validPaths
        Invalid = $invalidPaths
    }
}

#Convert-SID --------------------------------------------------------------------------------------
function Resolve-SID {
    param (
        [string]$sid
    )
    try {
        $sidObject = New-Object System.Security.Principal.SecurityIdentifier($sid)
        $ntAccount = $sidObject.Translate([System.Security.Principal.NTAccount])
        return [PSCustomObject]@{
            Valid = $true
            Value = $ntAccount
        }
    }
    catch {
        return [PSCustomObject]@{
            Valid = $false
            Value = $null
            ErrorMessage = $_.Exception.Message
        }
    }
}


#Validate-Paths -----------------------------------------------------------------------------------
function Select-ToProcessedPaths {
    param (
        [string[]]$Paths
    )

    $ignoreSIDs = Get-IgnoreList.SID
    $results = @()
    
    foreach ($path in $Paths) {
        # Check if the directory is empty.
        $items = Get-ChildItem -Path $path -Force -ErrorAction SilentlyContinue
        $isEmpty = -not ($items | Where-Object { $_.PSIsContainer -or $_.Length -gt 0 })
        
        # Get ACL and filter out ignored SIDs.
        $acl = Get-Acl -Path $path
        $aclEntries = $acl.Access | Where-Object {
            $sid = $_.IdentityReference.Translate([System.Security.Principal.SecurityIdentifier]).Value
            $ignoreSIDs -notcontains $sid
        } | ForEach-Object {
            "$($_.IdentityReference)"
        }
        $aclString = $aclEntries -join ", "

        # Check if there are unresolved SIDs.
        $unresolvedSIDs = $acl.Access | Where-Object {
            $sid = $_.IdentityReference.Translate([System.Security.Principal.SecurityIdentifier]).Value
            ($ignoreSIDs -notcontains $sid) -and -not (Is-SIDResolved -sid $sid)
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

#Mainscript =======================================================================================
if ($debug) {
    Show-DebugInfo
}


switch ($mode) {
    "maintain" {
        
        break
    }

    "show" {
        
        break
    }

    "show all" {

        break
    }

    default {
        break
    }
}