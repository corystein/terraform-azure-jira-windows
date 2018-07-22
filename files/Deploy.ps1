# Ref: https://github.com/bobalob/Terraform-AzureRM-Example/blob/master/Deploy.PS1
# Ref: https://gitlab.com/jamienelson/terraform-azure-rm-example/blob/618b7e4af73c76bc09b77508ad7bfce7d581c518/Deploy.PS1

#---------------------------------------------------------[Initialisations]--------------------------------------------------------

#Set Error Action to Silently Continue
#$ErrorActionPreference = "SilentlyContinue"

#-----------------------------------------------------------[Execution]------------------------------------------------------------

Start-Transcript -Path C:\Deploy.log

Write-Host "Setup WinRM for $Env:COMPUTERNAME"

Write-Host "Setup WinRM using QuickConfig"
cmd /c "winrm quickconfig -q"
#Enable-PSRemoting –force

Write-Host "Enable HTTP in WinRM"
cmd /c "winrm quickconfig -transport:http"
#winrm quickconfig -transport:http
cmd /c "winrm set winrm/config/listener?Address=*+Transport=HTTP @{Port=`"5985`"}"
cmd /c "winrm set winrm/config/service @{AllowUnencrypted=`"true`"}"

Write-Host "Configure WinRM defaults"
cmd /c "winrm set winrm/config @{MaxTimeoutms=`"1800000`"}"
cmd /c "winrm set winrm/config/winrs @{MaxMemoryPerShellMB=`"2048`"}"
#Set-item WSMan:\localhost\Shell\MaxMemoryPerShellMB 2048

Write-Host "Set Basic Auth in WinRM"
cmd /c "winrm set winrm/config/service/auth @{Basic=`"true`"}"
cmd /c "winrm set winrm/config/client/auth @{Basic=`"true`"}"

# https://docs.microsoft.com/en-us/windows/desktop/winrm/multi-hop-support
#Write-Host "Set CredSSP Auth in WinRM"
#cmd /c "winrm set winrm/config/client/auth @{CredSSP=`"true`"}"
#cmd /c "winrm set winrm/config/service/auth @{CredSSP=`"true`"}"

Write-Host "TrustedHosts file configuration"
Set-Item WSMan:\localhost\Client\TrustedHosts -Value “*” -Force

Write-Host "Open Firewall Port"
cmd /c "netsh advfirewall firewall set rule group=`"remote administration`" new enable=yes"
cmd /c "netsh firewall add portopening TCP 5985 `"Port 5985`""
New-NetFirewallRule -DisplayName 'WinRM Inbound' -Profile @('Domain', 'Private') -Direction Inbound -Action Allow -Protocol TCP -LocalPort @('5985')

Write-Host "Configure WinRM Service"
#cmd /c net stop winrm
#cmd /c sc config winrm start= auto
#cmd /c net start winrm
# Set start mode to automatic
Set-Service WinRM -StartMode Automatic
Restart-Service -Name WinRM -Force

# Ref: https://docs.microsoft.com/en-us/powershell/module/microsoft.wsman.management/enable-wsmancredssp?view=powershell-6
#Enable-WSManCredSSP

Stop-Transcript
