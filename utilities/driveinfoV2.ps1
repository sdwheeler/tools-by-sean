# Create custom object to store volume info
$hash = [ordered]@{
    DriveDeviceID=$null
    DriveModel=$null
    DriveSize=$null
    DriveSignature=$null
    VolumeDeviceID=$null
    VolumeMountPoint=$null
    VolumeLabel=$null
    VolumeSerialNumber=$null
    VolumeCapacity=$null
    VolumeBlockSize=$null
    VolumeFileSystem=$null
    PartitionName=$null
    PartitionSize=$null
    PartitionStartingOffset=$null
    PartitionAligned=$null
    PartitionBootPartition=$null
    ControllerName=$null
    ControllerDriver=$null
    ControllerDriverName=$null
    ControllerDriverVersion=$null
}

function GetPartitionData {
    param ($partition, $rv)

    # Collect data from Win32_DiskPartition
    $rv.PartitionName = $partition.Name
    $rv.PartitionBootPartition = $partition.BootPartition
    $rv.PartitionStartingOffset = $partition.StartingOffset
    if ($rv.VolumeBlockSize) {
       $rv.PartitionAligned = (($partition.StartingOffset % $rv.VolumeBlockSize) -eq 0)
    }
    $rv.PartitionSize  = "{0:N2}" -f ($partition.Size/1GB) + " GB"

    # Collect data from Win32_DiskDrive
    $drvq="ASSOCIATORS OF {Win32_DiskPartition.DeviceID='" + $partition.DeviceID + "'} WHERE ResultClass=Win32_DiskDrive"
    $drives=Get-WmiObject -Query $drvq
    $rv.DriveDeviceID = $drives.DeviceID
    $rv.DriveModel = $drives.Model
    $rv.DriveSize = "{0:N2}" -f ($drives.Size/1GB) + " GB"
    $rv.DriveSignature = if ($drives.Signature -ne $null) {$drives.Signature.ToString("X")}

    # Collect data from Win32_xxxController
    $ctlq = "ASSOCIATORS OF {Win32_PNPEntity.DeviceID='" + $drives.PNPDeviceID
    if ($drives.PNPDeviceID.StartsWith("IDE"))
       { $ctlq += "'} WHERE ResultClass=Win32_IDEController" }
    elseif ($drives.PNPDeviceID.StartsWith("SCSI"))
       { $ctlq += "'} WHERE ResultClass=Win32_SCSIController" }
    elseif ($drives.PNPDeviceID.StartsWith("USB"))
       { $ctlq += "'} WHERE ResultClass=Win32_USBController" }
    $ctl = Get-WmiObject -Query $ctlq
	if ($ctl -eq $null)
	{
		$ctlq = "ASSOCIATORS OF {Win32_PNPEntity.DeviceID='" + $drives.PNPDeviceID + "'} WHERE ResultClass=Win32_SCSIController"
		$ctl = Get-WmiObject -Query $ctlq
	}
    $rv.ControllerName = $ctl.Name

    # Collect data from Win32_SystemDriver
    $drvq = "ASSOCIATORS OF {Win32_PNPEntity.DeviceID='" + $ctl.PNPDeviceID + "'} WHERE ResultClass=Win32_SystemDriver"
    $drv = Get-WmiObject -Query $drvq
    $rv.ControllerDriver = $drv.PathName

    # Get file version information
    $rv.ControllerDriverName = $(Get-Item $drv.PathName).VersionInfo.FileDescription
    $rv.ControllerDriverVersion = $(Get-Item $drv.PathName).VersionInfo.FileVersion
    $rv
}

# Get a collection of volumes for DriveType=Local Disk
$vols=Get-WmiObject win32_volume | Where-Object {$_.DriveType -eq 3}
ForEach ($v in $vols)
{
    # Create a new instance of my class and append it to an array
    $vdata = New-Object -TypeName PSObject -Property $hash
    $voldata += ,$vdata

    # Collect data from Win32_Volume
    $voldata[$voldata.Count-1].VolumeMountPoint   = $v.DriveLetter
    $voldata[$voldata.Count-1].VolumeDeviceID     = $v.DeviceID
    $voldata[$voldata.Count-1].VolumeFileSystem   = $v.FileSystem
    $voldata[$voldata.Count-1].VolumeCapacity     = "{0:N2}" -f ($v.Capacity/1GB) + " GB"
    $voldata[$voldata.Count-1].VolumeBlockSize    = $v.BlockSize
    $voldata[$voldata.Count-1].VolumeLabel        = $v.Label
    $voldata[$voldata.Count-1].VolumeSerialNumber = $v.SerialNumber.ToString("X")

    if ( $v.Driveletter.Length -eq 2)
    {

        $dpq="ASSOCIATORS OF {Win32_LogicalDisk.DeviceID='" + $v.DriveLetter + "'} WHERE ResultClass=Win32_DiskPartition"
        $parts=Get-WmiObject -Query $dpq
        foreach ($dp in $parts)
        {
            $voldata[$voldata.Count-1] = GetPartitionData $dp $voldata[$voldata.Count-1]
        }
    }
}

# Find all partitions not associated with a volume
$partitions = Get-WmiObject Win32_DiskPartition
foreach ($partition in $partitions)
{
    $found=$false
    foreach ($v in $voldata)
    {
        if ($v.PartitionName -eq $partition.Name)
        {
            $found=$true
            break
        }
    }
    if ($found -eq $false)
    {
        # Create a new instance of my class and append it to an array
        $vdata = New-Object -TypeName PSObject -Property $hash
        $voldata += ,$vdata

        $voldata[$voldata.Count-1] = GetPartitionData $partition $voldata[$voldata.Count-1]
    }
}


$voldata | Sort-Object DriveDeviceID, PartitionName

