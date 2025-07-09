<#
===================================================================
Script Name:    file_flow_measuring_device.ps1
Author:         Turukmoorea
Contact:        mail@turukmoorea.ch
Repository:     https://github.com/Turukmoorea/your-repo
Last Updated:   2025-07-09
License:        Unlicense (https://unlicense.org)

Description:
    This script copies or moves a file from a defined source 
    directory to a defined destination directory. 
    It allows measuring the file flow process by optionally 
    providing CLI output.

    The behavior is controlled by the following variables:
      - $FileSourceDir:      The source directory of the file.
      - $FileDestinationDir: The destination directory where 
                             the file will be copied or moved.
      - $Verbose:            If set to $true, the script will 
                             output status messages to the console.
      - $TransferMode:       Defines whether to copy or move 
                             the file ("copy" or "move").

Usage Example:
    .\file_flow_measuring_device.ps1 -Verbose $true -TransferMode "copy"

Global Variables:
    $FileSourceDir      - Path to the source directory (e.g. "C:\Input")
    $FileDestinationDir - Path to the destination directory (e.g. "C:\Output")
    $Verbose            - Boolean flag for CLI output (default: $false)
    $TransferMode       - String, must be "copy" or "move" (default: "copy")

Dependencies:
    None (uses built-in PowerShell cmdlets)

===================================================================
#>

# ------------------------------------------------------------
# Script Parameters with short aliases
# ------------------------------------------------------------
param (
    [Alias("s")]
    [string]$FileSourceDirParam,

    [Alias("d")]
    [string]$FileDestinationDirParam,

    [Alias("m")]
    [ValidateSet("copy", "move")]
    [string]$TransferModeParam,

    [Alias("t", "type")]
    [ValidateSet("all", "files", "all-files")]
    [string]$TransferTypeParam,

    [Alias("v", "debug")]
    [switch]$VerboseParam
)

# ------------------------------------------------------------
# Define the source directory where the file is located.
# Must be an absolute path. Example: "C:\Input"
# ------------------------------------------------------------
$FileSourceDir = "C:\Users\timon.bachmann\OneDrive - MAIT GmbH\Dokumente\GitHub\file_flow_measuring_device\test_source"

# ------------------------------------------------------------
# Define the destination directory where the file will be copied or moved.
# Must be an absolute path. Example: "C:\Output"
# ------------------------------------------------------------
$FileDestinationDir = "C:\Users\timon.bachmann\OneDrive - MAIT GmbH\Dokumente\GitHub\file_flow_measuring_device\test_destination"

# ------------------------------------------------------------
# Define the transfer mode.
# Accepts "copy" to copy the file or "move" to move the file.
# Default: "copy"
# ------------------------------------------------------------
$TransferMode = "copy"

# ------------------------------------------------------------
# Define the transfer type.
# Controls which files and folders will be processed.
# Accepts:
#   "all"       - Transfer entire content including all subfolders and files.
#   "files"     - Transfer only files directly inside the source directory.
#   "all-files" - Transfer all files recursively but flatten the directory
#                 structure in the destination.
# Default: "all"
# ------------------------------------------------------------
$TransferType = "all"


# ------------------------------------------------------------
# Define whether to output status messages to the console.
# Set to $true for verbose output, $false for silent mode.
# Default: $false
# ------------------------------------------------------------
$Verbose = $true  # Set to $true to see outputs for testing

# ------------------------------------------------------------
# Override defaults with parameter values if provided
# ------------------------------------------------------------
if ($FileSourceDirParam) { $FileSourceDir = $FileSourceDirParam }
if ($FileDestinationDirParam) { $FileDestinationDir = $FileDestinationDirParam }
if ($TransferModeParam) { $TransferMode = $TransferModeParam }
if ($TransferTypeParam) { $TransferType = $TransferTypeParam }
if ($VerboseParam.IsPresent) { $Verbose = $true }

# ------------------------------------------------------------
# Output final settings if verbose
# ------------------------------------------------------------
if ($Verbose) {
    Write-Host "Set Source Directory: $FileSourceDir"
    Write-Host "Set Destination Directory: $FileDestinationDir"
    Write-Host "Set Transfer Mode: $TransferMode"
    Write-Host "Set Transfer Type: $TransferType"
    Write-Host "Set Verbose Mode: $Verbose"
}

# ------------------------------------------------------------
# Function: Validate-AbsolutePath
# Purpose : Ensure that the provided path is absolute and exists.
#
# Description:
#   This function checks if a given path is absolute.
#   If it is relative, it converts it to an absolute path.
#   Finally, it checks if the path exists on the filesystem.
#   The function returns the validated absolute path.
#
# Parameters:
#   [string]$Path - The input path to validate.
#
# Returns:
#   [string] - The absolute, validated path.
#
# Notes:
#   Exits the script with error code 1 if the path does not exist.
# ------------------------------------------------------------
function Validate-AbsolutePath {
    param (
        [string]$Path
    )

    if ($Verbose) {
        Write-Host "Validating path: $Path"
    }

    # Check if path is already absolute
    if (-not [System.IO.Path]::IsPathRooted($Path)) {
        if ($Verbose) {
            Write-Host "Path is not absolute. Converting to absolute path..."
        }
        $Path = Join-Path -Path (Get-Location) -ChildPath $Path
    }

    # Resolve potential relative tokens (like "..")
    try {
        $ResolvedPath = (Resolve-Path -Path $Path -ErrorAction Stop).ProviderPath

        if ($Verbose) {
            Write-Host "Resolved path: $ResolvedPath"
        }

    } catch {
        Write-Error "Path '$Path' does not exist."
        exit 1
    }

    return $ResolvedPath
}

# Validate and overwrite variables with validated absolute paths
$FileSourceDir = Validate-AbsolutePath -Path $FileSourceDir
$FileDestinationDir = Validate-AbsolutePath -Path $FileDestinationDir

if ($Verbose) {
    Write-Host "Set Source directory validated: $FileSourceDir"
    Write-Host "Set Destination directory validated: $FileDestinationDir"
}

