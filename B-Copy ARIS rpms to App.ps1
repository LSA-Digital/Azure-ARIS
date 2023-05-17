## General
$ResourceGroupName = "ARISa"
$AzEnvironment = "AzureUSGovernment"

## Keyvault
$VaultName = "LSA-kv"
$SecretName = "$ResourceGroupName-ssh"

$AppComputerName = "ARISapp-vm"
$VMUser = "arismaster"

## ----------------------------------------------
# First time, make sure Az modules install on Windows machine
Install-Module -Name Az -Repository PSGallery -Force
Install-Module SQLServer -Force

$setupFolder = "C:\SetupTools"

# Get Secure Token
Write-Output "Getting $SecretName from $VaultName"
Connect-AzAccount -UseDeviceAuthentication -Environment $AzEnvironment
$KeyFile = New-TemporaryFile
$secret = Get-AzKeyVaultSecret -VaultName $VaultName -Name $SecretName
$secret.SecretValue | ConvertFrom-SecureString -AsPlainText | Out-File -FilePath $KeyFile.FullName 

# Connect to VM and increase size of /home
Write-Output "SSHing to $VMName VM to extend home"
$sshcommand = ""
$sshcommand | ssh -i $KeyFile.FullName $VMUser@$AppComputerName "sudo lvextend -l +100%FREE /dev/mapper/rootvg-homelv"
$sshcommand | ssh -i $KeyFile.FullName $VMUser@$AppComputerName "sudo xfs_growfs /dev/mapper/rootvg-homelv"
Write-Output "home extended"

# Find the ARIS Linux_RedHat File and all the *.rpm Files
$lxPath = (Get-ChildItem -Path $setupFolder -Filter 'Linux_RedHat' -Recurse -Directory -ErrorAction SilentlyContinue).FullName
$rpmFiles = Get-ChildItem -Path $lxPath -Filter "*.rpm" -File -Recurse

# Send all the *.rpm Files to the App Server
foreach ($file in $rpmFiles) {    
	$FilePathWithQuotes = '"{0}"' -f $file.FullName
    $scpCommand = "scp -i " + $KeyFile.FullName + " " + $FilePathWithQuotes + " " + $VMUser + "@" + $AppComputerName + ":/home/" + $VMUser
    Write-Host $scpCommand
    Invoke-Expression -Command $scpCommand 
}

# Install fonts needed for ARIS
Write-Output "Installing fonts needed for ARIS"
ssh -i $KeyFile.FullName $VMUser@$AppComputerName "sudo yum -y install dejavu-sans-fonts"
ssh -i $KeyFile.FullName $VMUser@$AppComputerName "sudo yum -y install xorg-x11-fonts-Type1"
ssh -i $KeyFile.FullName $VMUser@$AppComputerName "sudo yum -y install nss-softokn-freebl"
ssh -i $KeyFile.FullName $VMUser@$AppComputerName "sudo yum -y install langpacks-en"

# Run each of the ARIS rpm package installers
Write-Output "Running each of the ARIS rpm package installers"
$acc = (Get-ChildItem -Path $lxPath -Filter "aris10-acc-*.rpm" -File -Recurse).Name
$ca = (Get-ChildItem -Path $lxPath -Filter "aris10-cloud-agent-*.rpm" -File -Recurse).Name
$sr = (Get-ChildItem -Path $lxPath -Filter "aris10-scriptrunner-*.rpm" -File -Recurse).Name

$sshcommand = ""
$sshcommand | ssh -i $KeyFile.FullName $VMUser@$AppComputerName "sudo rpm -i $acc"
$sshcommand | ssh -i $KeyFile.FullName $VMUser@$AppComputerName "sudo rpm -i $ca"
$sshcommand | ssh -i $KeyFile.FullName $VMUser@$AppComputerName "sudo rpm -i $sr"

# Ensure that port 14000 is open for the Windows machine to connect
Write-Output "Opening Port 14000/1080/1443 for ARIS Cloud Agent"
$sshcommand | ssh -i $KeyFile.FullName $VMUser@$AppComputerName "sudo firewall-cmd --zone=public --add-port=14000/tcp --permanent"
$sshcommand | ssh -i $KeyFile.FullName $VMUser@$AppComputerName "sudo firewall-cmd --zone=public --add-port=1080/tcp --permanent"
$sshcommand | ssh -i $KeyFile.FullName $VMUser@$AppComputerName "sudo firewall-cmd --zone=public --add-port=1443/tcp --permanent"

Write-Output "Rebooting ARISapp-vm"
$sshcommand | ssh -i $KeyFile.FullName $VMUser@$AppComputerName "sudo reboot"

Write-Output "Finished with ARIS RPMs (Script B)"