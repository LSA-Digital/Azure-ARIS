# Create Setup Folder
$setupFolder = "C:\SetupTools"
Write-Output "Creating Setup Folder $setupFolder"
New-Item -Path $setupFolder -type directory -Force 

# Download/Install the VC Redist ... Needed for the ODBC Drivers
Write-Output "Downloading VC Redist"
$RedistURL = "https://aka.ms/vs/15/release/vc_redist.x64.exe"
$RedistInstallPath = $setupFolder + "\vc_redist.x64.exe"
Invoke-WebRequest -Uri $RedistURL -OutFile $RedistInstallPath
Start-Process -Wait $RedistInstallPath -ArgumentList "/quiet"
             
# Download/Install the ODBC 17 drivers ... Needed for the MS SQL Command Line Tool    
Write-Output "Downloading ODBC 17"    
$SQLDriversURL = "https://go.microsoft.com/fwlink/?linkid=2223304"
$SQLDriversInstallPath = $setupFolder + "\msodbcsql.msi"
$SQLDriversInstallLog = $setupFolder + "\msodbcsql.log"
$SQLDriversArgs = "/quiet /l "+$SQLDriversInstallLog + " IACCEPTMSODBCSQLLICENSETERMS=YES"
Invoke-WebRequest -Uri $SQLDriversURL -OutFile $SQLDriversInstallPath
Start-Process -Wait $SQLDriversInstallPath -ArgumentList $SQLDriversArgs
              
# Download/Install the MS SQL Command Line Tool ... Needed for the ARIS SQL Setup batch file
Write-Output "Downloading MS SQL Command Line Tools"    
$SQLCmdURL = "https://go.microsoft.com/fwlink/?linkid=2230791" 
$SQLCmdInstallPath = $setupFolder + "\MsSqlCmdLnUtils.msi"
$SQLCmdInstallLog = $setupFolder + "\MsSqlCmdLnUtils.log"
$SQLCmdArgs = "/quiet /l "+$SQLCmdInstallLog + " IACCEPTMSSQLCMDLNUTILSLICENSETERMS=YES"
Invoke-WebRequest -Uri $SQLCmdURL -OutFile $SQLCmdInstallPath
Start-Process -Wait $SQLCmdInstallPath -ArgumentList $SQLCmdArgs
    
# Download/Extract the SQL JDBC Drivers ... Needed for the ARIS Setup executable  
Write-Output "Downloading JDBC Drivers"            
$SQLJDBCURL = "https://go.microsoft.com/fwlink/?linkid=2223050"
$SQLJDBCPath = $setupFolder + "\SQLJDBC.zip"
Invoke-WebRequest -Uri $SQLJDBCURL -OutFile $SQLJDBCPath
Expand-Archive -LiteralPath $SQLJDBCPath -DestinationPath $setupFolder

# Download/Install the Latest PowerShell ... Used for future scripts written against it
Write-Output "Downloading PowerShell 7"    
$PSURL = "https://github.com/PowerShell/PowerShell/releases/download/v7.3.4/PowerShell-7.3.4-win-x64.msi" 
$PSInstallPath = $setupFolder + "\PS.msi"
Invoke-WebRequest -Uri $PSURL -OutFile $PSInstallPath
Start-Process -Wait $PSInstallPath

Write-Output "Finished with Install Utils (Script A)"