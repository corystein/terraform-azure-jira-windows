# Stop script on any error
$ErrorActionPreference = "Stop"
$ProgressPreference = "SilentlyContinue"

#Requires -RunAsAdministrator
#Requires -Version 5.1

# Start logging
Start-Transcript -Path "C:\InstallJira.log"

#######################################################
# Download Java
#######################################################
# https://blog.danielburrowes.com/2016/10/powershell-download-and-install-java-8.html
# https://gist.github.com/carlcantprogram/42fbecb399af7e8ce4c0
Write-Host "Download Java..."

$JavaURL = "http://download.oracle.com/otn-pub/java/jdk/8u181-b13/96a7b8442fe848ef90c96a2fad6ed6d1/jdk-8u181-windows-x64.exe"
$Java_Filename = $JavaURL.Substring($JavaURL.LastIndexOf("/") + 1);
Invoke-WebRequest $JavaURL -UseBasicParsing -UseDefaultCredentials -SessionVariable s | Out-Null
$c = New-Object System.Net.Cookie("oraclelicense", "accept-securebackup-cookie", "/", ".oracle.com")

$s.Cookies.Add($JavaURL, $c)

if (Test-Path "$Env:TEMP\$Java_Filename") { Remove-Item -Path "$Env:TEMP\$Java_Filename" -Force | Out-Null }
Invoke-WebRequest $JavaURL -UseBasicParsing -UseDefaultCredentials -WebSession $s -OutFile "$Env:TEMP\$Java_Filename"
Write-Host "Completed downloading Java"
#######################################################

#######################################################
# Download Jira
#######################################################
Write-Host "Download Jira..."
$JiraURL = "https://www.atlassian.com/software/jira/downloads/binary/atlassian-jira-software-7.4.2-x64.exe"
$Jira_Filename = $JiraURL.Substring($JiraURL.LastIndexOf("/") + 1);
if (Test-Path "$Env:TEMP\$Jira_Filename") { Remove-Item -Path "$Env:TEMP\$Jira_Filename" -Force | Out-Null }
Invoke-WebRequest -Uri $JiraURL -OutFile "$Env:Temp\$Jira_Filename"
Write-Host "Completed downloading Jira"
#######################################################


#######################################################
# Install Java
#######################################################
Write-Host "Install Java..."
$process = (Start-Process "$Env:TEMP\$Java_Filename" `
        -ArgumentList 'INSTALL_SILENT=Enable REBOOT=Disable SPONSORS=Disable' `
        -Wait -PassThru)

$process.WaitForExit()
Write-Host "Process exit code: [$($process.ExitCode)]"

if ($process.ExitCode -eq 0) {
    Write-Host "Successfully installed Java" -ForegroundColor Green
}
else {
    Write-Error "Failure installing Java"
}

cmd /c "C:\ProgramData\Oracle\Java\javapath\java.exe -version"
Write-Host "Completed installation of Java"
#######################################################


#######################################################
# Install Jira
#######################################################
Write-Host "Install Jira..."

# Create response file
$ResponseFile = @" 
#install4j response file for JIRA Software 7.4.2
#Fri Jul 20 12:39:01 UTC 2018
app.jiraHome=C\:\\Program Files\\Atlassian\\Application Data\\JIRA
rmiPort`$Long=8005
app.install.service`$Boolean=true
existingInstallationDir=C\:\\Program Files\\JIRA Software
sys.confirmedUpdateInstallationString=false
sys.programGroupAllUsers`$Boolean=false
sys.languageId=en
sys.installationDir=C\:\\Program Files\\Atlassian\\JIRA
sys.programGroupName=JIRA
httpPort`$Long=8080
portChoice=default

"@ 
$ResponseFile | Out-File -FilePath "$Env:TEMP\response.varfile" -Force #-Encoding ASCII

# Install Jira using response file
$process = (Start-Process "$Env:TEMP\$Jira_Filename" `
        -ArgumentList "-q -varfile $Env:TEMP\response.varfile" `
        -Wait -PassThru)

$process.WaitForExit()
Write-Host "Process exit code: [$($process.ExitCode)]"

if ($process.ExitCode -eq 0) {
    Write-Host "Successfully installed Jira" -ForegroundColor Green
}
else {
    Write-Error "Failure installing Jira"
}

Write-Host "Completed installation of Jira"
#######################################################

#######################################################
# Configure Jira
#######################################################
# https://confluence.atlassian.com/adminjiraserver073/increasing-jira-application-memory-861253796.html
Write-Host "Configuring Jira..."

$JiraServiceName = (Get-Service | Where { $_.Name -like '*jira*' }).Name

if (-not([System.String]::IsNullOrWhiteSpace($JiraServiceName))) {
    $RegKey64 = "HKLM:\Software\Wow6432Node\Apache Software Foundation\Procrun 2.0\$JiraServiceName\Parameters\Java"
    $RegProperty = "JvmMx"
    $NewValue = "1536" 

    if (Test-Path $RegKey64) {
        Get-ItemProperty -Path $RegKey64 -Name $RegProperty
        Set-ItemProperty -Path $RegKey64 -Name $RegProperty -Value $NewValue -Type DWord
        Get-ItemProperty -Path $RegKey64 -Name $RegProperty
    }

    Restart-Service -Name $JiraServiceName
}
else {
    Write-Error "Unable to locate Jira service"
}

Write-Host "Completed configuring Jira"
#######################################################

#######################################################
# Clean up
#######################################################
#Push-Location -Path $Env:TEMP
#Remove-Item * -Recurse -Force
#Pop-Location

#if (Test-Path "$Env:TEMP\$Java_Filename") { Remove-Item -Path "$Env:TEMP\$Java_Filename" -Force | Out-Null }
#if (Test-Path "$Env:TEMP\$Jira_Filename") { Remove-Item -Path "$Env:TEMP\$Jira_Filename" -Force | Out-Null }
#######################################################

# Stop logging
Stop-Transcript