<#
===================================================================
Script Name:    file_flow_measuring_device.ps1
Author:         Turukmoorea
Contact:        mail@turukmoorea.ch
Repository:     https://github.com/Turukmoorea/windows-scripts
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
    [ValidateSet("all", "files", "all-files", "all-files-delete-dir")]
    [string]$TransferTypeParam,

    [Alias("v", "debug")]
    [switch]$VerboseParam
)

# ------------------------------------------------------------
# Define the source directory where the file is located.
# Must be an absolute path (e.g. "C:\source") or a relative path based on the script's location.
# ------------------------------------------------------------
$FileSourceDir = "test_source"

# ------------------------------------------------------------
# Define the destination directory where the file will be copied or moved.
# Must be an absolute path (e.g. "C:\destination") or a relative path based on the script's location.
# ------------------------------------------------------------
$FileDestinationDir = "test_destination"

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

# ------------------------------------------------------------
# Function: Get-UniqueDestinationPath
# Purpose : Generate a unique destination path by checking
#           for collisions and adding an incremental number
#           if necessary.
#
# Description:
#   This function checks whether a file or directory already
#   exists at the destination path. If it does, an incremental
#   number (_1, _2, _3, ...) is appended until a free name
#   is found.
#
# Parameters:
#   [string]$BaseName - The base name of the file or folder.
#   [string]$Extension - The extension (e.g. ".txt") or empty for folders.
#   [string]$DestinationDir - The target root directory.
#
# Returns:
#   [string] - A unique destination path.
# ------------------------------------------------------------
function Get-UniqueDestinationPath {
    param (
        [string]$BaseName,
        [string]$Extension,
        [string]$DestinationDir
    )

    $CandidateName = "$BaseName$Extension"
    $DestPath = Join-Path -Path $DestinationDir -ChildPath $CandidateName

    if (Test-Path $DestPath) {
        $Counter = 1
        do {
            $CandidateName = "{0}_{1}{2}" -f $BaseName, $Counter, $Extension
            $DestPath = Join-Path -Path $DestinationDir -ChildPath $CandidateName
            $Counter++
        } while (Test-Path $DestPath)
    }

    if ($Verbose) {
        if ($CandidateName -ne "$BaseName$Extension") {
            Write-Host "Collision detected. Using unique name: $CandidateName"
        }
    }

    return $DestPath
}

# ------------------------------------------------------------
# Perform the file or directory transfer based on TransferType and TransferMode.
#
# This version ensures that no files or folders are ever overwritten
# at the destination. Instead, Get-UniqueDestinationPath guarantees
# unique names by adding incremental suffixes (_1, _2, _3, ...).
# ------------------------------------------------------------

if ($Verbose) {
    Write-Host "------------------------------------------------------------"
    Write-Host "Starting transfer process..."
    Write-Host "Source Directory     : $FileSourceDir"
    Write-Host "Destination Directory: $FileDestinationDir"
    Write-Host "Transfer Mode        : $TransferMode"
    Write-Host "Transfer Type        : $TransferType"
    Write-Host "------------------------------------------------------------"
}

