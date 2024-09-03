<# ==========================================================================================
.SCRIPTNAME
    monitoring.network_interface.ps1

.VERSION
    1.0.1

.AUTHOR
    Turukmoorea (github.com/turukmoorea)

.DESCRIPTION
    This script is used to check the network interfaces on a Windows system. It gathers information about the available network interfaces, including their names, network types, link status (whether the interface is "up" or "down"), MAC address, and link speed.

    The script offers several parameters for filtering network interfaces:
    - It can filter by specific network types (e.g., "public", "private", "domain", etc.).
    - It allows filtering interfaces based on their link status.
    - It enables filtering by specific network names.
    
    Depending on the script configuration, network interfaces are filtered according to the specified parameters, and the filtered results are displayed in a table. Additionally, the script displays a help page when the corresponding parameter is provided and includes exit codes to better understand the script's behavior.
  
#>

# Parameter definition ============================================================================================
param (
    # A switch to trigger the display of the help page. Alias "h" allows users to call the help with -h.
    [Alias("h")] [switch]$help,  

    [switch]$prompt = $false,
    [switch]$debug = $false,
    [switch]$monitoring = $false,
    
    # A string parameter with a limited set of valid values ("fail" or "success").
    # It controls whether the script should be tested for a successful or failed state.
    [ValidateSet("fail", "success")] [string]$proof = "fail",  

    # An array of strings specifying the network types to be considered.
    # Valid values include "none", "public", "private", "domain", and "all".
    # The default is "all", which includes all network types.
    [ValidateSet("none", "public", "private", "domainauthenticated", "all")] [string[]]$netType = @("all"),  

    # A switch that determines whether multiple networks are allowed.
    # If set to true, the script will check if the system is part of multiple networks.
    [switch]$multipleNetwork = $false,  

    # A string parameter that allows the user to specify one or more network names.
    # If multiple names are provided, they should be separated by commas.
    [string]$netName,

    # A string array that allows the user to specify the link status of the network interfaces.
    # Valid values are "up", "down", and "both", with "up" being the default.
    [ValidateSet("Up", "Down", "Both")] [string[]]$linkStatus = "up"
)

# If 'all' is selected as the network type, set $netType to include all possible network types.
if ($netType -contains "all") {
    $netType = @("None", "Public", "Private", "DomainAuthenticated")
}

# If the $netName parameter is provided, split the names by commas to allow multiple network names.
if ($netName) {
    $netName = $netName -split "\s*,\s*"  # Split on commas, optionally with spaces before or after.
}

# If 'both' is selected for link status, set $linkStatus to include both "up" and "down".
if ($linkStatus -contains "both") {
    $linkStatus = @("Up", "Down")
}

if ($debug) {
    Write-Host "=== Start Initial Variables ========================================================================="
    Write-Host "DEBUG: help = $help"
    Write-Host "DEBUG: prompt = $prompt"
    Write-Host "DEBUG: debug = $debug"
    Write-Host "DEBUG: monitoring = $monitoring"
    Write-Host "DEBUG: netType = $netType"
    Write-Host "DEBUG: multipleNetwork = $multipleNetwork"
    Write-Host "DEBUG: netName = $netName"
    Write-Host "DEBUG: linkStatus = $linkStatus"
    Write-Host "=== End Initial Variables ==========================================================================="
}

# Help page function =========================================================================================
# This function displays the help page when the -help or -h switch is used.
function Show-Helppage {
    Write-Host ""
    Write-Host "#Helppage =========================================================================================="
    Write-Host "Usage: <scriptname> [parameters]"
    
    $table = @()
    
    # Define the parameters and descriptions to be displayed on the help page.
    $table += [PSCustomObject]@{Parameter = "-help, -h   "; Options = ""; Default = ""; Description = "Display this help page." }
    $table += [PSCustomObject]@{Parameter = "-proof <option>   "; Options = "fail, success   "; Default = "fail"; Description = "Should be tested for success or failure." }
    $table += [PSCustomObject]@{Parameter = "-multipleNetwork   "; Options = ""; Default = ''; Description = "Use multiple networks if the device is part of multiple networks." }
    $table += [PSCustomObject]@{Parameter = "-netType <option>[, option]   "; Options = "none, private, public, domain, all   "; Default = "all   "; Description = "Controls which network types are allowed." }
    $table += [PSCustomObject]@{Parameter = "-netName <string>   "; Options = ""; Default = ""; Description = "Checks whether this or these networks are available. If there are multiple values, separate the values in the string with commas." }
    $table += [PSCustomObject]@{Parameter = "-linkStatus <option>[, option]   "; Options = "up, down, both"; Default = "up"; Description = "Checks whether the interface is up or down." }
    
    # Display the table with the parameters and their descriptions in a formatted table.
    $table | Format-Table -AutoSize

    Write-Host "#Example ==========================================================================================="
    Write-Host '.\monitoring.network_interface.ps1 -proof success -multipleNetwork -netType public, private -netName "if.internal" -linkStatus Down'
}

