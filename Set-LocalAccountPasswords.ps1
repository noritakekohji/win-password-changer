# Windows Server 2022 local account password management GUI.
# Requires an elevated 64-bit Windows PowerShell 5.1 session.
param(
    [switch]$DryRun,
    [string[]]$UserName,
    [string]$LogPath
)

$ErrorActionPreference = 'Stop'

if ([string]::IsNullOrWhiteSpace($LogPath)) {
    $LogPath = Join-Path $env:LOCALAPPDATA 'WinPasswordChanger\operations.log'
}

if ($DryRun) {
    try {
        $users = @(Get-LocalUser -ErrorAction Stop)
        if ($UserName -and $UserName.Count -gt 0) {
            $requestedNames = @($UserName | ForEach-Object { $_ -split ',' } | ForEach-Object { $_.Trim().ToLowerInvariant() } | Where-Object { $_ })
            $users = @($users | Where-Object { $requestedNames -contains $_.Name.ToLowerInvariant() })
            $foundNames = @($users | ForEach-Object { $_.Name.ToLowerInvariant() })
            $missingNames = @($requestedNames | Where-Object { $foundNames -notcontains $_ })
            if ($missingNames.Count -gt 0) {
                throw ('Specified local users were not found: ' + ($missingNames -join ', '))
            }
        }

        $logDirectory = Split-Path -Parent $LogPath
        if (-not (Test-Path -LiteralPath $logDirectory)) {
            New-Item -ItemType Directory -Path $logDirectory -Force -ErrorAction Stop | Out-Null
        }
        $lines = @('{0} DRY-RUN target count: {1} (no password changes)' -f (Get-Date -Format 'yyyy-MM-dd HH:mm:ss'), $users.Count)
        $lines += @($users | Sort-Object Name | ForEach-Object {
            '{0} DRY-RUN target: {1} (password value not logged)' -f (Get-Date -Format 'yyyy-MM-dd HH:mm:ss'), $_.Name
        })
        Add-Content -LiteralPath $LogPath -Value $lines -Encoding UTF8 -ErrorAction Stop
        $lines
        "Log: $LogPath"
        exit 0
    }
    catch {
        [Console]::Error.WriteLine($_.Exception.Message)
        exit 1
    }
}

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
[System.Windows.Forms.Application]::EnableVisualStyles()

$form = New-Object System.Windows.Forms.Form
$form.Text = 'ローカルアカウント パスワード変更'
$form.Size = New-Object System.Drawing.Size(900, 700)
$form.MinimumSize = New-Object System.Drawing.Size(760, 580)
$form.StartPosition = 'CenterScreen'

$title = New-Object System.Windows.Forms.Label
$title.Text = 'Windows Server ローカルアカウントのパスワード変更'
$title.Font = New-Object System.Drawing.Font('Yu Gothic UI', 14, [System.Drawing.FontStyle]::Bold)
$title.Location = New-Object System.Drawing.Point(18, 14)
$title.Size = New-Object System.Drawing.Size(820, 32)
$form.Controls.Add($title)

$scope = New-Object System.Windows.Forms.Label
$scope.Text = "対象: $env:COMPUTERNAME のローカルユーザーのみ (ドメインアカウントは対象外)"
$scope.Location = New-Object System.Drawing.Point(20, 50)
$scope.Size = New-Object System.Drawing.Size(820, 24)
$form.Controls.Add($scope)

$accounts = New-Object System.Windows.Forms.ListView
$accounts.Location = New-Object System.Drawing.Point(20, 82)
$accounts.Size = New-Object System.Drawing.Size(840, 225)
$accounts.Anchor = 'Top,Left,Right'
$accounts.View = 'Details'
$accounts.CheckBoxes = $true
$accounts.FullRowSelect = $true
$accounts.GridLines = $true
[void]$accounts.Columns.Add('ユーザー名', 210)
[void]$accounts.Columns.Add('表示名', 260)
[void]$accounts.Columns.Add('有効', 70)
[void]$accounts.Columns.Add('説明', 270)
$form.Controls.Add($accounts)