try {

    switch ($TransferType) {

        "all" {
            # ------------------------------------------------------------
            # Transfer Type: all
            # Description:
            #   Copy or move the entire source content, preserving the
            #   directory structure. Each item is processed individually
            #   to avoid overwriting existing items at the destination.
            # ------------------------------------------------------------
            if ($Verbose) {
                Write-Host "Transfer Type: all - transferring entire structure with collision protection."
            }

            $Items = Get-ChildItem -Path $FileSourceDir

            foreach ($Item in $Items) {
                $BaseName = $Item.BaseName
                $Extension = $Item.Extension
                if ($Item.PSIsContainer) {
                    # For folders: no extension
                    $DestPath = Get-UniqueDestinationPath -BaseName $Item.Name -Extension "" -DestinationDir $FileDestinationDir
                } else {
                    $DestPath = Get-UniqueDestinationPath -BaseName $BaseName -Extension $Extension -DestinationDir $FileDestinationDir
                }

                if ($TransferMode -eq "copy") {
                    Copy-Item -Path $Item.FullName -Destination $DestPath -Recurse -Force
                } elseif ($TransferMode -eq "move") {
                    Move-Item -Path $Item.FullName -Destination $DestPath -Force
                }

                if ($Verbose) {
                    Write-Host "Processed item: $($Item.FullName) -> $DestPath"
                }
            }
        }

        "files" {
            if ($Verbose) {
                Write-Host "Transfer Type: files - transferring only files in source root with collision protection."
            }

            $Files = Get-ChildItem -Path $FileSourceDir -File
            foreach ($File in $Files) {
                $DestPath = Get-UniqueDestinationPath -BaseName $File.BaseName -Extension $File.Extension -DestinationDir $FileDestinationDir

                if ($TransferMode -eq "copy") {
                    Copy-Item -Path $File.FullName -Destination $DestPath -Force
                } elseif ($TransferMode -eq "move") {
                    Move-Item -Path $File.FullName -Destination $DestPath -Force
                }

                if ($Verbose) {
                    Write-Host "Processed file: $($File.FullName) -> $DestPath"
                }
            }
        }

        "all-files" {
            if ($Verbose) {
                Write-Host "Transfer Type: all-files - transferring all files recursively, flattened, with collision protection."
            }

            $Files = Get-ChildItem -Path $FileSourceDir -File -Recurse
            foreach ($File in $Files) {
                $DestPath = Get-UniqueDestinationPath -BaseName $File.BaseName -Extension $File.Extension -DestinationDir $FileDestinationDir

                if ($TransferMode -eq "copy") {
                    Copy-Item -Path $File.FullName -Destination $DestPath -Force
                } elseif ($TransferMode -eq "move") {
                    Move-Item -Path $File.FullName -Destination $DestPath -Force
                }

                if ($Verbose) {
                    Write-Host "Processed file: $($File.FullName) -> $DestPath"
                }
            }
        }

        "all-files-delete-dir" {
            if ($Verbose) {
                Write-Host "Transfer Type: all-files-delete-dir - transferring all files recursively, flattened, with collision protection."
                Write-Host "After transfer, source directories will be deleted only if TransferMode is 'move'."
            }

            $Files = Get-ChildItem -Path $FileSourceDir -File -Recurse
            foreach ($File in $Files) {
                $DestPath = Get-UniqueDestinationPath -BaseName $File.BaseName -Extension $File.Extension -DestinationDir $FileDestinationDir

                if ($TransferMode -eq "copy") {
                    Copy-Item -Path $File.FullName -Destination $DestPath -Force
                } elseif ($TransferMode -eq "move") {
                    Move-Item -Path $File.FullName -Destination $DestPath -Force
                }

                if ($Verbose) {
                    Write-Host "Processed file: $($File.FullName) -> $DestPath"
                }
            }

            if ($TransferMode -eq "move") {
                if ($Verbose) {
                    Write-Host "Deleting leftover source directories since TransferMode is 'move'."
                }

                $Directories = Get-ChildItem -Path $FileSourceDir -Directory -Recurse
                foreach ($Dir in $Directories) {
                    try {
                        Remove-Item -Path $Dir.FullName -Force -Recurse -ErrorAction Stop
                        if ($Verbose) {
                            Write-Host "Deleted directory: $($Dir.FullName)"
                        }
                    } catch {
                        if ($Verbose) {
                            Write-Warning "Could not delete directory: $($Dir.FullName). It may not be empty or may be in use."
                        }
                    }
                }
            } else {
                if ($Verbose) {
                    Write-Host "TransferMode is 'copy'. Source directories will not be deleted."
                }
            }
        }

        default {
            Write-Error "Invalid TransferType specified: $TransferType"
            exit 1
        }
    }

    if ($Verbose) {
        Write-Host "------------------------------------------------------------"
        Write-Host "Transfer completed successfully."
        Write-Host "------------------------------------------------------------"
    }

    if (-not (Test-Path $FileDestinationDir)) {
        Write-Error "Destination directory does not exist after transfer operation."
        exit 1
    }

    exit 0

} catch {
    Write-Error "An error occurred during the transfer: $_"
    exit 1
}


if ($Verbose) {
    Write-Host "Transfer completed successfully."
}