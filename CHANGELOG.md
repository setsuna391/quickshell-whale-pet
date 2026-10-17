# Changelog

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
