# Windows Server ローカルアカウント パスワード変更ツール

Windows Server 2022 上のローカルユーザーをGUIで選択し、個別または共通の新しいパスワードを設定するツールです。アカウント操作には Microsoft 標準の `Get-LocalUser` / `Set-LocalUser` を使います。

## 仕様

- 対象は実行したコンピューター上のローカルユーザーです。Active Directory のドメインユーザーやリモートサーバー操作は対象外です。
- 有効/無効状態と説明を確認しながら複数アカウントを選べます。
- 選択したユーザーごとに異なるパスワード、または選択ユーザー全員に同じパスワードを指定できます。
- ドライランではパスワード変更をせず、対象ユーザーを記録します。`-DryRun` を指定するとGUIを開かずにドライランを実行できます。`-UserName user1,user2` で対象を選び、`-LogPath C:\path\dry-run.log` でログ先を指定できます。
- 実行前に対象一覧を確認します。OS/ドメインのパスワードポリシーに反する値はOS側で拒否され、アカウントごとの結果を記録します。
- パスワード文字列はログに出力せず、処理後に画面上の入力を消去します。
- ログは `%LOCALAPPDATA%\WinPasswordChanger\operations.log` に追記されます。
- パスワード入力中のメモリ消去は保証されません。GUIの画面を覗かれない管理端末で使用してください。

## 実行要件と使い方

- Windows Server 2022 またはWindows 10/11、64ビット Windows PowerShell 5.1以降、管理者権限が必要です。PowerShell 7でも実行できます。
- `Set-LocalAccountPasswords.ps1` を対象サーバーに配置し、管理者として起動した Windows PowerShell から実行します。
- 実行ポリシーに応じて署名済みスクリプトまたは組織で許可された方法で起動してください。実行ポリシーを恒久的に緩和しないでください。
- Server Core には対話型デスクトップがないため使用できません。
- 既存ローカルユーザーのパスワードをリセットすると、暗号化ファイルや保存済み資格情報などへのアクセスに影響する場合があります。対象を確認して実行してください。

## 検証

Windows Server 2022 上で管理者権限を使い、まずGUIのドライラン、次にテスト用アカウントで実変更とログを確認してください。CLIドライランの例: `powershell.exe -NoProfile -File .\Set-LocalAccountPasswords.ps1 -DryRun -UserName user1,user2 -LogPath .\dry-run.log`。GUIはWindows Formsを使用します。GitHub ActionsではPowerShell ScriptAnalyzer、構文解析、CLIドライランを実行します。

## バージョンと公開範囲

初期版 `0.1.0`。詳細は [CHANGELOG.md](CHANGELOG.md) を参照してください。ライセンスは [LICENSE](LICENSE) を参照してください。
