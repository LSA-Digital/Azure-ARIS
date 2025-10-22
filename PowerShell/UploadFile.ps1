param (
    [string]$FileName  # Pass the filename as a parameter when running the script
)

## Check if already connected to Azure
$CurrentContext = Get-AzContext
if (-not $CurrentContext -or $CurrentContext.Environment.Name -ne "AzureUSGovernment") {
    Connect-AzAccount -Environment AzureUSGovernment
}

## General
$ResourceGroupName = "ARISa"

## VM Configuration
$VMName = "ARISapp-vm"
$VMUser = "arismaster"
$KeyFilePath = "ARISapp-vm.key"

## ----------------------------------------------
$NICName = "$VMName-ip"
$AppIP = (Get-AzPublicIpAddress -Name $NICName -ResourceGroupName $ResourceGroupName).IpAddress

$UploadsFolder = "$HOME/Downloads"  # Adjust if file is in a different folder
$LocalFilePath = Join-Path -Path $UploadsFolder -ChildPath $FileName
$RemoteFilePath = "/home/$VMUser/$FileName"

## Upload file to remote server
scp -i $KeyFilePath "$LocalFilePath" "${VMUser}@${AppIP}:$RemoteFilePath"
