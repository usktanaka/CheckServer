# 週次 SMART チェック
#
# [HDD / SATA SSD]
# 代替処理済みセクタ（05）、代替処理待ちセクタ（197）、回復不能セクタ（198）
#
# [NVMe SSD]
# 使用率（05: Value = 100 - PercentageUsed）が $nvmeUsedThreshold 以下
#
# PredictFailure（SMART が故障予測したか）
#
# をメール通知します。
#

# メール設定
$smtpServer = "smtp.example.com"
$from = "alert@server.local"
$to = "admin@company.com"
# NVMe 使用率アラートしきい値（Value がこの値以下 = 90% 以上消費でアラート）
$nvmeUsedThreshold = 10

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
        $id = $data.VendorSpecific[(2 + $i * 12)]
        if ($id -eq 0) { continue }

        $raw = [BitConverter]::ToUInt32($data.VendorSpecific, ($i * 12 + 7))
        $value = $data.VendorSpecific[(2 + $i * 12 + 3)]
        $thres = $threshold.VendorSpecific[($i * 12 + 3)]

        $attributes += [PSCustomObject]@{
            ID = $id
            Value = $value
            Threshold = $thres
            Raw = $raw
        }
    }

    # InstanceName で NVMe か判定
    $isNvme = $instance -match 'NVMe'

    if ($isNvme) {
        # NVMe: ID 5 は使用率の補数（Value = 100 - PercentageUsed）
        $important = $attributes | Where-Object { $_.ID -eq 5 }
        $nvmeAlert = $important -and ($important.Value -le $nvmeUsedThreshold)
    } else {
        # HDD / SATA SSD: セクタ不良系属性
        $important = $attributes | Where-Object { $_.ID -in 5, 10, 197, 198 }
        $nvmeAlert = $false
    }

    # メール本文
    $body = @"
SMART weekly check on $env:COMPUTERNAME

Disk: $instance
Type: $(if ($isNvme) { 'NVMe SSD' } else { 'HDD/SATA SSD' })
PredictFailure: $($disk.PredictFailure)

Important Attributes:
$($important | Format-Table -AutoSize | Out-String)

"@

    # 異常があれば通知
    if ($disk.PredictFailure -or $nvmeAlert -or (-not $isNvme -and ($important.Raw -gt 0))) {
        Send-MailMessage -SmtpServer $smtpServer -From $from -To $to `
            -Subject "[ALERT] SMART Warning on $env:COMPUTERNAME" -Body $body -Encoding utf8
    }
    else {
        # 正常でも週次レポートとしてメール送信
        Send-MailMessage -SmtpServer $smtpServer -From $from -To $to `
            -Subject "SMART Weekly Report on $env:COMPUTERNAME" -Body $body -Encoding utf8
    }
}
