<#
===================================================================
Script Name:    file_flow_measuring_device.ps1
Author:         Turukmoorea
Contact:        mail@turukmoorea.ch
Repository:     https://github.com/Turukmoorea/windows-scripts
Last Updated:   2025-07-09
License:        This script is released under the Unlicense
                (https://unlicense.org)

Description:
    This script measures and manages the flow of files from a defined
    source directory to a defined destination directory. It supports
    different transfer modes and types to handle both simple and
    complex file structures safely.

    Features:
      - Copy or move entire folders, specific files, or flatten nested
        structures into a single destination folder.
      - Prevents overwriting of existing files or folders at the
        destination by automatically adding incremental suffixes.
      - Supports removing empty source directories after transfer
        (only when using move mode with "all-files-delete-dir").
      - Fully configurable via CLI parameters or inline variables.
      - Verbose output for clear tracking, or silent mode for quiet runs.

Usage Example:
    # Copy all files recursively and flatten structure:
    .\file_flow_measuring_device.ps1 -s "C:\Source" -d "C:\Destination" -m "copy" -t "all-files" -v

    # Move files and delete leftover empty folders:
    .\file_flow_measuring_device.ps1 -s "C:\Source" -d "C:\Destination" -m "move" -t "all-files-delete-dir" -v

Parameters:
    -s, --source           : Source directory path (absolute or relative)
    -d, --destination      : Destination directory path (absolute or relative)
    -m, --mode             : Transfer mode ("copy" or "move")
    -t, --type             : Transfer type:
                               "all"                - Entire structure.
                               "files"              - Only files in root.
                               "all-files"          - All files flattened.
                               "all-files-delete-dir" - Flattened & remove
                                                         empty source dirs.
    -v, --verbose, --debug : Enable verbose output.
    --silent, --quiet      : Disable all output messages.

Dependencies:
    - Requires only built-in PowerShell cmdlets: Copy-Item, Move-Item, Get-ChildItem, Resolve-Path, Remove-Item.

Notes:
    - Always run this script with appropriate file system permissions.
    - Verify that the source and destination directories are correct
      to prevent unintended data moves or copies.
    - Designed to be idempotent: running multiple times will never
      overwrite existing files.

===================================================================
#>

# ------------------------------------------------------------
# Script Parameters with short aliases
# ------------------------------------------------------------
param (
    [Alias("s")]
    [string]$source,

    [Alias("d")]
    [string]$destination,

    [Alias("m")]
    [ValidateSet("copy", "move")]
    [string]$mode,

    [Alias("t")]
    [ValidateSet("all", "files", "all-files", "all-files-delete-dir")]
    [string]$type,

    [Alias("v", "debug")]
    [switch]$verbose,
	
    [switch]$silent
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
#   "all"               - Transfer entire content including all subfolders and files.
#   "files"             - Transfer only files directly inside the source directory.
#   "all-files"         - Transfer all files recursively but flatten the directory
#                         structure in the destination.
#   "all-files-delete-dir"
#                       - Same as "all-files" but deletes leftover empty source
#                         directories after moving files (only in move mode).
# Default: "all"
# ------------------------------------------------------------
$TransferType = "all"

# ------------------------------------------------------------
# Define whether to output status messages to the console.
# Set to $true for verbose output, $false for silent mode.
# Default: $false
# ------------------------------------------------------------
$Verbose = $true

# ------------------------------------------------------------
# Override defaults with parameter values if provided
# ------------------------------------------------------------
if ($source) { $FileSourceDir = $source }
if ($destination) { $FileDestinationDir = $destination }
if ($mode) { $TransferMode = $mode }
if ($type) { $TransferType = $type }
if ($verbose.IsPresent) { $Verbose = $true }
if ($silent.IsPresent) { $Verbose = $false }

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
#   This function ensures that an input path is valid for use in 
#   file operations. It performs three steps:
#     1. Check if the path is already absolute.
#     2. If it is relative, convert it to an absolute path.
#     3. Resolve the path to ensure that it exists on disk.
#
#   If the path does not exist, the script exits with error code 1.
#   If Verbose mode is enabled, detailed status messages are shown.
#
# Parameters:
#   [string]$Path - The input path to validate.
#
# Returns:
#   [string] - The absolute, validated path.
# ------------------------------------------------------------
function Validate-AbsolutePath {
    param (
        [string]$Path
    )

    # --------------------------------------------------------
    # If Verbose mode is enabled, output the path being validated.
    # --------------------------------------------------------
    if ($Verbose) {
        Write-Host "Validating path: $Path"
    }

    # --------------------------------------------------------
    # Step 1: Check if the provided path is already absolute.
    # Uses [System.IO.Path]::IsPathRooted to determine this.
    #
    # If the path is relative, join it with the current 
    # working directory to create an absolute path.
    #
    # Example:
    #   Input: "data\input"
    #   Output: "C:\Current\Working\Dir\data\input"
    # --------------------------------------------------------
    if (-not [System.IO.Path]::IsPathRooted($Path)) {
        if ($Verbose) {
            Write-Host "Path is not absolute. Converting to absolute path..."
        }

        # Join-Path combines current location with relative input
        $Path = Join-Path -Path (Get-Location) -ChildPath $Path
    }

    # --------------------------------------------------------
    # Step 2: Resolve the path.
    # This expands any relative tokens like ".." or "."
    # and checks that the path actually exists.
    #
    # Resolve-Path will throw an error if the path is invalid.
    # If so, the catch block will exit the script.
    # --------------------------------------------------------
    try {
        $ResolvedPath = (Resolve-Path -Path $Path -ErrorAction Stop).ProviderPath

        if ($Verbose) {
            Write-Host "Resolved path: $ResolvedPath"
        }

    } catch {
        # --------------------------------------------------------
        # If Resolve-Path fails, output an error message and exit.
        # This prevents the script from continuing with invalid paths.
        # --------------------------------------------------------
        Write-Error "Path '$Path' does not exist."
        exit 1
    }

    # --------------------------------------------------------
    # Return the validated, absolute path for use in the script.
    # --------------------------------------------------------
    return $ResolvedPath
}

# ------------------------------------------------------------
# Validate the source and destination directories using the function.
# This ensures both paths are absolute and exist before proceeding.
# ------------------------------------------------------------
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
#   This function ensures that no file or directory at the target
#   destination is overwritten. It works for both files and folders.
#   If a path with the given name already exists, it will append
#   an incremental numeric suffix (_1, _2, _3, ...) to create a 
#   unique name.
#
#   Example:
#     If "report.txt" exists, it will try "report_1.txt", "report_2.txt", etc.
#
#   Verbose mode shows the final name if a collision was detected.
#
# Parameters:
#   [string]$BaseName - The base name of the file or folder, without extension.
#   [string]$Extension - The file extension including dot (e.g. ".txt"), or empty for folders.
#   [string]$DestinationDir - The root destination directory where the item will be placed.
#
# Returns:
#   [string] - The full unique destination path, guaranteed to be free.
# ------------------------------------------------------------
function Get-UniqueDestinationPath {
    param (
        [string]$BaseName,
        [string]$Extension,
        [string]$DestinationDir
    )

    # --------------------------------------------------------
    # Start with the initial candidate name using base name 
    # and extension. This forms the default output if no 
    # existing file or folder conflicts are found.
    #
    # Example:
    #   BaseName: "data_file"
    #   Extension: ".log"
    #   CandidateName: "data_file.log"
    # --------------------------------------------------------
    $CandidateName = "$BaseName$Extension"

    # Combine the candidate name with the destination directory.
    $DestPath = Join-Path -Path $DestinationDir -ChildPath $CandidateName

    # --------------------------------------------------------
    # Check if the path already exists at the destination.
    # If it does, append an incremental suffix (_1, _2, ...) 
    # until a unique name is found.
    # --------------------------------------------------------
    if (Test-Path $DestPath) {
        $Counter = 1

        do {
            # Format the new candidate name with the current counter value.
            # Example: "data_file_1.log", "data_file_2.log", etc.
            $CandidateName = "{0}_{1}{2}" -f $BaseName, $Counter, $Extension

            # Combine again to get the full path for this candidate.
            $DestPath = Join-Path -Path $DestinationDir -ChildPath $CandidateName

            # Increment the counter for the next try if needed.
            $Counter++

        } while (Test-Path $DestPath)
    }

    # --------------------------------------------------------
    # Output the final unique name if a collision was handled.
    # This helps to track which files or folders were renamed.
    # --------------------------------------------------------
    if ($Verbose) {
        if ($CandidateName -ne "$BaseName$Extension") {
            Write-Host "Collision detected. Using unique name: $CandidateName"
        }
    }

    # --------------------------------------------------------
    # Return the full path which does not conflict with 
    # any existing file or folder.
    # --------------------------------------------------------
    return $DestPath
}

# ------------------------------------------------------------
# Block: Perform Transfer Process
# Purpose : Copy or move files and folders from source to 
#           destination based on the selected TransferType 
#           and TransferMode.
#
# Description:
#   This block uses a switch statement to handle all supported 
#   TransferTypes:
#
#     - "all":               Transfer entire directory structure, 
#                            including subfolders and files.
#                            Each item is checked to prevent 
#                            overwriting at destination.
#
#     - "files":             Transfer only files directly in the 
#                            root of the source directory.
#
#     - "all-files":         Transfer all files recursively but 
#                            flatten the structure in the destination.
#
#     - "all-files-delete-dir":
#                            Same as "all-files" but deletes leftover 
#                            empty source directories after moving files 
#                            (only if TransferMode is "move").
#
#   The block uses Get-UniqueDestinationPath to ensure that no 
#   existing files or folders are overwritten at the destination.
#   Verbose mode outputs detailed status messages for each step.
#
#   If the destination does not exist after processing, the script 
#   exits with error code 1 to prevent silent data loss.
#
# Notes:
#   - Uses built-in Copy-Item and Move-Item cmdlets.
#   - Verbose output helps to trace each processed item.
#   - Uses try/catch to handle unexpected errors safely.
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
			# Purpose :
			#   Copy or move the entire source content, preserving the
			#   original directory structure. Every file and folder
    	    #   is processed individually to ensure that no existing
            	#   items at the destination are overwritten.
			#
			# Description:
			#   - Iterates through all immediate children (files and folders)
			#     in the source directory.
			#   - For each item, calls Get-UniqueDestinationPath to create
			#     a unique name if a name collision would occur.
			#   - Uses Copy-Item with -Recurse for folders and files.
			#   - Supports both Copy and Move modes based on TransferMode.
			#   - Verbose mode outputs detailed info for each processed item.
			#
			# Example:
			#   If the source contains "project" and a folder "project"
			#   already exists at the destination, the function will
			#   rename it to "project_1" or higher to avoid overwrite.
			#
			# Notes:
			#   Uses built-in Get-ChildItem, Copy-Item, and Move-Item.
			#   Safe for nested structures since folders are handled
			#   with -Recurse.
			# ------------------------------------------------------------
			if ($Verbose) {
				# Output info about what will happen in this block
				Write-Host "Transfer Type: all - transferring entire structure with collision protection."
			}

			# Get all files and folders in the root of the source directory
			$Items = Get-ChildItem -Path $FileSourceDir

			# Iterate through each item to handle it individually
			foreach ($Item in $Items) {

				# Extract the base name and extension for collision checks
				$BaseName = $Item.BaseName
				$Extension = $Item.Extension

				# --------------------------------------------------------
				# If the item is a folder (PSIsContainer = $true),
				# pass its name as BaseName and no extension.
				# Otherwise, pass both BaseName and Extension.
				# --------------------------------------------------------
				if ($Item.PSIsContainer) {
					$DestPath = Get-UniqueDestinationPath `
						-BaseName $Item.Name `
						-Extension "" `
						-DestinationDir $FileDestinationDir
				} else {
					$DestPath = Get-UniqueDestinationPath `
						-BaseName $BaseName `
						-Extension $Extension `
						-DestinationDir $FileDestinationDir
				}

				# --------------------------------------------------------
				# Perform the copy or move operation.
				# Copy-Item uses -Recurse for folders, safe for files too.
				# --------------------------------------------------------
				if ($TransferMode -eq "copy") {
					Copy-Item -Path $Item.FullName -Destination $DestPath -Recurse -Force
				} elseif ($TransferMode -eq "move") {
					Move-Item -Path $Item.FullName -Destination $DestPath -Force
				}
	
				# --------------------------------------------------------
				# If Verbose is enabled, output the source and final
				# destination path for traceability.
				# --------------------------------------------------------
				if ($Verbose) {
					Write-Host "Processed item: $($Item.FullName) -> $DestPath"
				}
			}
		}
		
		"files" {
			# ------------------------------------------------------------
			# Transfer Type: files
			# Purpose :
			#   Copy or move only the files located directly in the root
			#   of the source directory. Subfolders are ignored.
			#
			# Description:
			#   - Finds all files in the top-level source directory.
			#   - Uses Get-UniqueDestinationPath to ensure that each file
			#     does not overwrite an existing file in the destination.
			#   - Supports both Copy and Move operations.
			#   - Verbose mode outputs detailed info for each processed file.
			#
			# Example:
			#   If "report.txt" already exists in the destination,
			#   the function will rename it to "report_1.txt" or higher.
			#
			# Notes:
			#   Uses built-in Get-ChildItem, Copy-Item, and Move-Item.
			#   Only files are included; folders are skipped.
			# ------------------------------------------------------------
			if ($Verbose) {
				# Output info about what will happen in this block
				Write-Host "Transfer Type: files - transferring only files in source root with collision protection."
			}

			# Get all files directly in the source directory (non-recursive)
			$Files = Get-ChildItem -Path $FileSourceDir -File

			# Iterate through each file to process individually
			foreach ($File in $Files) {

				# --------------------------------------------------------
				# Get a unique destination path for this file to prevent
				# overwriting an existing file with the same name.
				# --------------------------------------------------------
				$DestPath = Get-UniqueDestinationPath `
					-BaseName $File.BaseName `
					-Extension $File.Extension `
					-DestinationDir $FileDestinationDir
	
				# --------------------------------------------------------
				# Perform the copy or move operation.
				# --------------------------------------------------------
				if ($TransferMode -eq "copy") {
					Copy-Item -Path $File.FullName -Destination $DestPath -Force
				} elseif ($TransferMode -eq "move") {
					Move-Item -Path $File.FullName -Destination $DestPath -Force
				}

                # --------------------------------------------------------
                # If Verbose is enabled, output the processed file path
                # and its final resolved destination path.
                # --------------------------------------------------------
                if ($Verbose) {
                    Write-Host "Processed file: $($File.FullName) -> $DestPath"
                }
            }
		}
		
		"all-files" {
            # ------------------------------------------------------------
            # Transfer Type: all-files
            # Purpose :
            #   Copy or move all files found recursively in the source
            #   directory, but flatten the directory structure so that 
            #   all files are placed directly in the destination root.
            #
            # Description:
            #   - Recursively finds every file under the source directory,
            #     including files in all subfolders.
            #   - For each file, Get-UniqueDestinationPath ensures that 
            #     no existing file in the destination is overwritten.
            #   - The original folder structure is discarded; only the files 
            #     are copied or moved.
            #   - Supports both Copy and Move operations.
            #   - Verbose mode outputs the source file and final destination path.
            #
            # Example:
            #   If a file "logs\2024\report.txt" is found and a file named 
            #   "report.txt" already exists in the destination root, it will 
            #   be renamed to "report_1.txt" or higher.
            #
            # Notes:
            #   Uses built-in Get-ChildItem with -Recurse, Copy-Item, and Move-Item.
            #   Ensures all files end up flat in the destination folder.
            # ------------------------------------------------------------
            if ($Verbose) {
                # Output info about what will happen in this block
                Write-Host "Transfer Type: all-files - transferring all files recursively, flattened, with collision protection."
            }

            # Get all files recursively under the source directory
            $Files = Get-ChildItem -Path $FileSourceDir -File -Recurse

            # Iterate through each file found recursively
            foreach ($File in $Files) {

                # --------------------------------------------------------
                # Get a unique destination path for this file to prevent
                # overwriting an existing file with the same name.
                # The folder structure is ignored.
                # --------------------------------------------------------
                $DestPath = Get-UniqueDestinationPath `
                    -BaseName $File.BaseName `
                    -Extension $File.Extension `
                    -DestinationDir $FileDestinationDir

                # --------------------------------------------------------
                # Perform the copy or move operation.
                # --------------------------------------------------------
                if ($TransferMode -eq "copy") {
                    Copy-Item -Path $File.FullName -Destination $DestPath -Force
                } elseif ($TransferMode -eq "move") {
                    Move-Item -Path $File.FullName -Destination $DestPath -Force
                }

                # --------------------------------------------------------
                # If Verbose is enabled, output the processed file path
                # and its final resolved destination path.
                # --------------------------------------------------------
                if ($Verbose) {
                        Write-Host "Processed file: $($File.FullName) -> $DestPath"
                }
            }
		}
		
		"all-files-delete-dir" {
            # ------------------------------------------------------------
            # Transfer Type: all-files-delete-dir
            # Purpose :
            #   Recursively copy or move all files in the source directory,
            #   flatten the structure so that all files end up in the 
            #   destination root, and delete leftover empty source 
            #   directories if TransferMode is "move".
            #
            # Description:
            #   - Finds all files recursively in the source directory.
            #   - Flattens the structure: all files go directly to the 
            #     destination root, regardless of their original paths.
            #   - Uses Get-UniqueDestinationPath to ensure that no files 
            #     at the destination are overwritten.
            #   - If TransferMode is "move", deletes all empty leftover 
            #     source directories after files are moved.
            #   - If TransferMode is "copy", the source directories remain.
            #   - Verbose mode outputs detailed info for each step.
            #
            # Example:
            #   If "archive\logs\2022\report.txt" exists and "report.txt"
            #   already exists in the destination root, it will be renamed
            #   to "report_1.txt". After moving, "archive\logs\2022" will 
            #   be deleted if empty.
            #
            # Notes:
            #   Uses Get-ChildItem -Recurse, Copy-Item or Move-Item,
            #   and Remove-Item for directory cleanup.
            #   Directory deletion is wrapped in try/catch for safety.
            # ------------------------------------------------------------
            if ($Verbose) {
                # Output info about what will happen in this block
                Write-Host "Transfer Type: all-files-delete-dir - transferring all files recursively, flattened, with collision protection."
                Write-Host "After transfer, source directories will be deleted only if TransferMode is 'move'."
            }

            # Get all files recursively under the source directory
            $Files = Get-ChildItem -Path $FileSourceDir -File -Recurse

            # Iterate through each file found recursively
            foreach ($File in $Files) {

                # --------------------------------------------------------
                # Get a unique destination path to prevent overwriting.
                # Folder structure is ignored, everything goes to the
                # destination root.
                # --------------------------------------------------------
                $DestPath = Get-UniqueDestinationPath `
                    -BaseName $File.BaseName `
                    -Extension $File.Extension `
                    -DestinationDir $FileDestinationDir

                # --------------------------------------------------------
                # Perform the copy or move operation for each file.
                # --------------------------------------------------------
                if ($TransferMode -eq "copy") {
                    Copy-Item -Path $File.FullName -Destination $DestPath -Force
                } elseif ($TransferMode -eq "move") {
                    Move-Item -Path $File.FullName -Destination $DestPath -Force
                }

                # --------------------------------------------------------
                # If Verbose is enabled, output the processed file path
                # and its final destination path.
                # --------------------------------------------------------
                if ($Verbose) {
                    Write-Host "Processed file: $($File.FullName) -> $DestPath"
                }
            }

            # ------------------------------------------------------------
            # If TransferMode is "move", delete leftover empty directories.
            # ------------------------------------------------------------
            if ($TransferMode -eq "move") {
                if ($Verbose) {
                    Write-Host "Deleting leftover source directories since TransferMode is 'move'."
                }

                # Get all directories under the source recursively
                $Directories = Get-ChildItem -Path $FileSourceDir -Directory -Recurse

                # Try to remove each directory, safely handle failures
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
                # If in copy mode, do not delete source directories
                if ($Verbose) {
                        Write-Host "TransferMode is 'copy'. Source directories will not be deleted."
                }
            }
		}

        # ------------------------------------------------------------
        # Transfer Type: default
        # Purpose :
        #   Handle invalid TransferType values safely.
        #
        # Description:
        #   - If the specified TransferType does not match any valid
        #     case ("all", "files", "all-files", "all-files-delete-dir"),
        #     this default block is executed.
        #   - Outputs a clear error message and stops the script 
        #     with exit code 1 to prevent unintended operations.
        #
        # Notes:
        #   Acts as a fail-safe to catch configuration or user errors.
        # ------------------------------------------------------------
        default {
            # Output the invalid value in the error message
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
    # ------------------------------------------------------------
    # Error Handling: Catch Block
    # Purpose :
    #   Catch any unexpected errors that occur during the transfer
    #   process and exit safely with an error code.
    #
    # Description:
    #   - If any command inside the try block throws an exception,
    #     this catch block is triggered.
    #   - Outputs a clear error message including the $_ automatic 
    #     variable to show the actual error details.
    #   - Exits the script with status code 1 to signal failure.
    #
    # Notes:
    #   This ensures that errors do not silently fail or cause 
    #   partial transfers without notice.
    # ------------------------------------------------------------
    Write-Error "An error occurred during the transfer: $_"
    exit 1
}

# ------------------------------------------------------------
# Final Success Message
# Purpose :
#   Output a clear success message if the transfer process 
#   completed without errors and Verbose mode is enabled.
#
# Description:
#   - Gives user feedback that the entire process ran to the end.
#   - Outputs only if $Verbose is $true.
# ------------------------------------------------------------
if ($Verbose) {
    Write-Host "Transfer completed successfully."
}
