# ShotTessera

[English](README.md) · [简体中文](README.zh-CN.md) · [日本語](README.ja.md)

ShotTessera 是一款原生 macOS 分镜图工具：从视频中挑选有代表性的画面，拼成一张干净的分镜图。`tessera` 意为马赛克的小拼片，正对应本项目把镜头组织为整体的方式。

项目中文名为 **视频一键截屏拼图**，适合搜索“视频截图拼图”“视频一键截图”“分镜图生成器”“视频九宫格截图”“视频联系表”等关键词。

## 功能

- 自动识别明显的镜头变化，优先选择有面部或人物的有效画面。
- 跳过黑屏、低清晰度和近似重复的画面。
- 支持 3×3 至 8×8 分镜网格，以及 PNG、JPG 和最低 1920 px 宽度导出。
- 可一次添加多个视频，按队列顺序处理；右侧会逐张显示实时预览。
- 支持 MP4、MOV、M4V、AVI、MKV、WebM、3GP/3G2、MPEG、TS/M2TS、WMV、FLV 等常见容器。能否实际解码仍取决于当前 macOS 支持的视频编码。
- 可显示每张截图的源时间码。
- 默认不添加标题；开启“标题水印”后，使用视频文件名（不含扩展名）作为居中的半透明粗体标题。
- 输出自动保存到视频同目录，命名为 `视频名-shot-001.ext`，序号会安全递增。

所有分析和导出均在本机完成。项目不包含账号、遥测、网络请求、云上传、Electron、FFmpeg 或 Python 运行时。

## 运行

1. 使用 Xcode 15 或更高版本打开 `Package.swift`。
2. 选择 **ShotTessera** scheme，按 `⌘R` 运行。
3. 选择或拖入一个或多个视频，设置网格和导出选项后开始生成。

终端运行测试：

```sh
swift test
```

## 打包 DMG

在 Apple Silicon Mac 上运行：

```sh
./scripts/package_dmg.sh
```

会生成 `dist/视频一键截屏拼图-0.1.0.dmg`，其中包含中文名应用、图标、运行资源及全部许可证。该包使用 ad-hoc 签名校验本地完整性，但没有 Apple 公证；分发给他人后，首次打开可能需要按住 Control 点按应用并选择“打开”。

## 权利与归属

- 本仓库中的 Swift 源码、文档和 Tessera Iris 图标均为本项目原创内容，按 [MIT License](LICENSE) 发布。
- 应用只使用 Apple SDK 框架；未包含第三方应用代码、依赖包、分析 SDK、网络客户端或 MoviePrint 的素材。
- 导出的标题使用随应用打包的 **Noto Sans CJK SC Bold 2.004**。该字体保持原样，采用 **SIL Open Font License 1.1**，可随商业软件嵌入与再发布；完整归属、版本和校验值见 [NOTICE.md](NOTICE.md) 与 [字体许可证](ThirdPartyLicenses/NotoSansCJK-OFL-1.1.txt)。
- 视频本身及其中已有的字幕、商标、水印和音乐等权利仍归相关权利人所有。生成分镜图并不授予发布或再分发权限。

以上是对本仓库源码与随附素材的工程审计，不构成针对具体视频或发行方式的法律意见。

## 许可

项目代码与原创资产使用 [MIT License](LICENSE)。随附 Noto 字体继续单独适用 [SIL Open Font License 1.1](ThirdPartyLicenses/NotoSansCJK-OFL-1.1.txt)。
