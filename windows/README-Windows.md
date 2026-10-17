# DSH 桌面宠物 · Windows 11 便携版

解压后双击 `DSH-Pet.exe` 即可,不需要安装,也不需要 Node.js / Electron 环境。

## 首次运行

- 配置: `%APPDATA%\dsh-pet\config.json`(首次运行自动生成)
- 位置: `%APPDATA%\dsh-pet\state.json`
- 日志: `%APPDATA%\dsh-pet\app.log`
- 未签名程序,SmartScreen 提示时点「更多信息 → 仍要运行」。
- 退出请用托盘图标菜单;直接关窗口只会隐藏。

## 操作

| 操作 | 效果 |
| --- | --- |
| 左键点宠物 | Q 弹 + 音效 + 随机台词气泡 |
| 再点气泡 | 换一段台词 |
| 右键宠物 | 峰谷 + 各家余额 |
| 拖拽 | 水平移动,左右边缘吸附并镜像;位置自动记忆 |
| 中键点宠物 | 循环换模型 |
| 托盘右键 | 换模型 / 音效 / 自言自语 / 打开配置 / 退出 |

## 换模型 / 配置

编辑 `%APPDATA%\dsh-pet\config.json` 的 `model` 和 `models` 列表,保存后约 1–2 秒
生效;也可以从托盘菜单切换。余额 key 建议放 `%APPDATA%\dsh-pet\api_key`
(DeepSeek)、`openrouter_key`、`siliconflow_key`,不要把 key 提交到仓库。

`screen` 可填显示器序号(0 = 主屏)或显示器名称片段;留空使用主屏。

## 许可

- 代码: MIT(见 `licenses/LICENSE-DSH-PET.txt`;根目录 `LICENSE` 是 Electron 自带的)
- 小克立绘: CC BY-NC-SA 4.0(非商用、署名、同协议共享,见 `LICENSE-ARTWORK.md`)
- GPT娘立绘: MIT(按来源项目声明)
- 上游小鲸鱼素材/音效: as-is,不适用 MIT,版权归 MeteorNOX
- Electron / Chromium: MIT,许可文本随包提供

因为包含小克立绘,**本发布包不得用于商业售卖**。完整说明见 `THIRD_PARTY_NOTICES.md`。

上游/来源项目:

- https://github.com/MeteorNOX/DeepSeek-Balance-Whale-Widget
- https://github.com/aklnaaw/dsh-xiaoke-widget
- https://github.com/xixingyingmie/dsh-gpt-niang-widget
- https://github.com/setsuna391/quickshell-whale-pet
