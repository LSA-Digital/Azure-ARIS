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

#$DownloadsFolder = [System.Environment]::GetFolderPath("Downloads")
$DownloadsFolder = "$HOME/Downloads"

$RemoteFilePath = "/home/$VMUser/$FileName"
$LocalFilePath = Join-Path -Path $DownloadsFolder -ChildPath $FileName

scp -i $KeyFilePath "${VMUser}@${AppIP}:$RemoteFilePath" "$LocalFilePath"