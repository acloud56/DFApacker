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

$mounts = "D,P"
$label = "Data,PageFile"
### Stops the Hardware Detection Service ###

$mounts = "D,P"
Stop-Service -Name ShellHWDetection
 
### Take all the new RAW disks into a variable ###
$disks = get-disk | Where-Object partitionstyle -eq "raw"
 
### Split the mounts into array of mounts
$mountsArr = $mounts -split ","
$labelArr = $label -split ","
 
### Starts a foreach loop that will add the drive
### and format the drive for each RAW drive. This
### will also map drive letters passed to the script
### or auto-assign a new available drive letter.
$diskIndex = 0
foreach ($d in $disks){
    $diskNumber = $d.Number
 
    ### Initialize disk
    if ($mountsArr[$diskIndex]) {
        $driveLetter = $mountsArr[$diskIndex]
        Write-Output -InputObject "Assigning drive letter $driveLetter to disk"
        $dl = get-Disk $d.Number | Initialize-Disk -PartitionStyle MBR -PassThru | New-Partition -DriveLetter $driveLetter -UseMaximumSize
    } else {
        Write-Output -InputObject "Auto-assigning drive letter to disk"
        $dl = get-Disk $d.Number | Initialize-Disk -PartitionStyle MBR -PassThru | New-Partition -AssignDriveLetter -UseMaximumSize
    }
 
    ### Determine drive label
    $driveLabel = "Disk $($diskNumber)"
    if ($labelArr[$diskIndex]) {
        $driveLabel = $labelArr[$diskIndex]
        Write-Output -InputObject "Assigning drive label $driveLabel to disk"
    }
 
    ### Format disk
    $drive=Format-Volume -driveletter $dl.Driveletter -FileSystem NTFS -NewFileSystemLabel $driveLabel -Confirm:$false
 
    ### 25 Second pause between each disk ###
    Start-Sleep 25
    $driveletter=$drive.DriveLetter+':'
    icacls "$driveletter" /remove 'everyone'
    $diskIndex = $diskIndex + 1
}
 
### Starts the Hardware Detection Service again ###
Start-Service -Name ShellHWDetection
### end of script ###
$disks=get-wmiobject -class win32_logicaldisk | Format-Table DeviceID,@{Label="Size";Expression={"{0:N2}" -f ($_.Size / 1GB)}} -AutoSize
Write-Output $disks
