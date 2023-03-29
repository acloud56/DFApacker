Get-ScheduledTask -TaskName ServerManager | Disable-ScheduledTask -Verbose
New-ItemProperty -Path “HKLM:\SOFTWARE\Policies\Microsoft\Windows Defender” -Name DisableAntiSpyware -Value 1 -PropertyType DWORD -Force
