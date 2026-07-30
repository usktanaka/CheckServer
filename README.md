# サーバー管理スクリプト

## Send-DiskAlert.ps1

HDD 監視スクリプトです。

タスクスケジューラで「イベント発生時」をトリガーに実行し、イベントをメール通知します。

以下を監視（トリガーに）します。

■ Disk（物理 I/O）
* 7：Bad Block（不良セクタ）
* 11：ハードウェアエラー
* 51：I/O エラー（ページング含む）

■ StorPort / storahci / stornvme（ドライバ・コントローラ）
* 129：デバイスリセット（タイムアウト）
* 153：I/O リトライ

■ Ntfs（ファイルシステム）
* 55：ファイルシステム破損
* 98：CHKDSK 必要


## Check-SMART.ps1

SMART 取得スクリプトです。HDD / SATA SSD と NVMe SSD を自動判別して監視します。

### HDD / SATA SSD

* 代替処理済みセクタ（05）
* Spin Retry Count（0A）
* 代替処理待ちセクタ（197）
* 回復不能セクタ（198）
* PredictFailure（SMART が故障予測したか）

### NVMe SSD

* 使用率（05: `Value = 100 − PercentageUsed`）が `$nvmeUsedThreshold` 以下でアラート
* PredictFailure（Critical Warning バイトが非 0 のとき）

`$nvmeUsedThreshold`（デフォルト: 10）を変更することで感度を調整できます。  
Value が 10 以下 = 消費率 90% 超でアラートを発報します。