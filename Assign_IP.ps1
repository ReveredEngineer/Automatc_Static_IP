# Function to check if an IP is in use
function Test-IP {
    param (
        [string]$IPAddress
    )
    $ping = Test-Connection -ComputerName $IPAddress -Count 1 -Quiet -ErrorAction SilentlyContinue
    return $ping
}

# Get user input for IP range
$StartIP = Read-Host "Enter the starting IP (e.g., 192.168.1.100)"
$EndIP = Read-Host "Enter the ending IP (e.g., 192.168.1.200)"
$SubnetMask = Read-Host "Enter the Subnet Mask (e.g., 255.255.255.0)"
$Gateway = Read-Host "Enter the Default Gateway (e.g., 192.168.1.1)"
$DNS1 = Read-Host "Enter the Primary DNS Server (e.g., 8.8.8.8)"
$DNS2 = Read-Host "Enter the Secondary DNS Server (or leave blank)"

# Convert IPs to integers for iteration
function Convert-IPToInt {
    param ([string]$IPAddress)
    $Octets = $IPAddress -split '\.'
    return [int64]($Octets[0] -shl 24 -bor $Octets[1] -shl 16 -bor $Octets[2] -shl 8 -bor $Octets[3])
}

function Convert-IntToIP {
    param ([int64]$IntIP)
    return "$(($IntIP -shr 24) -band 255).$(($IntIP -shr 16) -band 255).$(($IntIP -shr 8) -band 255).$(($IntIP) -band 255)"
}

$StartInt = Convert-IPToInt $StartIP
$EndInt = Convert-IPToInt $EndIP

# Find an available IP
$AvailableIP = $null
for ($ip = $StartInt; $ip -le $EndInt; $ip++) {
    $TestIP = Convert-IntToIP $ip
    if (-not (Test-IP -IPAddress $TestIP)) {
        $AvailableIP = $TestIP
        break
    }
}

if (-not $AvailableIP) {
    Write-Host "No available IPs found in the given range." -ForegroundColor Red
    exit
}

Write-Host "Available IP found: $AvailableIP" -ForegroundColor Green

# Get network adapter
$Adapter = Get-NetAdapter | Where-Object { $_.Status -eq "Up" }

if (-not $Adapter) {
    Write-Host "No active network adapters found." -ForegroundColor Red
    exit
}

# Assign the IP address
Write-Host "Assigning IP address $AvailableIP to adapter $($Adapter.Name)..." -ForegroundColor Yellow
New-NetIPAddress -InterfaceAlias $Adapter.Name -IPAddress $AvailableIP -PrefixLength (32 - ($SubnetMask -split '\.' | Where-Object {$_ -eq "0"}).Count * 8) -DefaultGateway $Gateway -ErrorAction Stop

# Set DNS servers
Set-DnsClientServerAddress -InterfaceAlias $Adapter.Name -ServerAddresses @($DNS1, $DNS2) -ErrorAction Stop

Write-Host "IP address successfully assigned!" -ForegroundColor Green
Write-Host "New settings:"
Write-Host "IP Address: $AvailableIP"
Write-Host "Subnet Mask: $SubnetMask"
Write-Host "Gateway: $Gateway"
Write-Host "DNS Servers: $DNS1, $DNS2"
