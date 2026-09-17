# ShotTessera

[English](README.md) · [简体中文](README.zh-CN.md) · [日本語](README.ja.md)

![原创合成示例：视频画面经过智能挑选，生成九宫格分镜图](docs/assets/video-to-storyboard-demo.gif)

ShotTessera 是一款原生 macOS 分镜图工具：从视频中挑选有代表性的画面，拼成一张干净的分镜图。`tessera` 意为马赛克的小拼片，正对应本项目把镜头组织为整体的方式。

项目名称为 **视频一键截屏拼图**，适合搜索“视频截图拼图”“视频一键截图”“分镜图生成器”“视频九宫格截图”“视频联系表”等关键词。

> **最新版：**[v0.2.3 通用 DMG](https://github.com/ixiehao/ShotTessera/releases/tag/v0.2.3) · macOS 13+ · Apple Silicon 与 Intel Mac

## 一张图看懂功能

| 1. 添加视频 | 2. 智能挑帧 | 3. 生成拼图 | 4. 本地导出 |
| --- | --- | --- | --- |
| 选择一个视频，或一次加入多个视频。 | 识别转场，避开黑屏、模糊与重复画面，并优先考虑人物镜头。 | 3×3 至 8×8 网格逐张实时预览。 | 在视频同目录保存宽度至少 1920 px 的 PNG 或 JPG。 |

## 功能

- 自动识别明显的镜头变化，优先选择有面部或人物的有效画面。
- 跳过黑屏、低清晰度和近似重复的画面。
- 默认完整保留视频的竖屏、方屏或横屏构图；也可手动选择 16:9、4:3、1:1、3:4、9:16、21:9，再生成 3×3 至 8×8 分镜网格。支持 PNG、JPG 和最低 1920 px 宽度导出。
- 可一次添加多个视频，按队列顺序处理；右侧会逐张显示实时预览。
- 支持 MP4、MOV、MPEG 等常见格式；能否解码取决于当前 macOS 支持的视频编码。
- 可显示每张截图的源时间码。
- 默认不添加标题；开启“标题水印”后，使用视频文件名（不含扩展名）作为居中的半透明粗体标题。
- 可在应用顶部切换中文、英文、日语界面；选择会被记住。
- 输出自动保存到视频同目录，命名为 `视频名-shot-001.ext`，序号会安全递增。

所有分析和导出均在本机完成。项目不包含账号、遥测、网络请求、云上传、Electron、FFmpeg 或 Python 运行时。

## 下载

如已安装 [Homebrew](https://brew.sh/)，可直接执行：

```sh
brew install --cask ixiehao/tap/shottessera
```

也可打开[最新发布页](https://github.com/ixiehao/ShotTessera/releases/latest)，下载适用于 Apple Silicon 或 Intel Mac 的通用 **DMG**。

## 安装前先看这三步

![适合新手的 macOS 三步安装图文说明](docs/assets/install-guide-zh.jpg)

1. 双击下载的 `.dmg`，将 **视频一键截屏拼图.app** 拖进“应用程序”。
2. 复制完成后可推出或删除 DMG；它只是安装包，不会删除已经安装的应用。
3. 应用尚未经过 Apple 公证。若系统提示无法验证开发者，请在“应用程序”中按住 Control 点按应用，选择“打开”，再确认一次“打开”。无需关闭 macOS 的系统级安全设置。

之后如需卸载，先退出应用，再将“应用程序”中的 `视频一键截屏拼图.app` 移入废纸篓（回收站）。已经导出的图片仍在原视频文件夹中。需要 Apple Silicon 或 Intel Mac，以及 macOS 13 或更高版本。

## 项目与反馈

- 开发者：[xao](https://github.com/ixiehao)
- 源码、下载与版本说明：[github.com/ixiehao/ShotTessera](https://github.com/ixiehao/ShotTessera)
- 反馈问题或提出建议：[创建 GitHub Issue](https://github.com/ixiehao/ShotTessera/issues/new/choose)
- 更新记录：[CHANGELOG.md](CHANGELOG.md) · 隐私承诺：[PRIVACY.md](PRIVACY.md)

## 权利与归属

- 本仓库中的 Swift 源码、文档和 Tessera Iris 图标均为本项目原创内容，按 [MIT License](LICENSE) 发布。
- 应用只使用 Apple SDK 框架；未包含第三方应用代码、依赖包、分析 SDK、网络客户端或 MoviePrint 的素材。
- 导出的标题使用随应用打包的 **Noto Sans CJK SC Bold 2.004**。该字体保持原样，采用 **SIL Open Font License 1.1**，可随商业软件嵌入与再发布；完整归属、版本和校验值见 [NOTICE.md](NOTICE.md) 与 [字体许可证](ThirdPartyLicenses/NotoSansCJK-OFL-1.1.txt)。
- 视频本身及其中已有的字幕、商标、水印和音乐等权利仍归相关权利人所有。生成分镜图并不授予发布或再分发权限。
- 请遵守适用的当地法律，并仅处理你拥有或获授权处理的视频。

以上是对本仓库源码与随附素材的工程审计，不构成针对具体视频或发行方式的法律意见。

## 许可

项目代码与原创资产使用 [MIT License](LICENSE)。随附 Noto 字体继续单独适用 [SIL Open Font License 1.1](ThirdPartyLicenses/NotoSansCJK-OFL-1.1.txt)。

欢迎参与改进，提交方式见 [CONTRIBUTING.md](CONTRIBUTING.md)；互动前请阅读 [CODE_OF_CONDUCT.md](CODE_OF_CONDUCT.md)。
