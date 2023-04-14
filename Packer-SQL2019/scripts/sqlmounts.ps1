$label = "Data,Mounts,system_data01,system_log01,data_data01,data_data02,data_data03,data_data04,log_log01,temp_data01,temp_data02,temp_data03,temp_data04,temp_data05,temp_data06,temp_data07,temp_data08,temp_log01,page01"
### Stops the Hardware Detection Service ###

$mounts = "D,M,system_data01,system_log01,data_data01,data_data02,data_data03,data_data04,log_log01,temp_data01,temp_data02,temp_data03,temp_data04,temp_data05,temp_data06,temp_data07,temp_data08,temp_log01,page01"
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
    if ($mountpoint -eq "system_data1") {Add-PartitionAccessPath -DiskNumber $d.Number -PartitionNumber 2 –AccessPath "M:\System\Data1"}
    if ($mountpoint -eq "system_log1") {Add-PartitionAccessPath -DiskNumber $d.Number -PartitionNumber 2 –AccessPath "M:\System\Log1"}
    if ($mountpoint -eq "data_data1") {Add-PartitionAccessPath -DiskNumber $d.Number -PartitionNumber 2 –AccessPath "M:\Data\Data1"}
    if ($mountpoint -eq "data_data2") {Add-PartitionAccessPath -DiskNumber $d.Number -PartitionNumber 2 –AccessPath "M:\Data\Data2"}
    if ($mountpoint -eq "data_data3") {Add-PartitionAccessPath -DiskNumber $d.Number -PartitionNumber 2 –AccessPath "M:\Data\Data3"}
    if ($mountpoint -eq "data_data4") {Add-PartitionAccessPath -DiskNumber $d.Number -PartitionNumber 2 –AccessPath "M:\Data\Data4"}
    if ($mountpoint -eq "log_log1") {Add-PartitionAccessPath -DiskNumber $d.Number -PartitionNumber 2 –AccessPath "M:\Log\Log1"}
    if ($mountpoint -eq "temp_data1") {Add-PartitionAccessPath -DiskNumber $d.Number -PartitionNumber 2 –AccessPath "M:\Temp\Data1"}
    if ($mountpoint -eq "temp_data2") {Add-PartitionAccessPath -DiskNumber $d.Number -PartitionNumber 2 –AccessPath "M:\Temp\Data2"}
    if ($mountpoint -eq "temp_data3") {Add-PartitionAccessPath -DiskNumber $d.Number -PartitionNumber 2 –AccessPath "M:\Temp\Data3"}
    if ($mountpoint -eq "temp_data4") {Add-PartitionAccessPath -DiskNumber $d.Number -PartitionNumber 2 –AccessPath "M:\Temp\Data4"}
    if ($mountpoint -eq "temp_data5") {Add-PartitionAccessPath -DiskNumber $d.Number -PartitionNumber 2 –AccessPath "M:\Temp\Data5"}
    if ($mountpoint -eq "temp_data6") {Add-PartitionAccessPath -DiskNumber $d.Number -PartitionNumber 2 –AccessPath "M:\Temp\Data6"}
    if ($mountpoint -eq "temp_data7") {Add-PartitionAccessPath -DiskNumber $d.Number -PartitionNumber 2 –AccessPath "M:\Temp\Data7"}
    if ($mountpoint -eq "temp_data8") {Add-PartitionAccessPath -DiskNumber $d.Number -PartitionNumber 2 –AccessPath "M:\Temp\Data8"}
    if ($mountpoint -eq "temp_log1") {Add-PartitionAccessPath -DiskNumber $d.Number -PartitionNumber 2 –AccessPath "M:\Temp\Log1"}
    if ($mountpoint -eq "page") {Add-PartitionAccessPath -DiskNumber $d.Number -PartitionNumber 2 –AccessPath "M:\Page\Page"}

    $drive= Get-Partition –Disknumber $d.Number –PartitionNumber 2 | Format-Volume –FileSystem NTFS –NewFileSystemLabel $mountpoint -AllocationUnitSize 65536 –Confirm:$false
     }
    ### 25 Second pause between each disk ###
    Start-Sleep 25
    
    if ($driveLetter -eq "M") {New-Item -Path 'M:\System\Data1' -ItemType Directory}
    if ($driveLetter -eq "M") {New-Item -Path 'M:\System\Log1' -ItemType Directory}
    if ($driveLetter -eq "M") {New-Item -Path 'M:\Data\Data1' -ItemType Directory}
    if ($driveLetter -eq "M") {New-Item -Path 'M:\Data\Data2' -ItemType Directory}
    if ($driveLetter -eq "M") {New-Item -Path 'M:\Data\Data3' -ItemType Directory}
    if ($driveLetter -eq "M") {New-Item -Path 'M:\Data\Data4' -ItemType Directory}
    if ($driveLetter -eq "M") {New-Item -Path 'M:\Log\Log1' -ItemType Directory}
    if ($driveLetter -eq "M") {New-Item -Path 'M:\Temp\Data1' -ItemType Directory}
    if ($driveLetter -eq "M") {New-Item -Path 'M:\Temp\Data2' -ItemType Directory}
    if ($driveLetter -eq "M") {New-Item -Path 'M:\Temp\Data3' -ItemType Directory}
    if ($driveLetter -eq "M") {New-Item -Path 'M:\Temp\Data4' -ItemType Directory}
    if ($driveLetter -eq "M") {New-Item -Path 'M:\Temp\Data5' -ItemType Directory}
    if ($driveLetter -eq "M") {New-Item -Path 'M:\Temp\Data6' -ItemType Directory}
    if ($driveLetter -eq "M") {New-Item -Path 'M:\Temp\Data7' -ItemType Directory}
    if ($driveLetter -eq "M") {New-Item -Path 'M:\Temp\Data8' -ItemType Directory}
    if ($driveLetter -eq "M") {New-Item -Path 'M:\Temp\Log1' -ItemType Directory}
    if ($driveLetter -eq "M") {New-Item -Path 'M:\Page\Page' -ItemType Directory}
    
   

if ($mountsArr[$diskIndex].length -eq 1){
    $driveletter=$drive.DriveLetter+':'
    icacls "$driveletter" /remove "everyone"
}
    $diskIndex = $diskIndex + 1

    
}

### Starts the Hardware Detection Service again ###
Start-Service -Name ShellHWDetection
### end of script ###
