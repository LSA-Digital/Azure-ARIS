## General
$ResourceGroupName = "ARISa"

## VM Configuration
$VMSize = "Standard_D2s_v3"
$VMName = "ARISsetup-vm"
$VMUser = "arismaster"
$VMPass = "blahblah123!"

## OS Image
$ImagePublisher = "MicrosoftWindowsDesktop"
$ImageOffer = "Windows-10"
$ImageSkus = "win10-21h2-pro-g2"
$ImageVersion = "Latest"

## ----------------------------------------------

$rg = Get-AzureRMResourceGroup -Name $ResourceGroupName
$LocationName = $rg.location
$NetworkName = (Get-AzVirtualNetwork -ResourceGroupName $ResourceGroupName -Name * | Select-Object -Property Name -first 1).Name
$Vnet = Get-AzVirtualNetwork -ResourceGroupName $ResourceGroupName -Name $NetworkName
$NsgName = (Get-AzNetworkSecurityGroup -ResourceGroupName $ResourceGroupName -Name * | Select-Object -Property Name -first 1).Name
$nsg = Get-AzNetworkSecurityGroup -ResourceGroupName $ResourceGroupName -Name $NsgName
$SubnetName = $vnet.Subnets.Name

$NICName = "$VMName-nic"
$IpName = "$VMName-ip"

# Create a public IP address and specify a DNS name
Write-Output "Creating Public IP $IpName"
$PublicIp = New-AzPublicIpAddress `
    -ResourceGroupName $ResourceGroupName `
    -Location $LocationName `
    -AllocationMethod Static `
    -IdleTimeoutInMinutes 4 `
    -Name $IpName
    
# Create a virtual network card and associate with public IP address and NSG
Write-Output "Creating Network Interface $NICName"
$nic = New-AzNetworkInterface `
    -Name $NICName `
    -ResourceGroupName $ResourceGroupName `
    -Location $LocationName `
    -SubnetId ($vnet.Subnets | Where-Object { $_.Name -eq $SubnetName } | Select-Object -ExpandProperty Id) `
    -NetworkSecurityGroupId $nsg.Id `
    -PublicIpAddressId $PublicIp.Id

Write-Output "Creating $VMName VM"

# Define a credential object
$VMSecurePass = ConvertTo-SecureString $VMPass -AsPlainText -Force
$Credential = New-Object System.Management.Automation.PSCredential ($VMUser, $VMSecurePass);

# Create a virtual machine configuration
$VmConfig = New-AzVmConfig `
    -VMName $VMName `
    -VMSize $VMSize
    
$VmConfig = Set-AzVMOperatingSystem `
    -VM $VmConfig `
    -ComputerName $VMName `
    -Credential $Credential `
    -Windows
    
$VmConfig = Set-AzVMSourceImage `
	-VM $VmConfig `
    -PublisherName $ImagePublisher `
    -Offer $ImageOffer `
    -Skus $ImageSkus `
    -Version $ImageVersion
    
$VmConfig = Add-AzVMNetworkInterface `
	-VM $VmConfig `
    -Id $nic.Id

New-AzVM `
    -ResourceGroupName $ResourceGroupName `
    -Location $LocationName -VM $VmConfig

Write-Output "Created VM $VMName"
Write-Output "Finished with $VMName Creation! (Script 4)"

$pubIP = (Get-AzPublicIpAddress -ResourceGroupName $ResourceGroupName | Where-Object {$_.name -like "*$VMName*"}).IpAddress
Write-Output "Connect via RDP to Public IP: $pubIP"