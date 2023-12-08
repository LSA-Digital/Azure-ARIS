## Check if already connected to Azure
$CurrentContext = Get-AzContext
if (-not $CurrentContext -or $CurrentContext.Environment.Name -ne "AzureUSGovernment") {
    Connect-AzAccount -Environment AzureUSGovernment
}

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

$KeyFile = "ARISapp-vm.key"
$secret = Get-AzKeyVaultSecret -VaultName $VaultName -Name $SecretName
$secret.SecretValue | ConvertFrom-SecureString -AsPlainText | Out-File -FilePath $KeyFile 

# Set file permissions to 600
chmod 600 $KeyFile

#Connect Finally
ssh -i $KeyFile $VMUser@$AppIP
