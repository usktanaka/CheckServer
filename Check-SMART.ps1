# 週次 SMART チェック
#
# 代替処理済みセクタ（05）
# 代替処理待ちセクタ（197）
# 回復不能セクタ（198）
# PredictFailure（SMART が故障予測したか）
#
# をメール通知します。
#

# メール設定
$smtpServer = "smtp.example.com"
$from = "alert@server.local"
$to = "admin@company.com"

$disks = Get-WmiObject -Namespace root\wmi -Class MSStorageDriver_FailurePredictStatus

foreach ($disk in $disks) {
    $instance = $disk.InstanceName

    # SMART の生データ
    $data = Get-WmiObject -Namespace root\wmi -Class MSStorageDriver_FailurePredictData |
            Where-Object { $_.InstanceName -eq $instance }

    # SMART のしきい値
    $threshold = Get-WmiObject -Namespace root\wmi -Class MSStorageDriver_FailurePredictThresholds |
                 Where-Object { $_.InstanceName -eq $instance }

    # 属性を解析
    $attributes = @()

    for ($i = 0; $i -lt 30; $i++) {
        $id = $data.VendorSpecific[($i * 12)]
        if ($id -eq 0) { continue }

        $raw = [BitConverter]::ToInt32($data.VendorSpecific, ($i * 12 + 7))
        $value = $data.VendorSpecific[($i * 12 + 3)]
        $thres = $threshold.VendorSpecific[($i * 12 + 3)]

        $attributes += [PSCustomObject]@{
            ID = $id
            Value = $value
            Threshold = $thres
            Raw = $raw
        }
    }

    # 重要属性だけ抽出
    $important = $attributes | Where-Object { $_.ID -in 5, 197, 198 }

    # メール本文
    $body = @"
SMART weekly check on $env:COMPUTERNAME

Disk: $instance
PredictFailure: $($disk.PredictFailure)

Important Attributes:
$($important | Format-Table -AutoSize | Out-String)

"@

    # 異常があれば通知
    if ($disk.PredictFailure -or ($important.Raw -gt 0)) {
        Send-MailMessage -SmtpServer $smtpServer -From $from -To $to `
            -Subject "[ALERT] SMART Warning on $env:COMPUTERNAME" -Body $body
    }
}
