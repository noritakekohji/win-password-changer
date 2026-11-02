# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.1.0] - 2026-11-02

### Added
- Windows Server 2022 上のローカルユーザーを選択してパスワードを個別または一括変更するGUI。
- ドライランとパスワードを含めない操作ログ。
- ローカルユーザー指定とログ先を指定できるCLIドライラン。
- GitHub ActionsでPowerShell ScriptAnalyzer、構文解析、CLIドライランを確認するCI。

### Changed
- Windows PowerShell 5.1で日本語スクリプトを実行できるUTF-8 BOMと、ユーザー別AppDataログ保存を採用。

### Fixed
- GUIのドライランチェックボックスとCLI引数の変数名衝突を修正。
