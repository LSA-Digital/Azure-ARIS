## General
$ResourceGroupName = "ARISa"

## VM Configuration
$VMSize = "Standard_D2s_v3"
$VMName = "ARISsql-vm"
$VMUser = "arismaster"
$VMPass = "blahblah123!"

## OS Image
$ImagePublisher = "MicrosoftSQLServer"
$ImageOffer = "sql2019-ws2019"
$ImageSkus = "sqldev-gen2"
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

# Create a virtual network card and associate with public IP address and NSG
Write-Output "Creating Network Interface $NICName"
$nic = New-AzNetworkInterface `
    -Name $NICName `
    -ResourceGroupName $ResourceGroupName `
    -Location $LocationName `
    -SubnetId ($vnet.Subnets | Where-Object { $_.Name -eq $SubnetName } | Select-Object -ExpandProperty Id) `
    -NetworkSecurityGroupId $nsg.Id

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

Write-Output "Waiting 1 minute for server to launch..."
Start-Sleep -Seconds 60

Write-Output "Adding SQL IaaS Agent Extension"
# Add the SQL IaaS Agent Extension, and choose the license type
# Not sure if this was actually needed anymore....
New-AzSqlVM -ResourceGroupName $ResourceGroupName -Name $VMName -Location $LocationName -LicenseType PAYG

# Config Machine to allow SQL on local network
# Not sure if this was actually needed anymore....
Write-Output "Enabling PS Remoting"
Enable-AzVMPSRemoting -Name $VMName -ResourceGroupName $ResourceGroupName -Protocol https -OsType Windows

Write-Output "Disabling Firewall for PRIVATE Network"
Set-AzVMRunCommand -ResourceGroupName $ResourceGroupName -VMName $VMName -Location $LocationName -RunCommandName "AllowSQL" –SourceScript { 
	Set-NetFirewallProfile -Profile Private -Enabled False
	New-NetFirewallRule -DisplayName "Allow SQL" -Direction Inbound -LocalPort 1433 -Protocol TCP -Action Allow
}

Write-Output "Finished with $VMName Creation! (Script 3)"
