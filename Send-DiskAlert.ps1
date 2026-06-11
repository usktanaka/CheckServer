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
# Disk, Ntfs, StorPort, storahci,  stornvme, storvsp, storvsc などのストレージ関連ソース
#
# イベントID：
#
# 7, 11, 51, 55, 98, 129, 153
#
# ② 操作 → 「プログラムの開始」
# プログラム：
# pwsh.exe   （Windows PowerShell の場合は powershell.exe）
#
# 引数（方法A: スクリプトが直近のディスクイベントをログから自動取得）：
#
# -File "C:\Scripts\Send-DiskAlert.ps1"
#
# 引数（方法B: トリガーになったイベントを正確に渡す。推奨）：
#
# -File "C:\Scripts\Send-DiskAlert.ps1" -EventRecordID $(eventRecordID)
#
#   ※ 方法B を使うには、タスクXMLのトリガーに ValueQueries を追加する必要があります。
#      トリガーのXMLを編集し、<EventTrigger> 内に以下を追記してください：
#
#      <ValueQueries>
#        <Value name="eventRecordID">Event/System/EventRecordID</Value>
#      </ValueQueries>
#
#      これで $(eventRecordID) にトリガーイベントの RecordId が展開されます。
#
#
param(
    # タスクスケジューラからトリガーイベントの RecordId を渡す場合に使用（方法B）。
    # 渡されない場合は System ログから直近のディスク関連イベントを自動取得する（方法A）。
    [long]$EventRecordID
)

# 監視対象（タスクのトリガー条件と合わせる）
$targetSources  = @('Disk', 'Ntfs', 'StorPort', 'storahci', 'stornvme', 'storvsp', 'storvsc'    )
$targetEventIDs = @(7, 11, 51, 55, 98, 129, 153)

# 対象イベントを取得
$diskEvent = $null
if ($PSBoundParameters.ContainsKey('EventRecordID') -and $EventRecordID -gt 0) {
    # 方法B: トリガーになったイベントを RecordId でピンポイント取得
    $diskEvent = Get-WinEvent -LogName System -FilterXPath "*[System[(EventRecordID=$EventRecordID)]]" -MaxEvents 1 -ErrorAction SilentlyContinue
}
if (-not $diskEvent) {
    # 方法A: 直近のディスク関連イベントを取得
    $diskEvent = Get-WinEvent -FilterHashtable @{
        LogName      = 'System'
        ProviderName = $targetSources
        ID           = $targetEventIDs
    } -MaxEvents 1 -ErrorAction SilentlyContinue
}

if ($diskEvent) {
    $EventID = $diskEvent.Id
    $Source  = $diskEvent.ProviderName
    $Message = $diskEvent.Message
    $timeStr = $diskEvent.TimeCreated
} else {
    $EventID = '(not found)'
    $Source  = '(not found)'
    $Message = 'No matching disk-related event was found in the System log.'
    $timeStr = '(unknown)'
}

# メール設定
$smtpServer = "smtp.example.com"
$from = "alert@server.local"
$to = "admin@company.com"
$subject = "[ALERT] Disk Error Detected on $env:COMPUTERNAME"

$body = @"
Disk-related event detected.

Server: $env:COMPUTERNAME
Time: $timeStr
Event ID: $EventID
Source: $Source

Message:
$Message

Please check the disk status immediately.
"@

Send-MailMessage -SmtpServer $smtpServer -From $from -To $to -Subject $subject -Body $body -Encoding utf8

# End of script
