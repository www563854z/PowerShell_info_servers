#-------------------------------------------------------------------------------------------------------------

# Exp:       服务器资源，并把备份情况发送钉钉

# Author:    YuanHai

# Modify:    YuanHai

# Date:      2023/04/07 10:00

# Version:   2023.04.v1


#-------------------------------------------------------------------------------------------------------------

$ServerName = "xxxx服务器"
# 获取CPU使用率 old
#$cpuUsage = Get-WmiObject -Class Win32_Processor | Measure-Object -Property LoadPercentage -Average | Select-Object -ExpandProperty Average

#获取CPU核心数量
$cpu_cores = (Get-WmiObject -Class Win32_Processor).NumberOfCores
#判断是否是个数组，是就求和
if ($cpu_cores -is [array]) {
    $cpu_cores = ($cpu_cores | Measure-Object -Sum).Sum
}
#获取CPU使用率百分比值。
$cpu_counter = "\Processor(_Total)\% Processor Time"
$cpu_usage = (Get-Counter -Counter $cpu_counter).CounterSamples[0].CookedValue
#计算CPU繁忙度值
$cpu_busy = $cpu_usage / $cpu_cores
$cpu_busy_percent = ($cpu_busy * 100).ToString("#.#")



# 获取内存使用率和总量
$memUsage = Get-Counter -Counter "\Memory\% Committed Bytes In Use" | Select-Object -ExpandProperty CounterSamples | Select-Object -ExpandProperty CookedValue | ForEach-Object { [math]::Round($_, 2) }
$total_memory = "{0:N2} GB" -f ((Get-WmiObject -Class Win32_PhysicalMemory | Measure-Object -Property Capacity -Sum).Sum / 1GB)

# 获取磁盘信息
$disks = Get-WmiObject -Class Win32_LogicalDisk -Filter "DriveType=3" | Select-Object DeviceID, VolumeName, FileSystem, Size, FreeSpace

# 计算每个磁盘的使用率和总大小
foreach ($disk in $disks) {
    $diskSize = $disk.Size
    $diskFreeSpace = $disk.FreeSpace
    $diskUsage = 100 - (($diskFreeSpace / $diskSize) * 100)
    $disk | Add-Member -MemberType NoteProperty -Name 'Usage (%)' -Value ([int]$diskUsage)
    $disk | Add-Member -MemberType NoteProperty -Name 'Size (GB)' -Value ([int]($diskSize / 1GB))
}

# 构建Markdown消息体
$markdownMsg = @"
### 服务器资源监控信息
 CPU 使用率：$cpu_busy_percent % \n
 内存 使用率：$memUsage %
 总量：$total_memory \n
 磁盘信息：
"@

# 构建磁盘信息部分的Markdown
foreach ($disk in $disks) {
    $diskMsg = "
   分区: $($disk.DeviceID)
   标签: $($disk.VolumeName)
   文件系统: $($disk.FileSystem)
   大小: $($disk.'Size (GB)') GB
   使用率: $($disk.'Usage (%)') % \n
   "
    $markdownMsg += $diskMsg
}

Function DingTalkApi($msg){
# 钉钉机器人Webhook地址
$webhookUrl = "https://oapi.dingtalk.com/robot/send?access_token=xxxxxxxxxxx"

$PostBody="{
`"markdown`":{
`"title`":`"服务器状态  $ServerName`",
`"text`":`"
### $ServerName 资源状态
-----------------------
$markdownMsg
-----------------------
`"
},
`"msgtype`":`"markdown`"
}"

# 发送到钉钉机器人
Write-Host $PostBody
$DingTalk = [System.Text.Encoding]::UTF8.GetBytes($PostBody)
invoke-WebRequest $webhookUrl -Method "POST" -ContentType "application/json;charset=utf-8" -Body $DingTalk


}
DingTalkApi -msg b
