# 航拍影院 · Aerial Cinema

**让苹果的 4K 航拍，成为你的心流空间。**<br>
**Turn Apple’s 4K aerials into a space for flow.**

苹果自带的 4K 航拍实在太棒了。航拍影院把这些已经下载到 Mac 的城市、海岸与山川，变成安静、流动的全屏工作背景。让好风景物尽其用，也给专注留一个心流空间。

Apple’s 4K aerials deserve more screen time. Aerial Cinema turns the scenery already downloaded on your Mac into a quiet, moving backdrop for work. Let cities, coastlines, and landscapes drift across your screens—and give yourself a little space to find your flow.

<img src="Resources/IconSource.png" width="144" alt="航拍影院 · Aerial Cinema">

**[下载 Mac 版 · Download for Mac](https://github.com/channelchoi/aerial-cinema/releases/latest)** · [代码许可 · Code license](LICENSE)

Apple Silicon · macOS 14+ · 原生 Mac 应用 / Native macOS app

## 打开风景，进入状态 / Set the scene for focus

| 中文 | English |
| --- | --- |
| **打开即全屏。** 隐藏鼠标、菜单栏、程序坞和播放控件，把画面留给风景。 | **Open straight into the scenery.** Fullscreen video, with the cursor, menu bar, Dock, and playback controls out of sight. |
| **多屏同景。** 所有显示器同步播放同一段视频，按各屏幕比例铺满画面。 | **One view across your screens.** The same video plays in sync on every display, scaled to fill each screen. |
| **一直流动。** 每轮随机排列、轮内不重复，播完后继续循环。 | **Keep the scenery moving.** A shuffled playlist plays every video once per round, then keeps looping. |
| **知道身在何处。** 左下角两行小字，上中文、下英文，标明城市与国家。 | **Know where you are.** A small, two-line label shows the city and country in Chinese and English. |
| **从容退出。** 长按 Esc 5 秒；地点文字淡出、小圆环淡入。松手取消，地点平滑回来。 | **Leave with a deliberate hold.** Hold Esc for 5 seconds. The location label fades into a small progress ring; release early to cancel and bring the label back. |
| **用好已有素材。** 直接读取本地航拍视频，之后下载的新视频也会自动加入。 | **Make more of your local library.** Videos play directly from your Mac, and new downloads join the rotation automatically. |

## 开始使用 / Get started

1. 在「系统设置 → 墙纸」中下载喜欢的航拍视频。<br>Download your favorite aerial videos in **System Settings → Wallpaper**.
2. [下载应用压缩包](https://github.com/channelchoi/aerial-cinema/releases/latest)，解压后将「航拍影院.app」放入「应用程序」。<br>[Download the app](https://github.com/channelchoi/aerial-cinema/releases/latest), unzip it, and move **航拍影院.app** to **Applications**.
3. 双击打开。视频会在所有显示器上静音、随机、循环播放。<br>Open the app. Your aerials play silently on every display in a continuous shuffled loop.
4. 需要切回工作窗口时，按 **Command+Tab**；航拍继续播放。需要退出影院时，持续按住 **Esc 5 秒**。<br>Use **Command+Tab** to return to your work while the scenery keeps playing. To quit Aerial Cinema, **hold Esc for 5 seconds**.

发布包适用于 Apple Silicon Mac，最低目标为 macOS 14，本机实测 macOS 27.2。应用采用临时签名，尚未经过 Apple 公证；首次打开时，macOS 可能要求在「隐私与安全性」中手动允许。

The downloadable build is for Apple Silicon Macs and targets macOS 14 or later. It has been tested on macOS 27.2. The app is ad-hoc signed and has not been notarized by Apple; macOS may ask you to allow the first launch in **Privacy & Security**.

## 几个小细节 / A few thoughtful details

- 地点文字距左边和下边各 24 点，中文 12 点、英文 10 点，白色轻微阴影、无底板。<br>The label sits 24 points from the left and bottom edges: 12-point Chinese and 10-point English, in white with a subtle shadow and no background panel.
- 文字与圆环以 0.25 秒交叉淡化。快速反复按键会从当前透明度平滑反向过渡，退出计时始终从按下 Esc 开始。<br>The label and ring crossfade over 0.25 seconds. Rapid presses reverse smoothly from the current opacity; the exit timer always starts when Esc is pressed.
- 长按期间切换视频不会中断计时；取消后，显示的是新视频的地点。<br>A video change during a hold does not reset the timer. Canceling restores the new video’s location.
- 新下载的视频每 30 秒检查一次，经稳定性和格式检查后加入，通常需要 30–60 秒。<br>The library is checked every 30 seconds. New downloads join once their files are stable and playable, usually within 30–60 seconds.
- 播放时阻止系统因闲置自动熄屏，退出后释放这一限制。<br>The app keeps the displays awake during playback and releases that request when it exits.

## 地点与素材 / Locations & video library

地点按系统目录中的视频标识匹配。目前支持纽约、旧金山、洛杉矶、伦敦、迪拜和香港的中英文城市与国家名称；同一城市的新镜头可自动匹配。未识别的视频显示「地点未知 / Location unknown」，继续正常播放。

Locations are matched by video ID in Apple’s local catalog. Translations currently cover New York, San Francisco, Los Angeles, London, Dubai, and Hong Kong, including additional shots from those cities. Unrecognized videos show **地点未知 / Location unknown** and continue playing normally.

系统设置显示的航拍数量是所选轮换组的项目数，不代表每个视频都已下载。程序只播放本机已有的完整视频；损坏或无法解码的文件会跳过，全部不可用时先恢复桌面，再显示说明。

The aerial count in System Settings describes the selected rotation group, not the number of completed downloads. The app plays complete local files, skips damaged or unplayable ones, and restores the desktop before showing an explanation if none can play.

<details>
<summary>开发与验证 · Build & validation</summary>

### 构建 / Build

需要 Apple Silicon Mac、macOS 14+ 和 Xcode Command Line Tools。正式应用无需额外播放器或运行环境。

Building requires an Apple Silicon Mac, macOS 14+, and Xcode Command Line Tools. The finished app needs no additional player or runtime.

```sh
./build.sh
```

输出为 `build/航拍影院.app`，使用本机临时签名，不自动覆盖已安装的应用。

The ad-hoc signed app is written to `build/航拍影院.app`. Building does not replace an installed copy.

### 测试 / Tests

```sh
./test.sh          # 核心测试 / Core tests
./test.sh --media  # 本地视频与目录测试 / Local media and catalog tests
./build.sh --qa    # 独立测试版 / Separate QA build
```

媒体测试还需已下载的航拍视频、Python 3 和 `ffmpeg`，这些仅为测试依赖。测试版每段预览 5 秒，3 分钟后自动结束；可用 `AERIAL_QA_DIR`、`AERIAL_QA_LOG`、`AERIAL_QA_CLIP_SECONDS`、`AERIAL_QA_TIMEOUT` 调整。默认日志为系统临时目录中的 `aerial-cinema-qa.log`。正式版不包含这些测试入口或运行时日志。

Media tests also require downloaded aerials, Python 3, and `ffmpeg`; the app itself does not. The QA build previews each clip for 5 seconds and exits after 3 minutes. Configure it with `AERIAL_QA_DIR`, `AERIAL_QA_LOG`, `AERIAL_QA_CLIP_SECONDS`, and `AERIAL_QA_TIMEOUT`. Its default log is `aerial-cinema-qa.log` in the system temporary directory. These test controls and runtime logs are excluded from the release build.

### 素材位置 / Video locations

程序直接读取以下目录，不复制或改写系统视频。

The app reads these directories directly, without copying or modifying the system videos.

```text
~/Library/Application Support/com.apple.wallpaper/aerials/videos
/Library/Application Support/com.apple.idleassetsd/Customer/4KSDR240FPS
```

### 验证范围 / Validation

已在 macOS 27.2 上检查双屏播放、11 个视频的双语地点、随机循环、长按退出、快速反复按键，以及切换视频后取消退出。播放器使用共同系统时钟安排进度，并对超过 60 毫秒的偏差重新对齐；不同刷新率显示器不保证逐帧一致。物理热插拔、真实休眠唤醒及其他系统版本尚未全面实测。

Testing on macOS 27.2 covers two-display playback, bilingual labels for 11 videos, shuffled looping, hold-to-exit, rapid key presses, and canceling a hold across a video change. Playback is scheduled against a shared system clock and realigned when drift exceeds 60 milliseconds; displays with different refresh rates are not guaranteed to show identical frames. Physical hot-plugging, actual sleep/wake, and other macOS versions have not been comprehensively tested.

</details>

## 开源与素材许可 / Code & artwork

代码与文档采用 [MIT 许可](LICENSE)。图标包含「心流」字样与无脸男形象，不在 MIT 授权范围内，详见 [NOTICE](NOTICE)。苹果航拍视频不随项目或下载包分发。

Code and documentation are [MIT licensed](LICENSE). The icon, featuring the Chinese lettering “心流” and No-Face, is excluded from that license; see [NOTICE](NOTICE). Apple aerial videos are not distributed with the repository or app download.