$reload = New-Object System.Windows.Forms.Button
$reload.Text = '一覧を更新'
$reload.Location = New-Object System.Drawing.Point(20, 316)
$reload.Size = New-Object System.Drawing.Size(110, 30)
$form.Controls.Add($reload)

$selection = New-Object System.Windows.Forms.Label
$selection.Text = 'パスワード設定'
$selection.Font = New-Object System.Drawing.Font('Yu Gothic UI', 10, [System.Drawing.FontStyle]::Bold)
$selection.Location = New-Object System.Drawing.Point(20, 362)
$selection.Size = New-Object System.Drawing.Size(200, 24)
$form.Controls.Add($selection)

$individualMode = New-Object System.Windows.Forms.RadioButton
$individualMode.Text = 'アカウントごとに指定'
$individualMode.Location = New-Object System.Drawing.Point(22, 393)
$individualMode.Size = New-Object System.Drawing.Size(220, 24)
$individualMode.Checked = $true
$form.Controls.Add($individualMode)

$sharedMode = New-Object System.Windows.Forms.RadioButton
$sharedMode.Text = '選択した全アカウントに同じパスワード'
$sharedMode.Location = New-Object System.Drawing.Point(250, 393)
$sharedMode.Size = New-Object System.Drawing.Size(360, 24)
$form.Controls.Add($sharedMode)

$passwordGrid = New-Object System.Windows.Forms.DataGridView
$passwordGrid.Location = New-Object System.Drawing.Point(20, 423)
$passwordGrid.Size = New-Object System.Drawing.Size(840, 115)
$passwordGrid.Anchor = 'Top,Left,Right'
$passwordGrid.AllowUserToAddRows = $false
$passwordGrid.AllowUserToDeleteRows = $false
$passwordGrid.RowHeadersVisible = $false
$passwordGrid.AutoSizeColumnsMode = 'Fill'
$passwordGrid.Columns.Add('UserName', 'ユーザー名') | Out-Null
$passwordColumn = New-Object System.Windows.Forms.DataGridViewTextBoxColumn
$passwordColumn.Name = 'Password'
$passwordColumn.HeaderText = '新しいパスワード'
$passwordColumn.MaxInputLength = 256
$passwordGrid.Columns.Add($passwordColumn) | Out-Null
$form.Controls.Add($passwordGrid)

$sharedPassword = New-Object System.Windows.Forms.TextBox
$sharedPassword.Location = New-Object System.Drawing.Point(20, 423)
$sharedPassword.Size = New-Object System.Drawing.Size(840, 28)
$sharedPassword.Anchor = 'Top,Left,Right'
$sharedPassword.UseSystemPasswordChar = $true
$sharedPassword.Visible = $false
$form.Controls.Add($sharedPassword)

$showPassword = New-Object System.Windows.Forms.CheckBox
$showPassword.Text = '表示'
$showPassword.Location = New-Object System.Drawing.Point(20, 460)
$showPassword.Size = New-Object System.Drawing.Size(80, 24)
$showPassword.Visible = $false
$form.Controls.Add($showPassword)

$dryRunCheckbox = New-Object System.Windows.Forms.CheckBox
$dryRunCheckbox.Text = 'ドライラン (変更せず対象と設定状況のみ記録)'
$dryRunCheckbox.Location = New-Object System.Drawing.Point(20, 550)
$dryRunCheckbox.Size = New-Object System.Drawing.Size(390, 24)
$form.Controls.Add($dryRunCheckbox)

$apply = New-Object System.Windows.Forms.Button
$apply.Text = 'パスワード変更を実行'
$apply.Location = New-Object System.Drawing.Point(690, 546)
$apply.Size = New-Object System.Drawing.Size(170, 34)
$apply.Anchor = 'Top,Right'
$form.Controls.Add($apply)

