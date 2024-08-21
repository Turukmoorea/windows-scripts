<# ==========================================================================================
.SCRIPTNAME
    monitoring.network_interface.ps1

.VERSION
    1.0

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

    # A string parameter with a limited set of valid values ("fail" or "success").
    # It controls whether the script should be tested for a successful or failed state.
    [ValidateSet("fail", "success")] [string]$proof = "fail",  

    # An array of strings specifying the network types to be considered.
    # Valid values include "none", "public", "private", "domain", and "all".
    # The default is "all", which includes all network types.
    [ValidateSet("none", "public", "private", "domain", "all")] [string[]]$netType = @("all"),  

    # A switch that determines whether multiple networks are allowed.
    # If set to true, the script will check if the system is part of multiple networks.
    [switch]$multipleNetwork = $false,  

    # A string parameter that allows the user to specify one or more network names.
    # If multiple names are provided, they should be separated by commas.
    [string]$netName,

    # A string array that allows the user to specify the link status of the network interfaces.
    # Valid values are "up", "down", and "both", with "up" being the default.
    [ValidateSet("up", "down", "both")] [string[]]$linkStatus = "up"
)

# If 'all' is selected as the network type, set $netType to include all possible network types.
if ($netType -contains "all") {
    $netType = @("none", "public", "private", "domain")
}

# If the $netName parameter is provided, split the names by commas to allow multiple network names.
if ($netName) {
    $netName = $netName -split "\s*,\s*"  # Split on commas, optionally with spaces before or after.
}

# If 'both' is selected for link status, set $linkStatus to include both "up" and "down".
if ($linkStatus -contains "both") {
    $linkStatus = @("up", "down")
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
    $netIfaces = Get-NetAdapter | Select-Object `
        -Property Name,
                   @{Name='NetworkName'; Expression={(Get-NetConnectionProfile -InterfaceAlias $_.Name).Name}},
                   @{Name='NetworkType'; Expression={(Get-NetConnectionProfile -InterfaceAlias $_.Name).NetworkCategory}},
                   @{Name='LinkStatus'; Expression={if ($_.Status -eq 'Up') {'Up'} else {'Down'}}},
                   MacAddress,
                   @{Name='InterfaceDescription'; Expression={$_.InterfaceDescription}},
                   LinkSpeed

    # Count the number of network interfaces retrieved.
    $ifaceCount = $netIfaces.Count

    # Create a custom object to hold the interface information and the count of interfaces.
    $result = [PSCustomObject]@{
        IfaceInfo = $netIfaces
        IfaceCount = $ifaceCount
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
        #[ValidateSet("none", "public", "private", "domain")][string[]]$netType,
        #[ValidateSet("up", "down")][string[]]$LinkStatus,
        #[string[]]$netName
    )

    # Initialize the filtered interfaces with the provided interfaces.
    $filteredIfaces = $iface

    # Filter by network type if provided.
    if ($netType) {
        if ($netType -contains 'none') {
            # If 'none' is selected, include interfaces with no network type or the selected types.
            $filteredIfaces = $filteredIfaces | Where-Object {
                !$_.Networktype -or $netType -contains $_.Networktype
            }
        } else {
            # Otherwise, filter by the selected network types.
            $filteredIfaces = $filteredIfaces | Where-Object {
                $netType -contains $_.Networktype
            }
        }
    }

    # Filter by link status if provided.
    if ($LinkStatus) {
        # Only include interfaces that match the selected link statuses.
        $filteredIfaces = $filteredIfaces | Where-Object {
            $LinkStatus -contains $_.Status
        }
    }

    # Filter by network name if provided.
    if ($netName) {
        # Only include interfaces that match the provided network names.
        $filteredIfaces = $filteredIfaces | Where-Object {
            $netName -contains $_.NetworkName
        }
    }

    # Return the filtered interfaces.
    return $filteredIfaces
}

# Main script execution ====================================================================================
# Retrieve all network interfaces.
$allNetIface = Get-NetIface

# Filter the retrieved network interfaces based on the provided criteria.
$selectedNetIface = Select-NetIface -iface $allNetIface

# Display the filtered network interfaces in a formatted table.
$selectedNetIface.IfaceInfo | Format-Table -AutoSize
