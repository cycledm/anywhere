# Anywhere — install & first teleport

## 1. Sideload the IPA

Build Anywhere from source, then sideload its IPA with Feather, SideStore, AltStore, Sideloadly, or LiveContainer. [Upstream Releases](https://github.com/ChrisMack32/Locus/releases) carry the original Locus builds.

The Anywhere bundle ID is `dev.cycledm.anywhere`. iOS installs it separately from older builds that used a different bundle ID. Run setup and import your pairing file again on first launch.

### LiveContainer

File pickers often break inside LiveContainer. Do one of the following:

1. Long-press **Anywhere** in LiveContainer → **Settings** → enable **Fix File Picker**, then try Import again.
2. Share / open the pairing file **into LiveContainer → Anywhere** (iOS share sheet).

## 2. Pairing

### Reuse an existing SideStore pairing

In Anywhere, choose **Reuse SideStore pairing** in setup or Settings, then confirm the import when SideStore returns. This requires a version of SideStore that supports pairing export, including compatible LiveContainer+SideStore builds, and an active Remote Pairing record. If the callback is unavailable, choose an existing RPPairing file in the system file picker.

### On iOS 27 — no computer

1. Open Anywhere → **Settings → Pair on this iPhone** → **Start pairing**.
2. Allow **Local Network** (and Location / Notifications if asked).
3. Leave Anywhere open. Go to **Settings › Privacy & Security › Developer Mode › Pair with Host**.
4. Pick **Anywhere** → **Pair**.
5. Enter your **iPhone unlock passcode** first (authorizes pairing).
6. When the second prompt appears, type the **6-digit code** Anywhere shows (also sent as a notification).
7. Done — RPPairing file is saved on-device.

### On iOS 18–26

1. On a computer, download [idevice_pair](https://github.com/jkcoxson/idevice_pair/releases).
2. Plug in your iPhone, unlock, Trust.
3. Generate an **RPPairing** file (not lockdown / SideStore `.mobiledevicepairing`).
4. AirDrop / Share → Open in **Anywhere**, or use **Import RPPairing file** in Anywhere.

## 3. On-device loopback

Configure your network app to send traffic to `10.7.0.1:49152` back to this iPhone. On Surge iOS, enable Enhanced Mode and use the [documented IP Rewrite reflection example](https://manual.nssurge.com/features/ip-rewrite.html). For Stash or another client, use an equivalent loopback configuration if supported by that client.

Open **Settings → Loopback** in Anywhere and look for **TCP reachable**. That status confirms the port accepted a TCP connection. Teleport also requires a working RPPairing file and developer service.

## 4. Teleport

On Wi‑Fi: drop a pin → **Teleport**. Then joystick / routes / GPX work; the session can continue on cellular.

## 快捷指令模拟定位（iOS 18 或更新版本）

1. 先打开 Anywhere 完成教程、导入配对文件，并确认本机回环可用。允许通知后，快速操作的成功和失败会显示为通知。
2. 在「快捷指令」中新建一条快捷指令，打开「在共享表单中显示」，允许接收「URL」「文本」和「地图链接」。把「快捷指令输入」传给 Anywhere 的「使用地图链接模拟定位」动作。如果旧版 Anywhere 提示「无效的 URL」，可在两者之间加入「从输入中获取 URL」。
3. 如果前一个动作已提供「位置」变量，选用独立的「使用位置模拟定位」动作，直接把该变量传给「位置」。
4. 两个启动动作均可展开并填写「随机偏移半径（米）」。默认 `0`，表示使用原坐标。设置后，每次执行都会在半径内重新抽取一个位置。
5. 在 Apple 地图中打开地点详情或标记图钉，点「分享」，运行刚创建的快捷指令。高德支持带坐标的地点链接和可解析的 App 分享短链。百度支持带经纬度的地点链接，以及通过 HTTP 重定向即可取得经纬度的 HTTPS 短链。只返回地点 ID 的百度分享短链暂不支持。
6. 在「快捷指令」中运行「停止模拟定位」。

地图链接的通知显示偏移后的经纬度。位置输入提供名称时，通知显示该名称，否则显示坐标。如果来源提供有效海拔，坐标通知也会注明来源海拔。定位引擎只模拟经纬度。

## Build from source

Install [XcodeGen](https://github.com/yonaskolb/XcodeGen) and use a version of Xcode that supports the APIs used by this project. Set your Apple Developer team under Signing & Capabilities in Xcode or pass your team ID to the CLI.

```bash
xcodegen generate
open Anywhere.xcodeproj
```

```bash
xcodebuild -project Anywhere.xcodeproj -scheme Anywhere -configuration Release \
  -destination 'generic/platform=iOS' DEVELOPMENT_TEAM=YOUR_TEAM_ID build
```


## Mainland China map coordinates

**Correct Amap coordinates (GCJ-02)** is enabled by default and can be changed during first-run setup or under **Settings → Map coordinates**. In the correction area, Anywhere converts MapKit coordinates from GCJ-02 and uses WGS-84 for the coordinates sent to iOS and stored in GPX files. After changing the setting, reselect the place or rebuild the route. The approximate coverage mask uses the mainland China geometry from the public-domain [Natural Earth v5.1.2 map units](https://github.com/nvkelso/natural-earth-vector/blob/v5.1.2/geojson/ne_10m_admin_0_map_units.geojson).