$log = New-Object System.Windows.Forms.TextBox
$log.Location = New-Object System.Drawing.Point(20, 585)
$log.Size = New-Object System.Drawing.Size(840, 65)
$log.Anchor = 'Top,Bottom,Left,Right'
$log.Multiline = $true
$log.ReadOnly = $true
$log.ScrollBars = 'Vertical'
$form.Controls.Add($log)

$logPath = $LogPath

function Write-OperationLog {
    param([string]$Message)
    $line = '{0} {1}' -f (Get-Date -Format 'yyyy-MM-dd HH:mm:ss'), $Message
    $log.AppendText($line + [Environment]::NewLine)
    $directory = Split-Path -Parent $logPath
    if (-not (Test-Path -LiteralPath $directory)) {
        New-Item -ItemType Directory -Path $directory -Force -ErrorAction Stop | Out-Null
    }
    Add-Content -LiteralPath $logPath -Value $line -Encoding UTF8 -ErrorAction Stop
}

function ConvertTo-LocalAccountPassword {
    [CmdletBinding()]
    [System.Diagnostics.CodeAnalysis.SuppressMessageAttribute(
        'PSAvoidUsingConvertToSecureStringWithPlainText',
        '',
        Justification = 'WinForms exposes entered passwords as strings; convert only at the OS API boundary and never persist or log them.'
    )]
    [System.Diagnostics.CodeAnalysis.SuppressMessageAttribute(
        'PSAvoidUsingPlainTextForPassword',
        '',
        Justification = 'This value is received transiently from a WinForms password field and immediately converted for the OS API.'
    )]
    param([string]$Password)
    ConvertTo-SecureString -String $Password -AsPlainText -Force
}

function Show-AccountList {
    $accounts.Items.Clear()
    try {
        if (-not (Get-Command Get-LocalUser -ErrorAction SilentlyContinue)) {
            throw 'Get-LocalUser が見つかりません。64ビット Windows PowerShell 5.1 を使用してください。'
        }
        foreach ($user in (Get-LocalUser | Sort-Object Name)) {
            $item = New-Object System.Windows.Forms.ListViewItem($user.Name)
            [void]$item.SubItems.Add($user.FullName)
            [void]$item.SubItems.Add($(if ($user.Enabled) { '有効' } else { '無効' }))
            [void]$item.SubItems.Add($user.Description)
            $item.Tag = $user.SID.Value
            [void]$accounts.Items.Add($item)
        }
        Write-OperationLog 'アカウント一覧を更新しました。'
    }
    catch {
        $errorMessage = $_.Exception.Message -replace '[\r\n]+', ' '
        try { Write-OperationLog ('一覧取得失敗: ' + $errorMessage) }
        catch { $log.AppendText(('ログ保存失敗: ' + $_.Exception.Message + [Environment]::NewLine)) }
        [System.Windows.Forms.MessageBox]::Show($errorMessage, '一覧取得エラー', 'OK', 'Error') | Out-Null
    }
}

$reload.Add_Click({ Show-AccountList })
$individualMode.Add_CheckedChanged({
    $passwordGrid.Visible = $individualMode.Checked
    $sharedPassword.Visible = $sharedMode.Checked
    $showPassword.Visible = $sharedMode.Checked
})
$sharedMode.Add_CheckedChanged({
    $passwordGrid.Visible = $individualMode.Checked
    $sharedPassword.Visible = $sharedMode.Checked
    $showPassword.Visible = $sharedMode.Checked
})
$showPassword.Add_CheckedChanged({ $sharedPassword.UseSystemPasswordChar = -not $showPassword.Checked })
$accounts.Add_ItemChecked({
    if ($form.IsHandleCreated) {
        $form.BeginInvoke([Action]{
            $selected = @($accounts.Items | Where-Object { $_.Checked })
            $passwordGrid.Rows.Clear()
            foreach ($item in $selected) {
                [void]$passwordGrid.Rows.Add($item.Text, '')
            }
        }) | Out-Null
    }
})

