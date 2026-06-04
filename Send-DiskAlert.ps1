#
# Windows Server HDD 監視
#
#
# 1. タスクスケジューラで「イベント発生時」をトリガーにする
#
# ① タスク作成 → トリガー → 「イベント時」
# ログ：
#
# System
#
# ソース：
#
# Disk, Ntfs, StorPort, storahci
#
# イベントID：
#
# 7, 11, 51, 55, 98, 129, 153
#
# ② 操作 → 「プログラムの開始」
# プログラム：
# powershell.exe
#
# 引数：
#
# -File "C:\Scripts\Send-DiskAlert.ps1"
#
#
#
param(
    [string]$EventID,
    [string]$Source,
    [string]$Message
)

# メール設定
$smtpServer = "smtp.example.com"
$from = "alert@server.local"
$to = "admin@company.com"
$subject = "[ALERT] Disk Error Detected on $env:COMPUTERNAME"

$body = @"
Disk-related event detected.

Server: $env:COMPUTERNAME
Event ID: $EventID
Source: $Source

Message:
$Message

Please check the disk status immediately.
"@

Send-MailMessage -SmtpServer $smtpServer -From $from -To $to -Subject $subject -Body $body

# End of script
