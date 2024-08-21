<#header ==========================================================================================
.SCRIPTNAME
    monitoring.network_interface.ps1

.VERSION
    1.0

.AUTHOR
    Turukmoorea (github.com/turukmoorea)

.DESCRIPTION
    
#>

#param ============================================================================================
param (
    [Alias("h")] [switch]$help,  # Switch to trigger the help page, with -h as alias

    [ValidateSet("fail", "pass")] [string]$proof = "fail",
    [ValidateSet("unique", "multiple")] [string]$iface = "unique",
    [string]$nettype
)


#Helppage =========================================================================================
# Function to display the help page.
function Show-Helppage {
    Write-Host ""
    Write-Host "#Helppage =========================================================================================="
    Write-Host "Usage: <scriptname> [parameters]"
    
    $table = @()
    
    # Define the parameters and descriptions to be displayed in the help page.
    $table += [PSCustomObject]@{Parameter = "-help, -h   "; Options = ""; Default = ""; Description = "Display this help page." }
    
    # Display the table in a formatted way.
    $table | Format-Table -AutoSize
}

# Function to display exit codes and their meanings.
function Show-AllExitCode {
    Write-Host ""
    Write-Host "#All Exit-Codes ===================================================================================="
    $table = @()
    
    # Add rows to the exit code table.
    $table += [PSCustomObject]@{Code = "0"; Row = ""; Reason = "successful or desired exit" }
    $table += [PSCustomObject]@{Code = "100"; Row = "62"; Reason = "Help page was opened and script ended" }
    $table += [PSCustomObject]@{Code = "101"; Row = "69"; Reason = "No network type was specified." }
    
    # Display the table in a formatted way.
    $table | Format-Table -AutoSize
    Write-Host ""
}

# Check if the help parameter or its alias is provided, and if so, display the help page and exit.
if ($help) {
    Show-Helppage
    Show-AllExitCode
    exit 100
}

#parameter processing =============================================================================

<# if (-not $PSBoundParameters.ContainsKey('nettype') -or [string]::IsNullOrWhiteSpace($nettype)) {
    Write-Host "No network type was specified or the value was empty. Use the parameter -nettype <string>."
    exit 101
}
#>

#Functions ========================================================================================

#Get-NetIface -------------------------------------------------------------------------------------
function Get-NetIface {
    $netIfaces = Get-NetAdapter | Where-Object { $_.Status -eq 'Up' } | Select-Object `
        -Property Name,
                   @{Name='Networktype'; Expression={(Get-NetConnectionProfile -InterfaceAlias $_.Name).NetworkCategory}},
                   MacAddress,
                   @{Name='InterfaceDescription'; Expression={$_.InterfaceDescription}},
                   LinkSpeed

    $ifaceCount = $netIfaces.Count

    # Ein Objekt erstellen, das sowohl die Adapterinformationen als auch die Anzahl enthält
    $result = [PSCustomObject]@{
        IfaceInfo = $netIfaces
        IfaceCount = $ifaceCount
    }

    return $result
}


$result = Get-NetIface
Write-Host "Anzahl der aktiven Netzwerkadapter: $($result.IfaceCount)"
$result.IfaceInfo | Format-Table -AutoSize

