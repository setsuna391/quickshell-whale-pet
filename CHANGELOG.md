# Changelog

## v1.1.1 — 2026-10-17

### 修复

- Linux/QML:按显示尺寸和 DPR 选择 Lanczos 预缩放立绘(`assets/scaled/`),解决
  610px 源图被 GPU 直接缩小导致的发虚;新增 `tools/gen-scaled.sh`
- `model.sh` 自动排除 `assets/scaled/` 变体,避免出现在模型列表里

Windows 包一并重建,功能与 v1.1.0 相同。

## v1.1.0 — 2026-10-17

### 新增

- 多模型支持:小鲸鱼 / 小克 / GPT娘,`models` 列表可配置
- 中键循环换装;`model.sh`(`list` / `next` / 名字 / 路径)
- Quickshell IPC:`setModel` / `getModel` / `nextModel` / `listModels` / `say`
- **Windows 11 Electron 便携版**(实验性):置顶、透明点击穿透、水平拖拽吸附、
  气泡/音效/余额/托盘换模型
- 许可合规:`LICENSE-ARTWORK.md`、`THIRD_PARTY_NOTICES.md`、`licenses/` 原文
- 配置热更新改用 FileView + 2 秒 reload 兜底(兼容 Nix 软链替换)

### 修复 / 优化

- `idleTalkMinutes` 修改后不再失效
- 关闭 `mipmap` 后正常尺寸更锐利(小尺寸 <0.8 仍保留抗锯齿)
- 图片按比例显示(`PreserveAspectFit`),非正方形立绘不拉伸
- 余额 key 不再出现在命令行参数;支持 `openrouter_key` / `siliconflow_key`
- 余额刷新保留旧值,识别 401/403/429/网络失败
- 气泡隐藏时不再挡住下层窗口点击
- 声音播放器启动时探测一次;贴边逻辑复用 `resnap()`
- 默认配置补 `screen`;`run.sh` 按脚本目录解析路径
- GPT娘立绘调整伽马/饱和度并锐化;移除过时截图

## v1.0.0 — 2026-09

- 首个版本:Quickshell/niri 小鲸鱼桌宠,余额、峰谷提示、台词、音效、拖拽吸附
