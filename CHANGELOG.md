# Changelog

All notable user-facing changes are recorded here. Stable releases remain
available on the [GitHub Releases page](https://github.com/ixiehao/ShotTessera/releases).

## v0.2.9

### English

- Optimised the AVFoundation and Vision pipeline for macOS 27: batch precise frame extraction, reuse Vision previews, and avoid redundant decoding.
- Added adaptive 3 × 3 / 4 × 4 low-resolution broad scans with full-resolution final-frame retrieval, while preserving the existing visual-quality rules.
- Added text-region-first screening with OCR fallback to keep title cards and warnings out without penalising ordinary subtitles.

### 中文

- 借助 macOS 27 的 AVFoundation 与 Vision 调度能力优化处理管线：批量精确取帧、复用 Vision 预览，并减少重复解码。
- 为 3 × 3 / 4 × 4 增加自适应低分辨率粗筛与最终高分辨率回读，同时保持既有画质判断规则。
- 新增“文字区域优先、OCR 回退”的筛选方式：继续拦截封面和警告图，不误伤普通字幕。

### 日本語

- macOS 27 の AVFoundation と Vision の実行特性を活かし、精密フレーム抽出のバッチ化、Vision プレビューの再利用、重複デコードの削減を行いました。
- 3 × 3 / 4 × 4 では低解像度の粗い走査と最終フレームの高解像度取得を適応的に行い、既存の画質判定を維持します。
- テキスト領域の検出を優先し、必要時のみ OCR にフォールバックすることで、通常の字幕を避けつつ表紙・警告画面を除外します。

## v0.2.8

### English

- Improved the manual frame-selection window with a redesigned player, timeline, and candidate gallery layout.
- Added storyboard background-colour selection to Frame settings.

### 中文

- 优化手动选帧窗口：重做整体布局为“播放器 + 时间线 + 候选画廊”。
- 在“画面”设置中增加“底色”选择。

### 日本語

- 手動フレーム選択ウインドウを、プレーヤー、タイムライン、候補ギャラリーの構成に再設計しました。
- 「画面」設定に絵コンテの背景色選択を追加しました。

## v0.2.7

### English

- Refined the Batch Studio’s three-column layout, spacing, minimum window size, and queue scrolling.
- Redrew the original vector icon system and improved preview-navigation contrast in Light and Dark modes.

### 中文

- 全面重构批处理工作台的三栏布局、间距、最小窗口尺寸与队列滚动体验。
- 重绘全套原创矢量界面图标；提升浅色与深色模式下预览翻页按钮的辨识度。

### 日本語

- バッチ作業画面の 3 カラム構成、余白、最小ウインドウサイズ、キューのスクロール体験を改善しました。
- オリジナルのベクターアイコンを再設計し、ライト／ダーク表示でのプレビュー移動ボタンの視認性を高めました。

## v0.2.6

### English

- Added Light, Dark, and System appearance modes; improved window restoration and three-language layouts.
- Improved large-batch reliability with background saves, low-memory history, and clearer failure handling.

### 中文

- 新增浅色、深色与跟随系统外观；优化窗口恢复和三语言布局。
- 提升超大批次稳定性：后台保存、低内存历史预览与更准确的失败处理。

### 日本語

- ライト、ダーク、システム連動表示を追加し、ウインドウ復元と 3 言語レイアウトを改善しました。
- バックグラウンド保存、省メモリ履歴、明確な失敗処理で大規模バッチを安定化しました。

## v0.2.5

### English

- Added GitHub update reminders in the main window, About panel, and Help menu.
- Update checks read public release metadata only; no video or usage data is sent.

### 中文

- 新增 GitHub 更新提醒：主界面、关于与帮助均可直接前往下载新版本。
- 更新检查仅读取公开版本信息，不上传视频或使用数据。

### 日本語

- メイン画面、情報画面、ヘルプメニューに GitHub の更新通知を追加しました。
- 更新確認は公開リリース情報のみを読み取り、動画や利用データを送信しません。

## v0.2.4

### English

- Batch runs can safely pause/resume or stop with confirmation; a pause takes effect after the current video is saved.
- A failed video no longer stops the queue; review its error and retry only failed items afterward.

### 中文

- 批处理新增安全暂停/继续与停止确认；暂停会在当前影片保存后生效，可调整未处理影片的配置。
- 单个影片失败不会中断队列；结束后可查看失败原因并仅重试失败项。

### 日本語

- バッチ処理に確認付きの安全な一時停止・再開・停止を追加。停止は現在の動画を保存した後に反映されます。
- 1 本の失敗でキュー全体は止まらず、終了後に原因を確認して失敗分だけ再試行できます。

## v0.2.3

### English

- Added manual frame selection: browse candidates, use Smart Select, then fine-tune before creating the storyboard.
- Browse batch results with previous/next controls and open the saved image’s folder directly.
- Improved batch reliability and memory protection for large exports.
- Redesigned the DMG with an aligned drag-to-Applications layout and automatic final-package and universal-binary validation.
- Replaced the synthetic README sample with an owner-shot real-world result and refreshed the three-language visual install guides.

### 中文

- 新增手动选择画面：可浏览候选截图、智能一键选帧，再按需微调后生成。
- 批量结果支持左右切换；保存后可直接打开所在目录。
- 优化批处理稳定性与大尺寸导出的内存保护。
- 重新设计 DMG 安装器：应用、箭头与“应用程序”对齐，并自动校验最终安装包与双架构。
- README 改用项目所有者自摄视频的真实生成案例，并更新三语图文安装指南。

### 日本語

- 手動フレーム選択を追加：候補を確認し、スマート選択後に調整してから生成できます。
- バッチ結果を前後に切り替えられ、保存後は画像のフォルダを直接開けます。
- バッチ処理の安定性と大きな出力時のメモリ保護を改善しました。
- DMG を再設計し、アプリ・矢印・「アプリケーション」を整列。最終 DMG と Universal Binary を自動検証します。
- README を所有者撮影の実例に更新し、3 言語の画像付きインストールガイドを刷新しました。

## v0.2.2 — Stable

### English

- Universal DMG for Apple Silicon and Intel Macs.
- English, 中文, and 日本語 interfaces with an easier language selector.
- Source, landscape, square, portrait, and common aspect layouts; aspect and
  width use matching dropdown panels.
- Batch processing, live previews, PNG/JPG, timecodes, and filename titles.
- The About panel links to developer ixiehao, the project, and feedback.

### 中文

- 同时支持 Apple Silicon 与 Intel Mac 的通用 DMG。
- 支持 English、中文、日本語；语言选择更易点击。
- 支持横屏、方屏、竖屏及常见比例；比例和宽度均使用统一的下拉选择面板。
- 支持批量视频、实时预览、PNG/JPG、时间码和文件标题水印。
- “关于”页提供开发者 ixiehao、项目主页和反馈入口。

### 日本語

- Apple Silicon / Intel Mac 向け Universal DMG。
- English、中文、日本語に対応し、言語選択を操作しやすく改善。
- 元動画、横長、正方形、縦長などの比率に対応。比率と幅を統一した
  ドロップダウンで選択可能。
- 複数動画、リアルタイムプレビュー、PNG/JPG、時刻表示、ファイル名タイトルに対応。
- 「情報」画面から開発者 ixiehao、プロジェクト、フィードバックを確認可能。
