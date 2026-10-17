# 第三方素材与许可声明

本项目是 [DeepSeek-Balance-Whale-Widget](https://github.com/MeteorNOX/DeepSeek-Balance-Whale-Widget)
的 Wayland / Windows 衍生桌宠。代码与原创新增素材由 setsuna391 以 **MIT** 发布
（见 [`LICENSE`](LICENSE)）；但打包进仓库的**美术素材和音效并不都属于 MIT**。
下面是逐项说明。

> **重要**：因为包含 CC BY-NC-SA 4.0 的小克立绘，**包含全部素材的发布包
> 不得用于商业售卖**。代码部分仍是 MIT。

## 1. 上游小鲸鱼素材（as-is，不适用 MIT）

| 文件 | 来源 | 说明 |
| --- | --- | --- |
| `assets/DSniang1.png` | DeepSeek-Balance-Whale-Widget | 小鲸鱼立绘（AI 工具生成，原作者人工筛选） |
| `assets/rua.gif` | 同上 | 内置动图 |
| `assets/D1.mp3` / `D2.mp3` | 同上 | 按压 / 松开音效 |
| `assets/Ya1.mp3` / `Ya2.mp3` | 同上 | 小黄鸭音效 |
| 部分台词 / UI 文案 | 同上 | 从上游移植或改写的语句 |

上游自己的说明（原文见
[`licenses/DeepSeek-Balance-Whale-Widget-PROVENANCE.md`](licenses/DeepSeek-Balance-Whale-Widget-PROVENANCE.md)）：

> `assets/**`（图片 / 动图 / 音效）不适用 MIT：由维护者提供或使用 AI 工具生成，
> 按 **as-is** 随插件分发，仅用于运行本插件；不授予再许可，也不声明为原创作品。

版权归原作者 [MeteorNOX](https://github.com/MeteorNOX) 所有。本项目仅为运行桌宠
而随包分发这些文件，**不对此类素材授予任何额外许可**。若权利人不希望它们出现在
本仓库或发布包中，请开 Issue，我们会立即替换或移除。

## 2. 小克立绘（CC BY-NC-SA 4.0）

| 文件 | 来源 | 许可 | 改动 |
| --- | --- | --- | --- |
| `assets/characters/xiaoke.png` | [dsh-xiaoke-widget](https://github.com/aklnaaw/dsh-xiaoke-widget)（aklnaaw） | **CC BY-NC-SA 4.0** | 仅从 `xiaoke1.png` 重命名，像素未改 |

- 署名：小克立绘来自 dsh-xiaoke-widget / aklnaaw
- 协议：<https://creativecommons.org/licenses/by-nc-sa/4.0/legalcode.zh-hans>
- 离线全文：[`licenses/CC-BY-NC-SA-4.0.txt`](licenses/CC-BY-NC-SA-4.0.txt)
- 非商业性使用；再分发需署名并以相同协议共享。详见
  [`LICENSE-ARTWORK.md`](LICENSE-ARTWORK.md)。

## 3. GPT娘立绘（MIT，按来源项目声明）

| 文件 | 来源 | 许可 | 改动 |
| --- | --- | --- | --- |
| `assets/characters/gptniang.png` | [dsh-gpt-niang-widget](https://github.com/xixingyingmie/dsh-gpt-niang-widget)（xixingyingmie） | MIT（见该项目 PROVENANCE） | 伽马 0.65、饱和度 108%、轻度锐化 |

- 原项目声明：该立绘由项目发起人提供，规范化后随仓库按 MIT 分发。
- 本项目对图片做了色彩/锐度调整，代码仍按 MIT 分发；原始文件与来源说明见
  [`licenses/dsh-gpt-niang-widget-PROVENANCE.md`](licenses/dsh-gpt-niang-widget-PROVENANCE.md)。

## 4. Electron / Chromium（Windows 便携包）

Windows 便携包内含 Electron 运行时。Electron 以 MIT 许可发布，Chromium 及其
依赖的许可文本随包提供（`LICENSE`、`LICENSES.chromium.html`）。本项目不修改
Electron/Chromium 本身。

## 5. 字体

本项目不捆绑字体，界面使用系统字体（优先 `LXGW WenKai`，Windows 上回退到
`Microsoft YaHei` 等）。字体许可由系统提供方负责。

## 6. 发布包类型

| 发布物 | 内容 | 许可组合 |
| --- | --- | --- |
| `quickshell-whale-pet-*.tar.gz` / `.zip` | Linux/Quickshell 源码 + 素材 | 代码 MIT；小克 CC BY-NC-SA 4.0；上游素材 as-is |
| `DSH-Pet-win32-x64.zip` | Windows 便携版 + Electron 运行时 | 同上 + Electron MIT |

再次提醒：**不要将包含小克立绘的发布包用于商业售卖**。
