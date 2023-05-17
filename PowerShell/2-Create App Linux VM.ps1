## General
$ResourceGroupName = "ARISa"

## Keyvault
$VaultName = "LSA-kv"
$SecretName = "$ResourceGroupName-ssh"

## VM Configuration
$VMSize = "Standard_E2ds_v4"
$VMName = "ARISapp-vm"
$VMUser = "arismaster"

## OS Image
$ImagePublisher = "RedHat"
$ImageOffer = "RHEL"
$ImageSkus = "9-lvm-gen2"
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
    -PublicIpAddressId $PublicIp.Id `
    -NetworkSecurityGroupId $nsg.Id

# Define a credential object
Write-Output "Creating Secret Key $SecretName and Storing to $VaultName"
$SecurePassword = ConvertTo-SecureString ' ' -AsPlainText -Force
$Credential = New-Object System.Management.Automation.PSCredential ($VMUser, $SecurePassword)
$KeyFile = New-TemporaryFile
$secret = Get-AzKeyVaultSecret -VaultName $VaultName -Name $SecretName
$secret.SecretValue | ConvertFrom-SecureString -AsPlainText | Out-File -FilePath $KeyFile.FullName 

Write-Output "Creating $VMName VM"
# Create a virtual machine configuration
$VmConfig = New-AzVmConfig `
    -VMName $VMName `
    -VMSize $VMSize | `
    Set-AzVMOperatingSystem `
    -Linux `
    -ComputerName $VMName `
    -Credential $Credential `
    -DisablePasswordAuthentication
     
$VmConfig = Set-AzVMSourceImage `
	-VM $VmConfig `
    -PublisherName $ImagePublisher `
    -Offer $ImageOffer `
    -Skus $ImageSkus `
    -Version $ImageVersion
    
$VmConfig = Add-AzVMNetworkInterface `
	-VM $VmConfig `
    -Id $nic.Id
    
$VmConfig = Add-AzVMSshPublicKey `
    -VM $VmConfig `
    -KeyData (ssh-keygen -e -f $KeyFile -q | Out-String) `
    -Path "/home/$VmUser/.ssh/authorized_keys"

New-AzVM `
    -ResourceGroupName $ResourceGroupName `
    -Location $LocationName -VM $VmConfig

Write-Output "Created $VMName VM"
Write-Output "Finished with $VMName Creation! (Script 2)"