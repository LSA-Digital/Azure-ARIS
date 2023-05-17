# Azure-ARIS / ARISonAzure
Installation of AIRS on Azure VMs
Scripts and information known good as of 2023-05-14

Welcome to the GitHub repository for ARIS on Azure VM Scripts dedicated to setting up and installing ARIS by SoftwareAG! This collection of scripts aims to streamline and automate the deployment process, allowing you to quickly and effortlessly configure Azure virtual machines (VMs) to host ARIS, a powerful business process analysis and management software.

ARIS, developed by SoftwareAG, offers comprehensive tools and functionalities for modeling, analyzing, and optimizing business processes, enabling organizations to improve efficiency, streamline operations, and drive digital transformation. With these Azure VM scripts, you can easily provision the required infrastructure on Microsoft Azure, automate the installation of ARIS, and customize the environment to suit your specific needs.

**Disclaimer:**
Please note that the scripts and instructions provided in this GitHub repository are based on my personal experience and understanding. Your specific setup, configuration, and requirements may differ, and it is essential to exercise caution and validate the information provided in this repository against the official documentation and guidelines provided by SoftwareAG.

I take no responsibility for any issues, errors, or damages that may occur during the deployment or usage of these scripts. It is your responsibility to thoroughly review and test the scripts, adapt them to your environment, and ensure compatibility with your Azure setup and ARIS deployment.

I strongly recommend referencing the official SoftwareAG documentation and seeking their support or guidance for any specific technical or operational questions related to ARIS. Their documentation provides comprehensive information and best practices to ensure a successful deployment and operation of ARIS.

Please be aware that Azure services and features may change over time, and it is important to stay updated with the latest Azure documentation and announcements to ensure compatibility and adherence to current best practices.

By utilizing the scripts and instructions provided in this repository, you acknowledge and agree to the above disclaimers, and you accept full responsibility for the usage, configuration, and outcomes of your ARIS deployment on Azure.

Remember to test and validate any changes in a non-production environment before implementing them in a production setting.

**Prerequisites:**
- Azure Account (https://azure.microsoft.com/en-us/free/)
- Azure Cloud Shell (https://learn.microsoft.com/en-us/azure/cloud-shell/overview)
- Sure there is more...

**Azure Infrastructure Steps**
1. Start a new Powershell / Cloud Shell Session

2. Edit/Save variable values in all the *.ps1 scripts

3. Run 1-Setup Core.ps1  
This will create the RGs, NSGs, the VNets. 

4. Run 2-Create App Linux VM.ps1  
This will create the Linux box that will be hosting ARIS.

5. Run 3-SQL Windows VM.ps1  
This will create the MS SQL Server VM that will be hosting the ARIS database.

6. Run 4-Create Windows Setup VM.ps1.  
This will create the temporary Windows machine needed to run the ARIS install. You will eventually be able to delete this, but it is required to be on the same network as the App VM for the setup process.

7. Optional: Run 10a-Enable VM Auto Shutdown.ps1  
This will automatically shut down the machines daily at the defined time (used to save $ if running in dev/test).  


**Windows VM Steps**  
These steps are intended to be ran on the Windows Setup VM created above. 

1. RDP to the Windows Setup VM (ARISsetup-vm) using the Public IP address.

2. Start Windows PowerShell  
By default this is the old v5.x version; we will be downloading v7.x in a minute as it has expanded functionality.

3. Run A-Install Utils on Windows.ps1  
This will download the VC Redist, ODBC 17 drivers, MS SLQ Command Line Tools, JDBC Drivers, and PowerShell 7.  
_**When script completes, close PowerShell 5 and open PowerShell 7**_
 
4. Download & extract ARIS install from https://aris.softwareag.com/  
Extract the zip file to C:\SetupTools.

5. Run B-Copy ARIS rpms to App.ps1  
This will expand the home side, install fonts for ARIS, copy the RPMs from the setup and install them, open ports.

6. Run C-Setup Database.ps1  
This will enable mixed mode authentication on the SQL Server, enable the SA user, update the ARIS EVNV.bat file and run the DB installs. At the end, it'll kick off the ARIS setup.exe. Note: The setup.exe is started with the NO_VALIDATION parameter due to a technical issue with the setup (Support Ticket #zzzzzz).    

7. Complete ARIS install:   
- Install ARIS Server on Remote Computer: **ARISapp-vm**
- Select Desired ARIS Products
- Specify External IP - Leave defaults; change later after local testing first
- Change ARIS Agent User Credentials - Leave defaults; change later after local testing first
- Specify Port Number - Leave defaults; change later after local testing first
- Select Desired Required Memory Option - This documentation built with Medium option
- Import License - Leave defaults; change later after local testing first
- Select **Microsoft SQL Database** Management System
- Select JDBC Driver - Locate **C:\SetupTools\sqljdbc_12.2\enu\mssql-jdbc-12.2.0.jre11.jar**
- SQL Database Parameters:
   -   Server: **ARISsql-vm**
   -   Port: **1433**
   -   Database Name: **ARIS10DB**
   -   Application User: **ARIS10**
   -   Password: ***ARIS!1dm9n#**
- Specify Schema Names:
   -   Master: **ARIS_MASTER**
   -   Default: **ARIS_DEFAULT**
-  SQL Connection URL: Leave deaults
-  Specify Mail Server Connection: **Uncheck** Enable Mail Processing (unless you know SMTP settings)
-  Specify Server Connection: Leave defaults
-  Select Start Mode: Start Automatically

8. SSH into the ARISvm (See script 10b-Connect to App Linux VM.ps1)    
Run command: **acc10.sh -h localhost -pwd g3h31m -u Clous ** 
At the prompt: ACC+ localhost> **list**   
All services should be STARTED   

9. Open up the web browser on the Setup VM and connect to http://ARISapp-vm:1080   
If it doesn't connect, you may need to issue a reboot on the ARISapp-vm (then wait 15 min after reboot for services to be STARTED)

**Additional Best Practices**

* Edit the NSG in the Azure Portal - Set Source IPs for SSH/SQL/RDP to your Public IP (whatismyip.com).  
The default NSG created allows access to RDP, SSH, SQL for the entire internet. Restrict this to only needed IPs.

