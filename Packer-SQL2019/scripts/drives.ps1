$label = "Data"
### Stops the Hardware Detection Service ###

$mounts = "D"
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
    if ($mountpoint -eq "system_data01") {Add-PartitionAccessPath -DiskNumber $d.Number -PartitionNumber 2 –AccessPath "M:\System\Data01"}
    if ($mountpoint -eq "system_log01") {Add-PartitionAccessPath -DiskNumber $d.Number -PartitionNumber 2 –AccessPath "M:\System\Log01"}
    if ($mountpoint -eq "data_data01") {Add-PartitionAccessPath -DiskNumber $d.Number -PartitionNumber 2 –AccessPath "M:\Data\Data01"}
    if ($mountpoint -eq "data_data02") {Add-PartitionAccessPath -DiskNumber $d.Number -PartitionNumber 2 –AccessPath "M:\Data\Data02"}
    if ($mountpoint -eq "data_data03") {Add-PartitionAccessPath -DiskNumber $d.Number -PartitionNumber 2 –AccessPath "M:\Data\Data03"}
    if ($mountpoint -eq "data_data04") {Add-PartitionAccessPath -DiskNumber $d.Number -PartitionNumber 2 –AccessPath "M:\Data\Data04"}
    if ($mountpoint -eq "log_log01") {Add-PartitionAccessPath -DiskNumber $d.Number -PartitionNumber 2 –AccessPath "M:\Log\Log01"}
    if ($mountpoint -eq "temp_data01") {Add-PartitionAccessPath -DiskNumber $d.Number -PartitionNumber 2 –AccessPath "M:\Temp\Data01"}
    if ($mountpoint -eq "temp_data02") {Add-PartitionAccessPath -DiskNumber $d.Number -PartitionNumber 2 –AccessPath "M:\Temp\Data02"}
    if ($mountpoint -eq "temp_data03") {Add-PartitionAccessPath -DiskNumber $d.Number -PartitionNumber 2 –AccessPath "M:\Temp\Data03"}
    if ($mountpoint -eq "temp_data04") {Add-PartitionAccessPath -DiskNumber $d.Number -PartitionNumber 2 –AccessPath "M:\Temp\Data04"}
    if ($mountpoint -eq "temp_data05") {Add-PartitionAccessPath -DiskNumber $d.Number -PartitionNumber 2 –AccessPath "M:\Temp\Data05"}
    if ($mountpoint -eq "temp_data06") {Add-PartitionAccessPath -DiskNumber $d.Number -PartitionNumber 2 –AccessPath "M:\Temp\Data06"}
    if ($mountpoint -eq "temp_data07") {Add-PartitionAccessPath -DiskNumber $d.Number -PartitionNumber 2 –AccessPath "M:\Temp\Data07"}
    if ($mountpoint -eq "temp_data08") {Add-PartitionAccessPath -DiskNumber $d.Number -PartitionNumber 2 –AccessPath "M:\Temp\Data08"}
    if ($mountpoint -eq "temp_log01") {Add-PartitionAccessPath -DiskNumber $d.Number -PartitionNumber 2 –AccessPath "M:\Temp\Log01"}
    if ($mountpoint -eq "page01") {Add-PartitionAccessPath -DiskNumber $d.Number -PartitionNumber 2 –AccessPath "M:\Page\Page01"}
    

    $drive= Get-Partition –Disknumber $d.Number –PartitionNumber 2 | Format-Volume –FileSystem NTFS –NewFileSystemLabel $mountpoint -AllocationUnitSize 65536 –Confirm:$false
     }
    ### 25 Second pause between each disk ###
    Start-Sleep 25
    
    if ($driveLetter -eq "M") {New-Item -Path 'M:\System\Data01' -ItemType Directory}
    if ($driveLetter -eq "M") {New-Item -Path 'M:\System\Log01' -ItemType Directory}
    if ($driveLetter -eq "M") {New-Item -Path 'M:\Data\Data01' -ItemType Directory}
    if ($driveLetter -eq "M") {New-Item -Path 'M:\Data\Data02' -ItemType Directory}
    if ($driveLetter -eq "M") {New-Item -Path 'M:\Data\Data03' -ItemType Directory}
    if ($driveLetter -eq "M") {New-Item -Path 'M:\Data\Data04' -ItemType Directory}
    if ($driveLetter -eq "M") {New-Item -Path 'M:\Log\Log01' -ItemType Directory}
    if ($driveLetter -eq "M") {New-Item -Path 'M:\Temp\Data01' -ItemType Directory}
    if ($driveLetter -eq "M") {New-Item -Path 'M:\Temp\Data02' -ItemType Directory}
    if ($driveLetter -eq "M") {New-Item -Path 'M:\Temp\Data03' -ItemType Directory}
    if ($driveLetter -eq "M") {New-Item -Path 'M:\Temp\Data04' -ItemType Directory}
    if ($driveLetter -eq "M") {New-Item -Path 'M:\Temp\Data05' -ItemType Directory}
    if ($driveLetter -eq "M") {New-Item -Path 'M:\Temp\Data06' -ItemType Directory}
    if ($driveLetter -eq "M") {New-Item -Path 'M:\Temp\Data07' -ItemType Directory}
    if ($driveLetter -eq "M") {New-Item -Path 'M:\Temp\Data08' -ItemType Directory}
    if ($driveLetter -eq "M") {New-Item -Path 'M:\Temp\Log01' -ItemType Directory}
    if ($driveLetter -eq "M") {New-Item -Path 'M:\Page\Page01' -ItemType Directory}
    
   

if ($mountsArr[$diskIndex].length -eq 1){
    $driveletter=$drive.DriveLetter+':'
    icacls "$driveletter" /remove "everyone"
}
    $diskIndex = $diskIndex + 1

    
}

### Starts the Hardware Detection Service again ###
Start-Service -Name ShellHWDetection
### end of script ###