## General
$ResourceGroupName = "ARISa"
$LocationName = "usgovarizona"

## Keyvault
$VaultName = "LSA-kv" # Must create a Key vault resource in Azure first
$SecretName = "$ResourceGroupName-ssh"

## Networking
$NetworkName = "ARISnet"
$SubnetName = "ARISSubnet"
$SubnetAddressPrefix = "10.0.0.0/24"
$VnetAddressPrefix = "10.0.0.0/16"
$NsgName = "ARISnsg"

## ----------------------------------------------

function Read-Selection {
    param (
        [Parameter(Mandatory = $false)]
        [string]$Title = 'Options',
        [Parameter(Mandatory = $true)]
        [object[]]$Options,
        [Parameter(Mandatory = $false)]
        [object[]]$VisibleProperties = $null,
        [Parameter(Mandatory = $false)]
        [boolean]$Index = $false
    )

    #Clear-Host
    Write-Host "================ $Title ================"
    if ($VisibleProperties) {
        $FormattedOptions = @()

        for ($i = 0; $i -lt $Options.Count; $i++) {
            $option = $Options[$i] 
            
            $obj = [ordered]@{"Index" = $i }
            foreach ($prop in $VisibleProperties) { $obj[$prop] = $option.$prop }
            $FormattedOptions += [pscustomobject]$obj 
        }
        
        $FormattedOptions | Format-Table | Out-Host
    }
    else {
        for ($i = 0; $i -lt $Options.Count; $i++) {
            $option = $Options[$i] 
            Out-Host "$i : $option"
        }
    }

    [int]$answer = Read-Host -Prompt "Please make a selection: "

    if ($Index) { 
        return $answer 
    }
    else { 
        return $Options[$answer] 
    }
}

$AvailableContexts = Get-Azcontext -ListAvailable 

$Context = Read-Selection `
    -Title 'Choose subscription' `
    -Options $AvailableContexts `
    -VisibleProperties @("Name", "Account")

Set-AzContext -Context $Context | Out-Null

$ResourceGroupExists = $null -ne (Get-AzResourceGroup | Where-Object -Property ResourceGroupName -eq $ResourceGroupName)

if(-not $ResourceGroupExists) {
    New-AzResourceGroup `
        -Name $ResourceGroupName `
        -Location $LocationName
}

Write-Output "Creating keys"

$KeyFile = New-TemporaryFile
$KeyFile.Delete() # Avoids ssh-keygen prompting to overwrite

ssh-keygen -t rsa -f $KeyFile.FullName -q 

$PrivateKeySecure = Get-Content $KeyFile.FullName | Out-String | `
    ConvertTo-SecureString -AsPlainText -Force

Set-AzKeyVaultSecret `
    -VaultName $vaultName `
    -Name $SecretName `
    -SecretValue $PrivateKeySecure


Write-Output "Creating Network Components"

## VM Networking
$SubnetAddressPrefix = "10.0.0.0/24"
$VnetAddressPrefix = "10.0.0.0/16"

# Create a subnet configuration
$SubnetConfig = New-AzVirtualNetworkSubnetConfig `
    -Name $SubnetName `
    -AddressPrefix $SubnetAddressPrefix

# Create a virtual network
$Vnet = New-AzVirtualNetwork `
    -ResourceGroupName $ResourceGroupName `
    -Location $LocationName `
    -Name $NetworkName `
    -AddressPrefix $VnetAddressPrefix `
    -Subnet $subnetConfig

# Create an inbound network security group rule for port 22
$nsgRuleSSH = New-AzNetworkSecurityRuleConfig `
    -Name "SSH"  `
    -Protocol "Tcp" `
    -Direction "Inbound" `
    -Priority 1000 `
    -SourceAddressPrefix * `
    -SourcePortRange * `
    -DestinationAddressPrefix * `
    -DestinationPortRange 22 `
    -Access "Allow"
    
# Create an inbound network security group rule for port 3389
$nsgRuleRDP = New-AzNetworkSecurityRuleConfig `
    -Name "RDP"  `
    -Protocol "Tcp" `
    -Direction "Inbound" `
    -Priority 1001 `
    -SourceAddressPrefix * `
    -SourcePortRange * `
    -DestinationAddressPrefix * `
    -DestinationPortRange 3389 `
    -Access "Allow" 
    
# Create an inbound network security group rule for port 1080
$nsgRuleHTTP = New-AzNetworkSecurityRuleConfig `
    -Name "ARIShttp"  `
    -Protocol "Tcp" `
    -Direction "Inbound" `
    -Priority 1002 `
    -SourceAddressPrefix * `
    -SourcePortRange * `
    -DestinationAddressPrefix * `
    -DestinationPortRange 1080 `
    -Access "Allow"     
    
# Create an inbound network security group rule for port 1443
$nsgRuleHTTPS = New-AzNetworkSecurityRuleConfig `
    -Name "ARIShttpS"  `
    -Protocol "Tcp" `
    -Direction "Inbound" `
    -Priority 1003 `
    -SourceAddressPrefix * `
    -SourcePortRange * `
    -DestinationAddressPrefix * `
    -DestinationPortRange 1443 `
    -Access "Allow"     
    
<# # Create an inbound network security group rule for port 1443
$nsgRuleSQL = New-AzNetworkSecurityRuleConfig `
    -Name "SQL"  `
    -Protocol "Tcp" `
    -Direction "Inbound" `
    -Priority 1004 `
    -SourceAddressPrefix * `
    -SourcePortRange * `
    -DestinationAddressPrefix * `
    -DestinationPortRange 1433 `
    -Access "Allow"    #>
    
 # Create an rule for anything to talk locally
$nsgRuleLocal = New-AzNetworkSecurityRuleConfig `
-Name "AllLocal"  `
-Protocol * `
-Direction "Inbound" `
-Priority 1005 `
-SourceAddressPrefix "10.0.0.0/24" `
-SourcePortRange * `
-DestinationAddressPrefix * `
-DestinationPortRange "0-65535" `
-Access "Allow"     

# Create a network security group
$nsg = New-AzNetworkSecurityGroup `
    -ResourceGroupName $ResourceGroupName `
    -Location $LocationName `
    -Name $NsgName `
    -SecurityRules $nsgRuleSSH, $nsgRuleRDP, $nsgRuleHTTP, $nsgRuleHTTPS, $nsgRuleLocal


Write-Output "Completed Core Setup (Script 1)"