# Exit code function =========================================================================================
# This function displays exit codes and their meanings.
function Show-AllExitCode {
    Write-Host ""
    Write-Host "#All Exit-Codes ===================================================================================="
    $table = @()
    
    # Define the exit codes and their corresponding meanings.
    $table += [PSCustomObject]@{Code = "0"; Row = ""; Reason = "successful or desired exit" }
    
    # Display the exit codes in a formatted table.
    $table | Format-Table -AutoSize
    Write-Host ""
}

# Check if the help parameter is provided.
# If it is, display the help page, show the exit codes, and exit the script with code 100.
if ($help) {
    Show-Helppage
    Show-AllExitCode
    exit 0
}

# Functions for network interface management ================================================================

# Function to get network interfaces ======================================================================
# This function retrieves network interfaces using the Get-NetAdapter cmdlet.
# It collects information such as the interface name, network name, network type, link status, MAC address, interface description, and link speed.
function Get-NetIface {
    if ($debug) { 
        Write-Host "=== Start function Get-NetIface ===================================================================="
    }

    $netIfaces = Get-NetAdapter | Select-Object `
        -Property Name,
                   @{Name='NetworkName'; Expression={(Get-NetConnectionProfile -InterfaceAlias $_.Name).Name}},
                   @{Name='NetworkType'; Expression={(Get-NetConnectionProfile -InterfaceAlias $_.Name).NetworkCategory}},
                   @{Name='LinkStatus'; Expression={if ($_.Status -eq 'Up') {'Up'} else {'Down'}}},
                   MacAddress,
                   @{Name='InterfaceDescription'; Expression={$_.InterfaceDescription}},
                   LinkSpeed

    # Debug: Ausgabe der abgerufenen Daten
    if ($debug) {
        $netIfaces | ForEach-Object {
            Write-Host "DEBUG: Interface = $($_.Name),NetworkName = $($_.NetworkName), NetworkType = $($_.NetworkType), LinkStatus = $($_.LinkStatus)"
        }
    }

    # Count the number of network interfaces retrieved.
    $ifaceCount = $netIfaces.Count

    # Create a custom object to hold the interface information and the count of interfaces.
    $result = [PSCustomObject]@{
        IfaceInfo = $netIfaces
        IfaceCount = $ifaceCount
    }

    if ($debug) { 
        Write-Host "=== End function Get-NetIface ======================================================================"
    }

    # Return the custom object containing the interface information.
    return $result
}


# Function to select network interfaces ===================================================================
# This function filters the network interfaces based on the criteria provided by the user.
# It filters by network type, link status, and network name.
function Select-NetIface {
    param (
        [Parameter(Mandatory=$true)][psobject[]]$iface  # The network interfaces to filter.
    )

    if ($debug) { 
        Write-Host "=== Start function Select-NetIface ================================================================="
    }
    
    # Initialize an empty array for filtered interfaces
    $filteredIfaces = @()

    # Iterate over each interface in the provided array
    foreach ($interface in $iface) {
        # Debug output to show the current interface being processed
        if ($debug) { 
            Write-Host "DEBUG: Processing interface = $($interface.Name) (function Select-NetIface)"
            Write-Host "DEBUG: NetworkType = $($interface.Networktype), LinkStatus = $($interface.LinkStatus), NetworkName = $($interface.NetworkName) (function Select-NetIface)"
        }

        # Filter by network type if provided
        $includeInterface = $false  # Initialize a flag to determine if the interface should be included

        if ($debug) { 
            Write-Host "===== Start netType filtering ======================================================================"
        }

        if ($netType) {
            if ($debug) { Write-Host "DEBUG: netType = $netType (function Select-NetIface)" }

            # Check for 'none' condition (i.e., interfaces with no NetworkType)
            if ($netType -contains 'none') {
                if (-not [string]::IsNullOrEmpty($interface.Networktype) -eq $false) {
                    $includeInterface = $true
                    if ($debug) { Write-Host "DEBUG: Interface '$($interface.Name)' has no NetworkType and 'none' is included." }
                }
            }

            # Check if the interface's NetworkType matches any of the specified netTypes
            if ($netType -contains $interface.Networktype) {
                $includeInterface = $true
                if ($debug) { Write-Host "DEBUG: Interface '$($interface.Name)' matches NetworkType '$($interface.Networktype)'." }
            }
        } else {
            # If no netType filtering is specified, set the flag to true
            $includeInterface = $true
        }

        if ($debug) { 
            Write-Host "===== End netType filtering ========================================================================"
            Write-Host "===== Start LinkStatus filtering ==================================================================="
        }
        
        # Filter by link status if provided
        if ($LinkStatus) {
            if ($debug) { Write-Host "DEBUG: LinkStatus = $LinkStatus (function Select-NetIface)" }
            if ($LinkStatus -contains $interface.LinkStatus) {
                if ($includeInterface) {  # Only include if it already passed the netType filter
                    if ($debug) { Write-Host "DEBUG: Interface '$($interface.Name)' matches LinkStatus '$($interface.LinkStatus)'." }
                } else {
                    $includeInterface = $false
                }
            } else {
                $includeInterface = $false
                if ($debug) { Write-Host "DEBUG: Interface '$($interface.Name)' does not match LinkStatus '$($interface.LinkStatus)'." }
            }
        }

        if ($debug) { 
            Write-Host "===== End LinkStatus filtering ====================================================================="
            Write-Host "===== Start netName filtering ======================================================================"
        }

        # Filter by network name if provided
        if ($netName) {
            if ($debug) { Write-Host "DEBUG: netName = $netName (function Select-NetIface)" }
            if ($netName -contains $interface.NetworkName) {
                if ($includeInterface) {  # Only include if it already passed the previous filters
                    if ($debug) { Write-Host "DEBUG: Interface '$($interface.Name)' matches NetworkName '$($interface.NetworkName)'." }
                } else {
                    $includeInterface = $false
                }
            } else {
                $includeInterface = $false
                if ($debug) { Write-Host "DEBUG: Interface '$($interface.Name)' does not match any netName filter criteria." }
            }
        }

        if ($debug) { 
            Write-Host "===== End netName filtering ========================================================================"
        }

        # If the interface should be included based on the criteria, add it to the filtered list
        if ($includeInterface) {
            $filteredIfaces += $interface
        }
    }

    if ($debug) { 
        Write-Host "=== End function Select-NetIface ==================================================================="
    }

    # Return the filtered interfaces
    return $filteredIfaces
}

function Get-Proof {
    param (
        [psobject[]]$iface  # The network interfaces to filter.
    )
    
    if ($debug) { 
        Write-Host "=== Start function Get-Proof ======================================================================="
    }

    # Count the number of network interfaces provided
    $ifaceCount = $iface.Count

    # Extract the NetworkName property from each interface and filter out empty names
    $networkNames = $iface | Select-Object -ExpandProperty NetworkName
    $nonEmptyNames = $networkNames | Where-Object { $_ -ne "" }

    # Determine whether the network names are considered unique
    # If only one network name is present, it is considered unique regardless of the multipleNetwork parameter
    if ($nonEmptyNames.Count -le 1) {
        # Only one unique non-empty network name exists
        $allNetworksUnique = $true
    } else {
        # If more than one network name is present, check uniqueness based on the multipleNetwork parameter
        if ($multipleNetwork) {
            # If multipleNetwork is true, check if there are multiple unique non-empty network names
            $allNetworksUnique = ($nonEmptyNames | Select-Object -Unique).Count -gt 1
        } else {
            # If multipleNetwork is false, check if all non-empty network names are identical
            $allNetworksUnique = ($nonEmptyNames | Select-Object -Unique).Count -le 1
        }
    }

    # Debug output to show the network names and the uniqueness determination
    if ($debug) {
        Write-Host "DEBUG: NetworkNames = $networkNames"
        Write-Host "DEBUG: NonEmptyNames = $nonEmptyNames"
        Write-Host "DEBUG: allNetworksUnique = $allNetworksUnique"
    }

    # Determine the exit code based on the value of the proof parameter
    if ($proof -eq "success") {
        # If proof is "success", exit with 0 (success) if there is at least one interface and network names are unique
        if ($ifaceCount -ge 1 -and $allNetworksUnique) {
            exit 0
        } else {
            # Otherwise, exit with 1 (failure)
            exit 1
        }
    } elseif ($proof -eq "fail") {
        # If proof is "fail", exit with 1 (failure) if there is at least one interface and network names are unique
        if ($ifaceCount -ge 1 -and $allNetworksUnique) {
            exit 1
        } else {
            # Otherwise, exit with 0 (success)
            exit 0
        }
    } else {
        # If proof has an unknown value, print an error and exit with 1 (failure)
        Write-Host "Unknown value for 'proof': $proof"
        exit 1
    }
    
    # End of function debug output
    if ($debug) { 
        Write-Host "=== End function Get-Proof ========================================================================="
    }
}


# Main script execution ====================================================================================
# Retrieve all network interfaces.
if ($prompt) { 
    Write-Host "Fetching all network interfaces..."
}
$allNetIface = Get-NetIface

# Check what was retrieved
if ($debug) {
    Write-Host "DEBUG: Retrieved interfaces count: $($allNetIface.IfaceCount)"
}

# Filter the retrieved network interfaces based on the provided criteria.
if ($prompt) { 
    Write-Host "Filtering network interfaces..."
}
$selectedNetIface = Select-NetIface -iface $allNetIface.IfaceInfo 

# Check the result of the filtering
if ($debug) {
    Write-Host "DEBUG: Filtered interfaces count: $($selectedNetIface.Count)"
}

# Display the filtered network interfaces in a formatted table.
if ($debug) { 
    Write-Host "=== Final Output ==================================================================================="
}
if ($prompt) { 
    Write-Host "Displaying the filtered network interfaces:"
}
$selectedNetIface | Format-Table -AutoSize

Get-Proof -iface $selectedNetIface