$apply.Add_Click({
    $selected = @($accounts.Items | Where-Object { $_.Checked })
    if ($selected.Count -eq 0) {
        [System.Windows.Forms.MessageBox]::Show('変更するアカウントを選択してください。', '入力確認', 'OK', 'Warning') | Out-Null
        return
    }

    $targets = @()
    if ($sharedMode.Checked) {
        if ([string]::IsNullOrEmpty($sharedPassword.Text)) {
            [System.Windows.Forms.MessageBox]::Show('共通パスワードを入力してください。', '入力確認', 'OK', 'Warning') | Out-Null
            return
        }
        foreach ($item in $selected) { $targets += [pscustomobject]@{ UserName = $item.Text; Password = $sharedPassword.Text; Sid = $item.Tag } }
    }
    else {
        foreach ($row in $passwordGrid.Rows) {
            $value = [string]$row.Cells['Password'].Value
            if ([string]::IsNullOrEmpty($value)) {
                [System.Windows.Forms.MessageBox]::Show("$($row.Cells['UserName'].Value) のパスワードを入力してください。", '入力確認', 'OK', 'Warning') | Out-Null
                return
            }
            $account = $selected | Where-Object { $_.Text -eq $row.Cells['UserName'].Value } | Select-Object -First 1
            $targets += [pscustomobject]@{ UserName = [string]$row.Cells['UserName'].Value; Password = $value; Sid = $account.Tag }
        }
        if ($targets.Count -ne $selected.Count) {
            [System.Windows.Forms.MessageBox]::Show('選択中の全アカウントにパスワードを指定してください。', '入力確認', 'OK', 'Warning') | Out-Null
            return
        }
    }

    $mode = if ($dryRunCheckbox.Checked) { 'ドライラン' } else { 'パスワード変更' }
    $names = ($targets | ForEach-Object { $_.UserName }) -join ', '
    if ([System.Windows.Forms.MessageBox]::Show("次のローカルアカウントを対象に $mode を実行します。`r`n$names`r`n`r`nパスワードはログに記録されません。続行しますか?", '実行確認', 'YesNo', 'Warning') -ne 'Yes') { return }

    $apply.Enabled = $false
    try {
        $sharedPassword.Clear()
        foreach ($row in $passwordGrid.Rows) { $row.Cells['Password'].Value = '' }
        foreach ($target in $targets) {
            if ($dryRunCheckbox.Checked) {
                Write-OperationLog ("DRY-RUN 対象: {0} (パスワード値は記録しません)" -f $target.UserName)
                continue
            }
            try {
                $securePassword = $null
                $current = Get-LocalUser -SID $target.Sid
                $securePassword = ConvertTo-LocalAccountPassword -Password $target.Password
                $target.Password = $null
                $current | Set-LocalUser -Password $securePassword -ErrorAction Stop
                Write-OperationLog ("成功: {0} のパスワードを変更しました。" -f $target.UserName)
            }
            catch {
                Write-OperationLog ("失敗: {0} - OSが操作を拒否しました。入力値とパスワードポリシー、管理者権限を確認してください。" -f $target.UserName)
            }
            finally {
                if ($null -ne $securePassword) { $securePassword.Dispose(); $securePassword = $null }
            }
        }
    }
    finally {
        $apply.Enabled = $true
        $sharedPassword.Clear()
        foreach ($row in $passwordGrid.Rows) { $row.Cells['Password'].Value = '' }
        foreach ($target in $targets) { $target.Password = $null }
        [System.Windows.Forms.MessageBox]::Show("処理が完了しました。ログ: $logPath", '完了', 'OK', 'Information') | Out-Null
    }
})

Show-AccountList
[void]$form.ShowDialog()
