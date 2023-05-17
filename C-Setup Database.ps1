## General
$SQLComputerName = "ARISsql-vm"
$VMUser = "arismaster"
$VMPass = "blahblah123!"

$setupFolder = "C:\SetupTools"

## ----------------------------------------------
Import-Module SQLServer

# Update the SQL Server to enable sa, and enable sql server mixed mode authentication
Write-Output "Running SQL Commands to Enable SA"
$ConnectionString = "Server=$SQLComputerName;Database=master;User Id=$VMUser;Password=$VMPass;TrustServerCertificate=True;Trusted_Connection=True;"
Invoke-Sqlcmd -ConnectionString $ConnectionString -Query "ALTER LOGIN sa ENABLE; ALTER LOGIN [sa] WITH CHECK_EXPIRATION=OFF, CHECK_POLICY=OFF;"  -Verbose
Invoke-Sqlcmd -ConnectionString $ConnectionString -Query "ALTER LOGIN sa WITH PASSWORD = '$VMPass'"  -Verbose

Write-Output "Running SQL Commands to Enable Mixed Mode Authentication"
Invoke-Sqlcmd -ConnectionString $ConnectionString -Query "EXEC xp_instance_regwrite N'HKEY_LOCAL_MACHINE', N'Software\Microsoft\MSSQLServer\MSSQLServer', N'LoginMode', REG_DWORD, 2;" -Verbose

# Send note to user to restart SQL Services
$Shell = New-Object -ComObject "WScript.Shell"
$blank = $Shell.Popup("You must now RDP to the SQL VM ($SQLComputerName) and restart the MSSQL Service (net stop MSSQLServer && net start MSSQLServer). Click OK when service restarted.", 0, "Restart SQL", 0)

# Find the SQLCMD.exe that is added to the envset.bat file ... uses the Install Utils script
$sqlcmd = (Get-ChildItem -Path "C:\Program Files\Microsoft SQL Server\" -Filter "SQLCMD.exe" -File -Recurse).FullName
$sqlcmdpath = Split-Path $sqlcmd

# Find the ARIS mssql File, copy it to a new file that we will edit instead
# Uses the extracted ARIS install files that should have been placed into the SetupTools folder variable
Write-Output "Finding ARIS MSSQL Files"
$lxPath = (Get-ChildItem -Path $setupFolder -Filter 'mssql' -Recurse -Directory -ErrorAction SilentlyContinue).FullName
$envset = (Get-ChildItem -Path $lxPath -Filter "envset.bat" -File -Recurse).Name
$inst = (Get-ChildItem -Path $lxPath -Filter "inst.bat" -File -Recurse).FullName

# Create copies of the original ARIS install files
$filefull = "$lxPath\$envset"
$filefullorig = "$lxPath\$envset" + ".$(get-date -f yyyyMMdd-HHmmss).original"
$newfile = "$filefull.$(get-date -f yyyyMMdd-HHmmss).bat"
Copy-Item -Path $filefull -Destination $newfile

# Get the default file path, used by the INST.BAT file to for new database creation
$qry = Invoke-Sqlcmd -ConnectionString $ConnectionString -Query "SELECT SERVERPROPERTY('instancedefaultdatapath') AS [DefaultFile]"  -Verbose
$sqldatapath = $qry.DefaultFile

# Edit the ENVSET file
Write-Output "Configuring Options in ARIS ENVSET.BAT"
$content = Get-Content -Path $newfile
$newPath = "PATH=%PATH%;"+$sqlcmdpath
$content = $content -replace '@ECHO OFF', "@ECHO OFF`n$newPath"
$content = $content -replace 'SET MSSQL_SAG_MSSQL_SERVER_NAME=localhost', "SET MSSQL_SAG_MSSQL_SERVER_NAME=$SQLComputerName"
$content = $content -replace 'REM SET SQLCMDUSER=sa', 'SET SQLCMDUSER=sa'
$content = $content -replace 'REM SET SQLCMDPASSWORD=manager', "SET SQLCMDPASSWORD=$VMPass"
$content = $content -replace "F:\\msqldata\\ARIS10DB", $sqldatapath
$content | Set-Content -Path $newfile

# Backup Original File & Copy New Over It
Write-Output "Backing Up Original ARIS ENVSET.BAT"
Rename-Item -Path $filefull -NewName $filefullorig -Force
Rename-Item -Path $newfile -NewName $filefull -Force

# Run the INST.bat file (that does all the SQL work)
Write-Output "Running ARIS INST.BAT"
Start-Process -FilePath $inst -WorkingDirectory $lxPath -Wait -NoNewWindow

Write-Output "Finished with ARIS Database Setup (Script C)"

Write-Output "Finding ARIS Setup Files"
$setupPath = (Get-ChildItem -Path $setupFolder -Filter '*Windows setup*' -Recurse -Directory -ErrorAction SilentlyContinue).FullName
$setupcmd = "$setupPath\\ARIS_server\setup.exe"
Start-Process -FilePath $setupcmd -WorkingDirectory $setupPath -ArgumentList "NO_VALIDATION" -Verb RunAs

Write-Output "Note: You may need to restart the App Server before starting ARIS setup."
