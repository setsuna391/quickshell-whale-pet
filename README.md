# DSH 小鲸鱼桌面宠物

> [!IMPORTANT]
> **原项目**:[DeepSeek-Balance-Whale-Widget](https://github.com/MeteorNOX/DeepSeek-Balance-Whale-Widget)
> **原作者**:[MeteorNOX](https://github.com/MeteorNOX)
> 本项目是原项目的 Wayland / Windows 桌面宠物衍生版。立绘、rua.gif、音效与部分台词
> 来自原项目,版权归原作者所有,感谢!
>
> **许可提醒**:代码是 MIT;小克立绘是 **CC BY-NC-SA 4.0(非商用)**;上游美术素材
> 为 as-is,不适用 MIT。包含全部素材的发布包不可商业售卖。详见
> [`THIRD_PARTY_NOTICES.md`](THIRD_PARTY_NOTICES.md) 和 [`LICENSE-ARTWORK.md`](LICENSE-ARTWORK.md)。

两种实现:

- **Linux / Wayland**:Quickshell layer-shell 版,常驻置顶、无边框,适配 niri(其他
  wlroots 系合成器理论上可用)。
- **Windows 11**:Electron 便携版,免安装,解压双击即用(实验性适配,见下文)。

## 快速开始

### Linux / Wayland

依赖:Quickshell(Qt 6)、支持 `wlr-layer-shell` 的合成器、PipeWire(`pw-play`)或
`ffplay` / `paplay`。

```sh
git clone https://github.com/setsuna391/quickshell-whale-pet.git
cd quickshell-whale-pet
./run.sh            # 启动(已启动则跳过)
./run.sh stop       # 退出
./run.sh restart    # 重启
```

### Windows 11

1. 从 [Releases](https://github.com/setsuna391/quickshell-whale-pet/releases/latest)
   下载 `DSH-Pet-1.1.0-win32-x64.zip`。
2. 解压到任意目录,双击 `DSH-Pet.exe`。
3. 首次运行会在 `%APPDATA%\dsh-pet\config.json` 生成配置;托盘图标可换模型 / 开关音效 / 退出。
4. 未签名程序,SmartScreen 提示时选「更多信息 → 仍要运行」。

> Windows 版是 Electron 重写的实验性适配:窗口置顶、透明点击穿透、拖拽吸附、
> 气泡/音效/余额/托盘换模型均已接好,但尚未在 Win11 实机长期验证,欢迎反馈。

## 交互

| 操作 | 效果 |
| --- | --- |
| 左键点宠物 | Q 弹 + 音效(按下/松开两声)+ 随机台词气泡(5 秒自动收起) |
| 再点气泡 | 换一段随机台词 |
| 右键宠物 | 峰谷时段 + 各家余额气泡(有气泡时先关闭) |
| 拖拽 | 水平移动,靠近左/右边缘自动吸附;吸到左边整体镜像;位置自动记忆 |
| 中键点宠物 | 在模型列表里循环换装 |
| 托盘菜单(Windows) | 换模型、音效、自言自语、打开配置、退出 |

## 换模型

Linux:

```sh
./model.sh              # 查看当前模型和可用模型
./model.sh next         # 切换到下一个
./model.sh xiaoke       # 按名字模糊匹配(小克)
./model.sh gptniang     # GPT娘
./model.sh default      # 换回小鲸鱼
./model.sh characters/xxx.png   # 相对 assets/ 或绝对路径
```

选择会写入 `config.json` 并立即通知运行中的宠物;若 config 是 Nix 只读软链,则只对
当前实例生效。也可以直接走 IPC:

```sh
qs ipc -p /path/to/quickshell-whale-pet call dsh-pet setModel characters/xiaoke.png
qs ipc -p /path/to/quickshell-whale-pet call dsh-pet getModel
```

niri 键位示例(按 `Mod+M` 换下一个):

```kdl
Mod+M { spawn "sh" "-c" "/path/to/quickshell-whale-pet/model.sh next"; }
```

Windows:中键点宠物,或右键托盘图标 →「换模型」。托盘菜单会读取 `models` 列表。

把新图片丢进 `assets/` 或 `assets/characters/` 即可(`model.sh list` 会自动发现;
Windows 版改 `models` 数组后重启或托盘「重新读取配置」)。

## 配置

| 平台 | 路径 |
| --- | --- |
| Linux | `~/.config/dsh-pet/config.json`(若由 Nix home-manager 管理,可能是只读软链) |
| Windows | `%APPDATA%\dsh-pet\config.json` |

保存后约 2 秒内热更新(Linux 用 FileView/轮询,Windows 用文件监听),不用重启:

```json
{
  "scale": 1.0,             // 缩放 0.6 – 2.5
  "sound": true,            // 音效开关
  "soundSet": "duck",       // duck = 小黄鸭(Ya1/Ya2), fx1 = 音效1(D1/D2)
  "volume": 1.0,            // 音效音量 0 – 1
  "model": "DSniang1.png",  // 当前立绘(assets 下文件名,或绝对路径)
  "models": [               // 中键 / model.sh next 的循环顺序
    "DSniang1.png",
    "characters/xiaoke.png",
    "characters/gptniang.png"
  ],
  "bubbleScale": 1.3,       // 气泡大小 0.8 – 2.5
  "edgePad": 3,             // 窗口左右内衬 px
  "snapZone": 0.22,         // 左右吸附区占屏幕宽度的比例
  "idleTalk": true,         // 发呆自言自语
  "idleTalkMinutes": 5,     // 平均间隔(分钟,实际随机 ±50%)
  "idleTalkChance": 0.4,    // 每次触发说话的概率 0 – 1
  "screen": "DP-2"          // Linux:输出名(niri msg outputs);Windows:显示器序号或名称;留空 = 主屏
}
```

位置记忆:Linux 在 `~/.config/dsh-pet/state.json`;Windows 在
`%APPDATA%\dsh-pet\state.json`,由拖拽自动写入,不用手改。

### 多家余额(可选)

`config.json` 的 `balance` 数组:

```json
"balance": [
  { "name": "DeepSeek",   "type": "deepseek",    "apiKey": "" },
  { "name": "OpenRouter", "type": "openrouter",  "apiKey": "" },
  { "name": "硅基流动",    "type": "siliconflow", "apiKey": "" }
]
```

- **不要把 key 写进 Nix 配置**:`/nix/store` 全局可读,旧 generation 会一直保留。
- 建议 `apiKey` 留空,改用 key 文件或环境变量;key 文件建议 `chmod 600`。
- 文件名(Linux 在 `~/.config/dsh-pet/`,Windows 在 `%APPDATA%\dsh-pet\`):
  - `deepseek` → `api_key`,或 `DEEPSEEK_API_KEY`
  - `openrouter` → `openrouter_key`,或 `OPENROUTER_API_KEY`;余额 = 总额度 - 已用
  - `siliconflow` → `siliconflow_key`,或 `SILICONFLOW_API_KEY`
- 右键宠物查看余额,每 60 秒刷新;刷新时保留上一次数值。
- 全都不配置也不影响其他功能,余额台词会变成随机卖萌文案。

## 开机自启

### Linux(systemd user service 示例)

```ini
# ~/.config/systemd/user/dsh-pet.service
[Unit]
Description=DSH desktop pet (quickshell)
After=graphical-session.target
PartOf=graphical-session.target

[Service]
Type=exec
ExecStart=/path/to/quickshell-whale-pet/run.sh
Restart=on-failure
RestartSec=5

[Install]
WantedBy=graphical-session.target
```

```sh
systemctl --user enable --now dsh-pet.service
```

NixOS / home-manager 用户可以把配置文件声明成 `xdg.configFile."dsh-pet/config.json"`,
并用 `systemd.user.services` 管理进程;注意配置文件只读时 `model.sh` 只能临时切换。

### Windows 11

把 `DSH-Pet.exe` 的快捷方式放进 `shell:startup`(`Win+R` → 输入 `shell:startup`)。
退出请用托盘菜单,直接关闭窗口只会隐藏。

### Linux 清晰度

Qt Quick 直接把 610px 源图缩到 170px 会发虚。Linux 版在发布前用 Lanczos 预缩放
到常见尺寸,存放在 `assets/scaled/`,QML 会根据 `scale` 和屏幕 DPR 自动选最接近的
一档,避免 GPU 直接缩小。

新增模型后,若要同样的清晰度:

```sh
tools/gen-scaled.sh      # 需要 ImageMagick,然后一起提交 assets/scaled/
```

Windows/Electron 版由 Chromium 处理缩放,不需要这些预缩放图。

## 构建 Windows 便携包

需要 `curl`、`unzip`、`zip`(Linux / macOS / WSL 均可):

```sh
windows/build-win.sh            # 默认 Electron 44.8.0
windows/build-win.sh 44.8.0     # 指定版本
```

产物在 `windows/dist/DSH-Pet-1.1.0-win32-x64.zip`。脚本会从 npmmirror 下载 Electron
(失败时回退 GitHub Releases),把 `resources/app` 替换成本项目并打包素材与许可文件。

## 文件结构

```
quickshell-whale-pet/
├── shell.qml              # Linux/Wayland 宠物本体
├── run.sh                 # Linux 启动器
├── model.sh               # 快捷换模型
├── assets/                # 立绘 / rua.gif / 音效 / characters/ / scaled/
├── tools/gen-scaled.sh    # 生成 Lanczos 预缩放立绘(Linux 清晰度)
├── windows/               # Windows 11 Electron 便携版
│   ├── main.js            # 窗口、点击穿透、拖拽吸附、余额、托盘
│   ├── preload.js
│   ├── shared.js          # 两边共用的布局公式
│   ├── renderer/          # 气泡 / 台词 / 交互
│   └── build-win.sh
├── licenses/              # 上游与第三方许可/来源原文
├── LICENSE                # 代码 MIT(含适用范围说明)
├── LICENSE-ARTWORK.md     # 小克 CC BY-NC-SA 4.0
├── THIRD_PARTY_NOTICES.md # 素材逐项说明
└── README.md
```

## 许可与致谢

- **代码**:[MIT](LICENSE),© 2026 setsuna391。
- **小克立绘**(`assets/characters/xiaoke.png`):来自
  [dsh-xiaoke-widget](https://github.com/aklnaaw/dsh-xiaoke-widget),
  **CC BY-NC-SA 4.0**(署名、非商用、同协议共享)。像素未改,仅重命名。
- **GPT娘立绘**(`assets/characters/gptniang.png`):来自
  [dsh-gpt-niang-widget](https://github.com/xixingyingmie/dsh-gpt-niang-widget),
  按该项目 PROVENANCE 声明为 MIT;本仓库版本做了伽马 / 饱和度 / 锐化调整。
- **上游小鲸鱼素材**(`DSniang1.png`、`rua.gif`、`D1/D2/Ya1/Ya2.mp3` 及部分文案):
  来自 [DeepSeek-Balance-Whale-Widget](https://github.com/MeteorNOX/DeepSeek-Balance-Whale-Widget),
  © 2026 MeteorNOX。上游明确说明 `assets/**` **不适用 MIT**,按 as-is 随插件分发、
  不授予再许可;本项目为运行桌宠而随包包含,权利仍归原作者。
- **Electron / Chromium**:MIT,随 Windows 包附带各自的许可文本。
- 完整说明与 takedown 方式见 [`THIRD_PARTY_NOTICES.md`](THIRD_PARTY_NOTICES.md)。

> 因为包含 CC BY-NC-SA 4.0 的小克立绘,**包含全部素材的发布包不得用于商业售卖**。
> 代码本身仍是 MIT;如果只需要宽松许可,可删除 `assets/characters/xiaoke.png`
> 并从 `models` 移除。
