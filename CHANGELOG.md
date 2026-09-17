# Changelog

All notable user-facing changes are recorded here. Stable releases remain
available on the [GitHub Releases page](https://github.com/ixiehao/ShotTessera/releases).

## v0.2.6

### 中文

- 新增浅色、深色与跟随系统外观；优化窗口恢复和三语言布局。
- 提升超大批次稳定性：后台保存、低内存历史预览与更准确的失败处理。

### English

- Added Light, Dark, and System appearance modes; improved window restoration and three-language layouts.
- Improved large-batch reliability with background saves, low-memory history, and clearer failure handling.

### 日本語

- ライト、ダーク、システム連動表示を追加し、ウインドウ復元と 3 言語レイアウトを改善しました。
- バックグラウンド保存、省メモリ履歴、明確な失敗処理で大規模バッチを安定化しました。

## v0.2.5

### 中文

- 新增 GitHub 更新提醒：主界面、关于与帮助均可直接前往下载新版本。
- 更新检查仅读取公开版本信息，不上传视频或使用数据。

### English

- Added GitHub update reminders in the main window, About panel, and Help menu.
- Update checks read public release metadata only; no video or usage data is sent.

### 日本語

- メイン画面、情報画面、ヘルプメニューに GitHub の更新通知を追加しました。
- 更新確認は公開リリース情報のみを読み取り、動画や利用データを送信しません。

## v0.2.4

### 中文

- 批处理新增安全暂停/继续与停止确认；暂停会在当前影片保存后生效，可调整未处理影片的配置。
- 单个影片失败不会中断队列；结束后可查看失败原因并仅重试失败项。

### English

- Batch runs can safely pause/resume or stop with confirmation; a pause takes effect after the current video is saved.
- A failed video no longer stops the queue; review its error and retry only failed items afterward.

### 日本語

- バッチ処理に確認付きの安全な一時停止・再開・停止を追加。停止は現在の動画を保存した後に反映されます。
- 1 本の失敗でキュー全体は止まらず、終了後に原因を確認して失敗分だけ再試行できます。

## v0.2.3

### 中文

- 新增手动选择画面：可浏览候选截图、智能一键选帧，再按需微调后生成。
- 批量结果支持左右切换；保存后可直接打开所在目录。
- 优化批处理稳定性与大尺寸导出的内存保护。
- 重新设计 DMG 安装器：应用、箭头与“应用程序”对齐，并自动校验最终安装包与双架构。
- README 改用项目所有者自摄视频的真实生成案例，并更新三语图文安装指南。

### English

- Added manual frame selection: browse candidates, use Smart Select, then fine-tune before creating the storyboard.
- Browse batch results with previous/next controls and open the saved image’s folder directly.
- Improved batch reliability and memory protection for large exports.
- Redesigned the DMG with an aligned drag-to-Applications layout and automatic final-package and universal-binary validation.
- Replaced the synthetic README sample with an owner-shot real-world result and refreshed the three-language visual install guides.

### 日本語

- 手動フレーム選択を追加：候補を確認し、スマート選択後に調整してから生成できます。
- バッチ結果を前後に切り替えられ、保存後は画像のフォルダを直接開けます。
- バッチ処理の安定性と大きな出力時のメモリ保護を改善しました。
- DMG を再設計し、アプリ・矢印・「アプリケーション」を整列。最終 DMG と Universal Binary を自動検証します。
- README を所有者撮影の実例に更新し、3 言語の画像付きインストールガイドを刷新しました。

## v0.2.2 — Stable

### 中文

- 同时支持 Apple Silicon 与 Intel Mac 的通用 DMG。
- 支持中文、English、日本語；语言选择更易点击。
- 支持横屏、方屏、竖屏及常见比例；比例和宽度均使用统一的下拉选择面板。
- 支持批量视频、实时预览、PNG/JPG、时间码和文件标题水印。
- “关于”页提供开发者 xao、项目主页和反馈入口。

### English

- Universal DMG for Apple Silicon and Intel Macs.
- 中文, English, and 日本語 interfaces with an easier language selector.
- Source, landscape, square, portrait, and common aspect layouts; aspect and
  width use matching dropdown panels.
- Batch processing, live previews, PNG/JPG, timecodes, and filename titles.
- The About panel links to developer xao, the project, and feedback.

### 日本語

- Apple Silicon / Intel Mac 向け Universal DMG。
- 中文、English、日本語に対応し、言語選択を操作しやすく改善。
- 元動画、横長、正方形、縦長などの比率に対応。比率と幅を統一した
  ドロップダウンで選択可能。
- 複数動画、リアルタイムプレビュー、PNG/JPG、時刻表示、ファイル名タイトルに対応。
- 「情報」画面から開発者 xao、プロジェクト、フィードバックを確認可能。
