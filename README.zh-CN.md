# Anywhere

[English](README.md) / **简体中文**

Anywhere 是一款适用于 iPhone 和 iPad 的模拟定位工具，基于 [ChrisMack32/Locus](https://github.com/ChrisMack32/Locus) 二次开发。它通过 Apple 的开发者定位服务修改 iOS 和 iPadOS 报告的位置。

这个 fork 加入了快捷指令、SideStore 配对导入、简体中文本地化，以及面向中国大陆的高德坐标修正。回环连接可以通过兼容的网络工具配置。

## 功能

- 在地图上选点或搜索地点，设为模拟位置。
- 用摇杆移动，沿步行或驾车路线前进，也可以手绘路线、导入或导出 GPX。
- 收藏地点，或从最近记录回到之前模拟过的位置。
- 通过快捷指令传入「位置」，或使用受支持的 Apple 地图、高德地图和百度地图链接启动模拟。两种启动方式都支持以米为单位的随机偏移，也可以用独立的动作停止模拟。
- 沿用兼容版本的 SideStore 配对、手动导入 RPPairing 文件，或在系统支持时直接在设备上配对。

## 使用前准备

首个版本发布后，可在 SideStore 或 AltStore Classic 中添加 [Anywhere 订阅源（raw JSON）](https://raw.githubusercontent.com/cycledm/anywhere/main/source.json)，用于安装和接收更新。

Anywhere 支持 iOS 18 和 iPadOS 18 或更新版本。开始模拟前，需要完成设备配对并配置本机回环连接。配对方式、网络配置和快捷指令的具体步骤见[设置指南](SETUP.md)。

## 本地构建

在 macOS 上安装 Xcode 和 [XcodeGen](https://github.com/yonaskolb/XcodeGen)，然后在仓库根目录生成并打开项目。

```bash
xcodegen generate
open Anywhere.xcodeproj
```

选中 **Anywhere** target，在 **Signing & Capabilities** 中选择你的 Apple Developer 团队，再选中已连接的设备构建并运行。也可以在命令行中构建签名版本，将 `YOUR_TEAM_ID` 替换为自己的 Apple Developer 团队 ID。

```bash
xcodebuild -project Anywhere.xcodeproj -scheme Anywhere -configuration Release \
  -destination 'generic/platform=iOS' DEVELOPMENT_TEAM=YOUR_TEAM_ID build
```

默认 Bundle ID 为 `dev.cycledm.anywhere`。

## 许可证

Anywhere 采用 [MIT 许可证](LICENSE)。项目内附的 [idevice](https://github.com/jkcoxson/idevice) 库同样采用 MIT 许可。许可证文件也保留了改编自 coordtransform 的坐标换算代码的署名。
