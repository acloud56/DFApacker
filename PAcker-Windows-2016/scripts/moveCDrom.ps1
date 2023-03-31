$initial_d_drive = Get-CimInstance Win32_LogicalDisk -Filter 'DeviceID="D:"' | Select-Object -Unique
if ($initial_d_drive.DriveType -eq 5) 
{
    Write-Output 'Drive D is a CD-ROM, moving it to F:'
    $drv = Get-WmiObject win32_volume -filter 'DriveLetter = "D:"'
    $drv.DriveLetter = "F:"
    $drv.Put()
}

$initial_e_drive = Get-CimInstance Win32_LogicalDisk -Filter 'DeviceID="E:"' | Select-Object -Unique
if ($initial_e_drive.DriveType -eq 5) 
{
    Write-Output 'Drive E is a CD-ROM, moving it to G:'
    $drv = Get-WmiObject win32_volume -filter 'DriveLetter = "E:"'
    $drv.DriveLetter = "G:"
    $drv.Put()
}
