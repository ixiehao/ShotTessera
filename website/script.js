const translations = {
  en: { navWorkflow:"Workflow", navFeatures:"Features", navPrivacy:"Privacy", download:"Download", eyebrow:"Native macOS · Private by default", heroTitle:"Make the whole video<br />visible at once.", heroSummary:"ShotTessera turns video into clean, configurable contact sheets—locally, quickly, and without a complicated editing suite.", heroDownload:"Download for macOS", viewSource:"View source <span aria-hidden=\"true\">↗</span>", compatibility:"macOS 13+ · Apple Silicon & Intel · Free and open source", queue:"Queue", preview:"Contact sheet", settings:"Settings", grid:"Grid", background:"Background", format:"Format", workflowEyebrow:"A focused workflow", workflowTitle:"From video to contact sheet in three steps.", stepOneTitle:"Drop in your videos", stepOneText:"Add one clip or a batch. The queue stays simple and visible.", stepTwoTitle:"Choose the moments", stepTwoText:"Use intelligent selection, then fine-tune with a real player timeline when you need control.", stepThreeTitle:"Export the story", stepThreeText:"Set grid, dimensions, background, labels, and PNG or JPG—then save beside your video.", featuresEyebrow:"Designed for the edit, not the setup", featuresTitle:"The useful frame, without the noise.", featuresSummary:"Every part of ShotTessera is tuned for the moment you need to review a film, share a scene, or find a shot again.", featureOneTitle:"Smarter frame selection", featureOneText:"Balances sharpness, scene variety, faces, action, and text-heavy screens for more useful results.", featureTwoTitle:"Manual precision", featureTwoText:"Scrub a visual timeline, step by frames, type a timecode, and number your selected sequence.", featureThreeTitle:"Made for your format", featureThreeText:"From 3 × 3 to 8 × 8, landscape to vertical, with backgrounds that match the material.", privacyEyebrow:"Your footage stays yours", privacyTitle:"No account. No upload. No cloud queue.", privacyText:"Frame analysis and export happen on your Mac. ShotTessera has no telemetry, cloud processing, Electron, FFmpeg, or Python runtime.", ctaEyebrow:"A clearer way to review video", ctaTitle:"Start with the whole picture.", github:"GitHub", feedback:"Feedback" },
  zh: { navWorkflow:"工作流", navFeatures:"功能", navPrivacy:"隐私", download:"下载", eyebrow:"原生 macOS · 默认保护隐私", heroTitle:"让整部影片，<br />一眼可见。", heroSummary:"ShotTessera 在本机快速制作干净、可自定义的影片拼图，不必打开复杂的剪辑软件。", heroDownload:"下载 macOS 版", viewSource:"查看源码 <span aria-hidden=\"true\">↗</span>", compatibility:"macOS 13+ · Apple Silicon 与 Intel · 免费开源", queue:"视频队列", preview:"分镜预览", settings:"分镜设置", grid:"网格", background:"底色", format:"格式", workflowEyebrow:"专注的工作流", workflowTitle:"三步，把影片变成分镜拼图。", stepOneTitle:"加入影片", stepOneText:"单部或批量添加，清晰的队列始终可见。", stepTwoTitle:"挑选关键画面", stepTwoText:"先用智能选帧，再通过真实播放器时间轴细调到需要的位置。", stepThreeTitle:"导出故事", stepThreeText:"设定网格、尺寸、底色、标签和 PNG/JPG，然后保存到影片旁。", featuresEyebrow:"专为看片，而非复杂设置", featuresTitle:"留下有用画面，过滤无用干扰。", featuresSummary:"ShotTessera 的每一处设计，都服务于审片、分享场景和再次找到某个镜头的时刻。", featureOneTitle:"更聪明的选帧", featureOneText:"综合清晰度、镜头变化、人物、动作与文字密度，挑出更有用的画面。", featureTwoTitle:"手动精确控制", featureTwoText:"可滑动视觉时间轴、逐帧微调、输入时间码，并为选中画面标记顺序。", featureThreeTitle:"适合你的画幅", featureThreeText:"支持 3 × 3 至 8 × 8，以及横屏、竖屏和多种适配底色。", privacyEyebrow:"你的影片，只属于你", privacyTitle:"无需账号，不上传，没有云端队列。", privacyText:"画面分析与导出都在你的 Mac 上完成。ShotTessera 没有遥测、云处理、Electron、FFmpeg 或 Python 运行时。", ctaEyebrow:"更清晰地审看影片", ctaTitle:"从全局，看见故事。", github:"GitHub", feedback:"反馈" },
  ja: { navWorkflow:"ワークフロー", navFeatures:"機能", navPrivacy:"プライバシー", download:"ダウンロード", eyebrow:"ネイティブ macOS · プライバシーを標準に", heroTitle:"動画全体を、<br />一目で把握。", heroSummary:"ShotTessera は複雑な編集ソフトを使わず、動画から整ったコンタクトシートを Mac 上で素早く作成します。", heroDownload:"macOS 版をダウンロード", viewSource:"ソースを見る <span aria-hidden=\"true\">↗</span>", compatibility:"macOS 13+ · Apple Silicon / Intel · 無料・オープンソース", queue:"キュー", preview:"コンタクトシート", settings:"設定", grid:"グリッド", background:"背景", format:"形式", workflowEyebrow:"集中できるワークフロー", workflowTitle:"3 ステップで動画をコンタクトシートに。", stepOneTitle:"動画を追加", stepOneText:"1 本でもバッチでも追加。キューは常にシンプルで見やすく保たれます。", stepTwoTitle:"瞬間を選ぶ", stepTwoText:"スマート選択の後、実際のプレイヤーのタイムラインで必要なフレームまで追い込めます。", stepThreeTitle:"ストーリーを書き出す", stepThreeText:"グリッド、サイズ、背景、表示、PNG/JPG を選び、動画の隣に保存します。", featuresEyebrow:"設定より、映像を見るために", featuresTitle:"必要なフレームだけを、ノイズなく。", featuresSummary:"ShotTessera は作品の確認、シーンの共有、必要なカットの再発見のために設計されています。", featureOneTitle:"より賢いフレーム選択", featureOneText:"鮮明さ、場面の変化、人物、アクション、文字量をバランスよく評価します。", featureTwoTitle:"手動での精密操作", featureTwoText:"視覚タイムラインのスクラブ、フレーム単位の調整、タイムコード入力、選択順の番号付けに対応。", featureThreeTitle:"多彩なフォーマット", featureThreeText:"3 × 3 から 8 × 8、横長から縦長、素材に合わせた背景色まで対応します。", privacyEyebrow:"あなたの映像は、あなたのもの", privacyTitle:"アカウント不要。アップロード不要。クラウド処理不要。", privacyText:"フレーム解析と書き出しはすべて Mac 内で行われます。ShotTessera はテレメトリー、クラウド処理、Electron、FFmpeg、Python ランタイムを使用しません。", ctaEyebrow:"動画をもっと明快に確認", ctaTitle:"全体像から、物語を読む。", github:"GitHub", feedback:"フィードバック" }
};
Object.assign(translations.en, {
  heroTitle: "Turn video into a<br />clean storyboard.",
  heroSummary: "Pick representative frames, make precise adjustments, and export a polished contact sheet—entirely on your Mac.",
  productCaption: "The real ShotTessera workspace"
});
Object.assign(translations.zh, {
  heroTitle: "把影片整理成一张<br />清晰的分镜图。",
  heroSummary: "自动挑选代表画面，逐帧精确微调，并在你的 Mac 本地导出精致的截图拼图。",
  productCaption: "真实的 ShotTessera 工作区"
});
Object.assign(translations.ja, {
  heroTitle: "動画を、見やすい一枚の<br />ストーリーボードに。",
  heroSummary: "代表フレームを選び、フレーム単位で調整し、洗練されたコンタクトシートを Mac 上だけで書き出します。",
  productCaption: "実際の ShotTessera ワークスペース"
});
Object.assign(translations.en, {
  navWorkflow: "How it works", navFeatures: "What it does", navPrivacy: "Privacy", download: "Download",
  eyebrow: "A simple way to revisit your videos", heroTitle: "Give every video a<br />memory map.",
  heroSummary: "A folder shows only one thumbnail for each video. ShotTessera lays out the key moments in one image, so you can see what happened before opening the file.",
  heroDownload: "Download for macOS", viewSource: "See the project on GitHub <span aria-hidden=\"true\">↗</span>",
  compatibility: "macOS 13 or later · Apple Silicon and Intel · Free and open source", productCaption: "ShotTessera workspace",
  workflowEyebrow: "Three simple steps", workflowTitle: "Add a video. Pick frames. Save the image.",
  stepOneTitle: "Add your videos", stepOneText: "Drop in one video, a few family clips, or a whole folder of footage.",
  stepTwoTitle: "See the important moments", stepTwoText: "Start with Smart Select. Use the timeline when you want to keep or replace one exact frame.",
  stepThreeTitle: "Save your memory map", stepThreeText: "Choose the grid, size, background, and file type. The image saves beside the original video.",
  featuresEyebrow: "Useful at home and at work", featuresTitle: "Find a moment without watching every video.",
  featuresSummary: "Use it for a child’s first steps, a holiday sunset, a family gathering, or a folder of footage before you start editing.",
  featureOneTitle: "A quick visual summary", featureOneText: "See the beginning, middle, and end of a video together instead of relying on one unhelpful thumbnail.",
  featureTwoTitle: "Choose the frame you want", featureTwoText: "Smart Select gives you a starting point. The visual timeline and small frame steps make it easy to fine-tune.",
  featureThreeTitle: "Organise a whole folder", featureThreeText: "Process several videos at once and export contact sheets with timecodes for faster browsing later.",
  privacyEyebrow: "Your videos stay on your Mac", privacyTitle: "No account. No upload. No cloud processing.",
  privacyText: "ShotTessera reads frames and creates the final image locally. Your family videos and personal footage never leave your computer.",
  guideEyebrow: "Install and start", guideTitle: "Install in three simple steps.",
  ctaEyebrow: "Ready to find a moment?", ctaTitle: "Make your video library easy to browse.", ctaDownload: "Get the latest version", ctaGithub: "Follow on GitHub ↗"
});
Object.assign(translations.zh, {
  navWorkflow: "使用方法", navFeatures: "功能", navPrivacy: "隐私", download: "下载",
  eyebrow: "让旧视频重新变得好找", heroTitle: "给每段视频一张<br />回忆地图。",
  heroSummary: "文件夹通常只给视频一张缩略图，模糊、黑屏或看不出内容。ShotTessera 把关键画面放在一张图里，让你打开视频前就知道里面发生了什么。",
  heroDownload: "下载 macOS 版", viewSource: "在 GitHub 查看项目 <span aria-hidden=\"true\">↗</span>",
  compatibility: "支持 macOS 13 及以上 · Apple Silicon 与 Intel · 免费开源", productCaption: "ShotTessera 中文界面",
  workflowEyebrow: "只需三步", workflowTitle: "加入视频，选择画面，保存图片。",
  stepOneTitle: "加入视频", stepOneText: "可以拖入一部影片、几段家庭录像，或整个文件夹里的素材。",
  stepTwoTitle: "看见关键时刻", stepTwoText: "先用智能选择；想保留或替换某一帧时，再用时间轴精确定位。",
  stepThreeTitle: "保存回忆地图", stepThreeText: "选择网格、尺寸、底色和格式，图片会保存在原视频旁边。",
  featuresEyebrow: "家庭整理和专业审片都适用", featuresTitle: "不用逐个播放，也能找到想要的瞬间。",
  featuresSummary: "找孩子第一次走路、旅行的日落、家人聚会，或剪片前快速浏览一批素材，都能从一张分镜图开始。",
  featureOneTitle: "快速看懂一段视频", featureOneText: "把开头、中间和结尾的代表画面同时展示，不再只靠一张无意义的缩略图判断内容。",
  featureTwoTitle: "自己决定要哪一帧", featureTwoText: "智能选择先给出结果；视觉时间轴和小步调帧让你轻松替换成真正想要的画面。",
  featureThreeTitle: "一次整理整个文件夹", featureThreeText: "可批量处理多条视频，导出带时间码的分镜图，日后浏览和查找都更快。",
  privacyEyebrow: "你的影片始终留在 Mac 上", privacyTitle: "无需账号，不上传，也不使用云端处理。",
  privacyText: "读取画面和生成图片都在本机完成。家庭录像和个人素材不会离开你的电脑。",
  guideEyebrow: "安装并开始使用", guideTitle: "三步完成安装。",
  ctaEyebrow: "准备好找回某个瞬间了吗？", ctaTitle: "让视频资料库变得一目了然。", ctaDownload: "获取最新版本", ctaGithub: "在 GitHub 关注 ↗"
});
Object.assign(translations.ja, {
  navWorkflow: "使い方", navFeatures: "できること", navPrivacy: "プライバシー", download: "ダウンロード",
  eyebrow: "昔の動画を、もう一度見つけやすく", heroTitle: "すべての動画に<br />思い出の地図を。",
  heroSummary: "フォルダに表示されるのは、たいてい動画ごとに一枚のサムネイルだけです。ShotTessera は大切な場面を一枚に並べ、動画を開く前に何が映っているか分かるようにします。",
  heroDownload: "macOS 版をダウンロード", viewSource: "GitHub でプロジェクトを見る <span aria-hidden=\"true\">↗</span>",
  compatibility: "macOS 13 以降 · Apple Silicon / Intel 対応 · 無料・オープンソース", productCaption: "ShotTessera 日本語インターフェース",
  workflowEyebrow: "3 つの簡単なステップ", workflowTitle: "動画を追加。場面を選ぶ。画像を保存。",
  stepOneTitle: "動画を追加", stepOneText: "一本の動画、家族の動画数本、またはフォルダごと追加できます。",
  stepTwoTitle: "大切な場面を見る", stepTwoText: "まずはスマート選択を使用。残したい一コマがあるときは、タイムラインで正確に選べます。",
  stepThreeTitle: "思い出の地図を保存", stepThreeText: "グリッド、サイズ、背景、形式を選ぶと、元の動画のそばに画像が保存されます。",
  featuresEyebrow: "家庭の動画整理にも、映像確認にも", featuresTitle: "すべて再生しなくても、見たい瞬間が見つかる。",
  featuresSummary: "子どもの初めての一歩、旅の夕日、家族の集まり、編集前の素材確認まで。一枚のコンタクトシートから始められます。",
  featureOneTitle: "動画の内容をすぐ把握", featureOneText: "始まり・途中・終わりの代表場面を同時に表示。一枚だけの分かりにくいサムネイルに頼りません。",
  featureTwoTitle: "欲しい一コマを選べる", featureTwoText: "スマート選択が最初の候補を作成。視覚タイムラインと小さなコマ送りで、好きな画面に調整できます。",
  featureThreeTitle: "フォルダをまとめて整理", featureThreeText: "複数の動画を一度に処理し、タイムコード付きのコンタクトシートを書き出せます。後から探すのも簡単です。",
  privacyEyebrow: "動画は Mac の外に出ません", privacyTitle: "アカウント不要。アップロード不要。クラウド処理不要。",
  privacyText: "フレームの読み込みから画像の作成まで、すべて Mac 上で完結します。家族の動画や個人の映像が外部に送られることはありません。",
  guideEyebrow: "インストールして始める", guideTitle: "3 ステップでインストール。",
  ctaEyebrow: "思い出の瞬間を探してみませんか？", ctaTitle: "動画ライブラリを、もっと見やすく。", ctaDownload: "最新版を入手", ctaGithub: "GitHub でフォロー ↗"
});
const localizedVisualAssets = {
  en: { product: "assets/workspace-en.png", productAlt: "ShotTessera workspace in English", workflow: "assets/manual-en.png", workflowAlt: "ShotTessera manual frame selection in English", guide: "assets/install-guide-en.jpg", guideAlt: "ShotTessera installation guide in English" },
  zh: { product: "assets/workspace-zh.png", productAlt: "ShotTessera 中文工作区", workflow: "assets/manual-zh.png", workflowAlt: "ShotTessera 中文手动选帧界面", guide: "assets/install-guide-zh.jpg", guideAlt: "ShotTessera 中文安装说明" },
  ja: { product: "assets/workspace-ja.png", productAlt: "ShotTessera 日本語ワークスペース", workflow: "assets/workflow-ja.png", workflowAlt: "ShotTessera の日本語ワークスペース", guide: "assets/install-guide-ja.jpg", guideAlt: "ShotTessera インストールガイド" }
};
function activateLanguage(language) {
  document.documentElement.lang = language === "zh" ? "zh-CN" : language;
  document.querySelectorAll("[data-i18n]").forEach((node) => { node.innerHTML = translations[language][node.dataset.i18n]; });
  const visuals = localizedVisualAssets[language];
  const product = document.querySelector(".localized-product");
  const workflow = document.querySelector(".localized-workflow");
  const guide = document.querySelector(".localized-guide");
  if (product) { product.src = visuals.product; product.alt = visuals.productAlt; }
  if (workflow) { workflow.src = visuals.workflow; workflow.alt = visuals.workflowAlt; }
  if (guide) { guide.src = visuals.guide; guide.alt = visuals.guideAlt; }
  document.querySelectorAll("[data-lang]").forEach((button) => button.setAttribute("aria-pressed", String(button.dataset.lang === language)));
  localStorage.setItem("shottessera-language", language);
}
document.querySelectorAll("[data-lang]").forEach((button) => button.addEventListener("click", () => activateLanguage(button.dataset.lang)));
activateLanguage(localStorage.getItem("shottessera-language") || "en");
