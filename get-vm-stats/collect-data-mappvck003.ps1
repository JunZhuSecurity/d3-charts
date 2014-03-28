﻿Add-PSSnapin VMware.VimAutomation.Core
Add-PSSnapin VMware.VimAutomation.Vds

#Set-PowerCLIConfiguration -InvalidCertificateAction Ignore -DefaultVIServerMode Single 

$vis = "mappvck003" #KFall
$cred = Import-Clixml s:\vmware\management.cred
$date = get-date -format yyyy-MM-dd
$data = "s:\vmware\stats\$date"
#if (Test-Path $data) {rd $data -Force -Recurse}
md $data -ErrorAction SilentlyContinue
cd $data

connect-viserver $vis -Credential $cred

Write-Host "Getting VMs from $vis"
$vm = (get-vm | ? {$_.PowerState -eq "PoweredOn"})

Write-Host "Saving VMs from $vis"
$vm |
Select-Object -Property Name,NumCpu,MemoryMB,usedSpaceGB,@{Name="HostName"; Expression={$_.VMHost.Name}},@{Name="OS"; Expression={$_.Guest.OSFullName}} | 
export-csv "vms_$vis.csv" -Encoding UTF8 -NoTypeInformation

Write-Host "Get Live VMs"
$live = ($vm | ?{$_.Name.StartsWith("L")})
$live = ($live | ?{-not ($_.Name -eq "LCDNCSV002")}) # LCDNCSV002 seems to be defect???

Write-Host "Get Live Stats"
$stats = @{}
$counters = "cpu.usage.average", "mem.active.average", "net.received.average", "net.transmitted.average", "disk.read.average", "disk.write.average"
$live | ForEach{$stats[$_.Name] = get-stat $_ -stat $counters -start (get-date).AddDays(-2) -finish (get-date).AddHours(-1)}

Write-Host "Write Live Stats"
$stats.GetEnumerator() | ForEach{$_.Value | ?{!$_.Instance} | Select-Object -Property MetricID,TimeStamp,Value | Export-Csv "$($_.Name).csv" -Encoding UTF8 -NoTypeInformation}