## General
$ResourceGroupName = "ARISa"
$AdminEmail = "keith.mangold@leanscaledarchitects.com"
$AppComputerName = "ARISapp-vm"
$SetupComputerName = "ARISsetup-vm"
$SQLComputerName = "ARISsql-vm"
$TimeZone = "Eastern Standard Time"
$Time = 1800

## ----------------------------------------------

Function Enable-AzureVMAutoShutdown {
  <#
  .SYNOPSIS
  Enable Auto-Shutdown on Azure Virtual Machines
  
  .DESCRIPTION
  This cmdlet will enable Azure Dev Test Labs Auto-Shutdown on Azure Virtual Machine or Machines.
    
  .PARAMETER rgName
  The Resource Group the virtual machine belongs to.

  .PARAMETER vmName
  The name of the virtual machine you want to add auto-shutdown too.

  .PARAMETER time
  Time to shutdown virtual machine, in military time. Default: 1600.

  .PARAMETER timezone
  Timezone for the the time. Default: Pacific Standard Time.

  .PARAMETER emailfornotification
  Email address to be notified before auto-shutdown, this is the default notification option is not is selected. Azure user ID will be used if no email is specified.

  .PARAMETER WebHookNoticationURI
  Incoming WebHook to send notification to before auto-shutdown.

  .NOTES
  Author : Hannel Hazeley - hhazeley@outlook.com

  .LINK
  https://github.com/hhazeley/HannelsToolBox/blob/master/Functions/Enable-AzureVMAutoShutdown.ps1

  .EXAMPLE
  Enable-AzureVMAutoShutdown -rgName DDemo -vmName DDemo-VM5
  
  Enable auto shutdown for 4pm PST with email notification to user that is logged in to Azure environment

  .EXAMPLE
  Enable-AzureVMAutoShutdown -rgName DDemo -vmName DDemo-VM5 -time 1800 -timezone 'Eastern Standard Time' -emailfornotification hhazeley@outlook.com
  
  Enable auto shutdown for 6pm EST with email notification to hhazeley@outloook.com

  .EXAMPLE
  $webhook = "https://outlook.office.com/webhook/b258463b-9b14-4659-8a66-5cbe5fd5...............
  Enable-AzureVMAutoShutdown -rgName DDemo -vmName DDemo-VM5 -time 1900 -timezone 'Eastern Standard Time' -WebHookNoticationURI $webhook
  
  Enable auto shutdown for 7pm EST with webhook notification
  #>
  [cmdletbinding(DefaultParameterSetName = "Local")]
  Param (
    [Parameter(ParameterSetName = "VM", Mandatory = $true)]
    [Parameter(ParameterSetName = "Email")]
    [Parameter(ParameterSetName = "Webhook")]
    $rgName,
    [Parameter(ParameterSetName = "VM")]
    [Parameter(ParameterSetName = "Email")]
    [Parameter(ParameterSetName = "Webhook")]
    $vmName,
    [ValidatePattern("[0-9][0-9][0-9][0-9]")]
    [ValidateRange(0000, 2359)]
    $time = "1600",
    [ValidateSet("Pacific Standard Time", "US Mountain Standard Time", "Mountain Standard Time", "Central Standard Time", "Canada Central Standard Time", "Eastern Standard Time", "US Eastern Standard Time", "Atlantic Standard Time", "Venezuela Standard Time", "Central Brazilian Standard Time")]
    $timezone = "Pacific Standard Time",
    [Parameter(ParameterSetName = "Email", Mandatory = $true)]
    [ValidatePattern("^[a-zA-Z0-9.!£#$%&'^_`{}~-]+@[a-zA-Z0-9-]+(?:\.[a-zA-Z0-9-]+)*$")]
    $emailfornotification,
    [Parameter(ParameterSetName = "Webhook", Mandatory = $true)]
    $WebHookNoticationURI
  )

  if ($WebHookNoticationURI -ne $null) {
    $webhookvalidation = Invoke-WebRequest -Method Head -Uri $WebHookNoticationURI -ErrorVariable errorck
    If ($errorck -ne $null) {
      Write-host
      Write-host -ForegroundColor Red "ERROR: Webhook URI not a valid URI"
      Write-Host -ForegroundColor Red $errorck
      Write-Host "______________________________________________________________________"
      Write-Host -ForegroundColor Red "Script aborted, see above error."
      Write-Host "______________________________________________________________________"
      Break
    }
    $body = '{"text":"Test from HannelsToolBox Enable-AzureVMAutoShutdown cmdlet"}'
    $webhookvalidation = Invoke-WebRequest -Uri $WebHookNoticationURI -Method Post -Body $body -ContentType application/json -ErrorVariable errorck
    if ($webhookvalidation.StatusCode -ne "200" -or $errorck -ne $null) {
      Write-host
      Write-host -ForegroundColor Red "ERROR: ERROR: Webhook URI not a valid Incoming Webhook URI"
      Write-Host -ForegroundColor Red $errorck
      Write-Host "______________________________________________________________________"
      Write-Host -ForegroundColor Red "Script aborted, see above error."
      Write-Host "______________________________________________________________________"
      Break
    }
    else {
      [Switch]$Webhooknotification = $true
    }
  }
  If ($emailfornotification -ne $null) {
    [Switch]$emailnotification = $true
  }
  If ($emailfornotification -eq $null -and $WebHookNoticationURI -eq $null) {
    $emailfornotification = (Get-AzureRmContext).Account.Id
    [Switch]$emailnotification = $true
  }
  If ($vmName -ne $null) {
    $vms = Get-AzureRmVM -ResourceGroupName $rgName -Name $vmName
  }
  If ($vmName -eq $null -and $rgName -ne $null) {
    $vms = Get-AzureRmVM -ResourceGroupName $rgName
  }
  If ($vmName -eq $null -and $rgName -eq $null) {
    $vms = Get-AzureRmVM
  }
  Write-host
  Foreach ($vm in $vms) {
    $rgName = $vm.ResourceGroupName
    $vmName = $vm.Name
    $location = $vm.Location
    $VMResourceId = $VM.Id
    $SubscriptionId = ($vm.Id).Split('/')[2]
    $ScheduledShutdownResourceId = "/subscriptions/$SubscriptionId/resourceGroups/$rgName/providers/microsoft.devtestlab/schedules/shutdown-computevm-$vmName"
    $Properties = @{}
    $Properties.Add('status', 'Enabled')
    $Properties.Add('taskType', 'ComputeVmShutdownTask')
    $Properties.Add('dailyRecurrence', @{'time' = "$time" })
    $Properties.Add('timeZoneId', "$timezone")
    If ($emailnotification.IsPresent) {
      $Properties.Add('notificationSettings', @{status = 'enabled'; timeInMinutes = 30; emailRecipient = "$emailfornotification" })
    }
    if ($Webhooknotification.IsPresent) {
      $Properties.Add('notificationSettings', @{status = 'enabled'; timeInMinutes = 30; WebhookUrl = "$WebHookNoticationURI" })
    }
    $Properties.Add('targetResourceId', $VMResourceId)
    $hout = New-AzureRmResource -Location $location -ResourceId $ScheduledShutdownResourceId -Properties $Properties -Force  -ErrorVariable errorck
    If ($errorck -ne $null) {
      Write-host
      Write-host -ForegroundColor Red "ERROR: " -NoNewline
      Write-Host -ForegroundColor Red $errorck
      Write-Host "______________________________________________________________________"
      Write-Host -ForegroundColor Red "Script aborted, see above error."
      Write-Host "______________________________________________________________________"
      Break
    }
    Write-host -ForegroundColor Green "Auto-shutdown is enabled for Virtual Machine $vmName at $time hours $timezone"
  }
  Write-host
}

Enable-AzureVMAutoShutdown -rgName $ResourceGroupName -vmName $AppComputerName -time $Time -timezone $TimeZone -emailfornotification $AdminEmail
Enable-AzureVMAutoShutdown -rgName $ResourceGroupName -vmName $SetupComputerName -time $Time -timezone $TimeZone -emailfornotification $AdminEmail
Enable-AzureVMAutoShutdown -rgName $ResourceGroupName -vmName $SQLComputerName -time $Time -timezone $TimeZone -emailfornotification $AdminEmail