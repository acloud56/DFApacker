
$label = "Data,PageFile,SQLLogs_Root,TempDB_Root,SQLData_Root,SQLLogs_Vol1,TempDB_Vol1,SQLData_Vol0,SQLData_Vol1"
### Stops the Hardware Detection Service ###

$mounts = "D,P,L,X,R,SQLLogs_Vol1,TempDB_Vol1,SQLData_Vol0,SQLData_Vol1"
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

        if ($mountsArr[$diskIndex].length -eq 1) {
        $driveLetter = $mountsArr[$diskIndex]
        Write-Output -InputObject "Assigning drive letter $driveLetter to disk"
        $dl = get-Disk $d.Number | Initialize-Disk -PartitionStyle MBR -PassThru | New-Partition -DriveLetter $driveLetter -UseMaximumSize
        }
        else {
        $mountpoint = $mountsArr[$diskIndex]
        Write-Output -InputObject "Assigning mountpoint $mountpoint to disk"
        $dl = get-Disk $d.Number | Initialize-Disk -PartitionStyle GPT -PassThru | New-Partition -UseMaximumSize
        }
    } 
 
    ### Determine drive label
    $driveLabel = "Disk $($diskNumber)"
    if ($labelArr[$diskIndex]) {
        $driveLabel = $labelArr[$diskIndex]
        Write-Output -InputObject "Assigning drive label $driveLabel to disk"
    }
 
    ### Format disk
    if ($mountsArr[$diskIndex].length -eq 1){
    $drive=Format-Volume -driveletter $dl.Driveletter -FileSystem NTFS -NewFileSystemLabel $driveLabel -Confirm:$false
    }
     else {
    if ($mountpoint -eq "SQLLogs_Vol1") {Add-PartitionAccessPath -DiskNumber $d.Number -PartitionNumber 2 –AccessPath "L:\SQLLogs_Vol1"}
    if ($mountpoint -eq "TempDB_Vol1") {Add-PartitionAccessPath -DiskNumber $d.Number -PartitionNumber 2 –AccessPath "X:\TempDB_Vol1"}
    if ($mountpoint -eq "SQLData_Vol0") {Add-PartitionAccessPath -DiskNumber $d.Number -PartitionNumber 2 –AccessPath "R:\SQLData_Vol0"}
    if ($mountpoint -eq "SQLData_Vol1") {Add-PartitionAccessPath -DiskNumber $d.Number -PartitionNumber 2 –AccessPath "R:\SQLData_Vol1"}
    $drive= Get-Partition –Disknumber $d.Number –PartitionNumber 2 | Format-Volume –FileSystem NTFS –NewFileSystemLabel $mountpoint -AllocationUnitSize 65536 –Confirm:$false
     }
    ### 25 Second pause between each disk ###
    Start-Sleep 25
    
    if ($driveLetter -eq "L") {New-Item -Path 'L:\SQLLogs_Vol1' -ItemType Directory}
    if ($driveLetter -eq "X") {New-Item -Path 'X:\TempDB_Vol1' -ItemType Directory}
    if ($driveLetter -eq "R") {New-Item -Path 'R:\SQLData_Vol0' -ItemType Directory}
    if ($driveLetter -eq "R") {New-Item -Path 'R:\SQLData_Vol1' -ItemType Directory}

if ($mountsArr[$diskIndex].length -eq 1){
    $driveletter=$drive.DriveLetter+':'
    icacls "$driveletter" /remove 'everyone'
}
    $diskIndex = $diskIndex + 1

    
}

### Starts the Hardware Detection Service again ###
Start-Service -Name ShellHWDetection
### end of script ###
