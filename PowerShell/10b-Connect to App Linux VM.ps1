## Connect to Azure
Connect-AzAccount -Environment AzureUSGovernment 

## General
$ResourceGroupName = "ARISa"

## Keyvault
$VaultName = "LSA-kv"
$SecretName = "$ResourceGroupName-ssh"

## VM Configuration
$VMName = "ARISapp-vm"
$VMUser = "arismaster"

## ----------------------------------------------
$NICName = "$VMName-ip"
$AppIP = (Get-AzPublicIpAddress -Name $NICName -ResourceGroupName $ResourceGroupName).IpAddress

$KeyFile = New-TemporaryFile
$secret = Get-AzKeyVaultSecret -VaultName $VaultName -Name $SecretName
$secret.SecretValue | ConvertFrom-SecureString -AsPlainText | Out-File -FilePath $KeyFile.FullName 

ssh -i $KeyFile.FullName $VMUser@$AppIP
