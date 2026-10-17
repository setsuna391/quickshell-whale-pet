// DSH 小鲸鱼桌面宠物 —— quickshell 版
// 参考 DeepSeek-Balance-Whale-Widget 移植到 niri/Wayland
// 运行: ~/Documents/project/quickshell-whale-pet/run.sh
// 配置: ~/.config/dsh-pet/config.json(保存后即时生效,无需重启)

import QtQuick
import QtQuick.Shapes
import Quickshell
import Quickshell.Io
import Quickshell.Wayland

ShellRoot {
    id: root

    PanelWindow {
        id: win

        // ---- 可调配置(由 config.json 热更新,见底部 configView) ----
        property real petScale: 1.0          // 缩放 0.6 – 2.5
        property bool soundOn: true          // 音效开关
        property string soundSet: "duck"     // duck = 小黄鸭(Ya), fx1 = 音效1(D)
        property int edgePad: 3              // 窗口左右内衬 px,越小贴边越紧
        property real snapZone: 0.22         // 左右吸附区占屏幕宽度的比例
        property bool idleTalk: true         // 发呆自言自语
        property int idleTalkMinutes: 5      // 自言自语间隔(分钟)
        property real idleTalkChance: 0.4    // 每次触发说话的概率
        property real idleInterval: 300000   // 下一次自言自语的实际间隔(随机化后)
        property real volume: 1.0            // 音效音量 0 – 1
        property string model: "DSniang1.png" // 角色立绘(assets 下文件名,或绝对路径)
        property bool modelFallback: false   // 预缩放图缺失时回退原图
        readonly property var scaledSizes: [102, 136, 170, 204, 255, 340, 425, 510, 640, 850]
        property string audioPlayer: ""      // 启动时探测到的音频播放器
        property real bubbleScale: 1.3       // 气泡大小(相对鲸鱼宽度,0.8 – 2.5)
        property string screenName: ""       // 显示在哪个输出(如 "DP-2");空 = 默认屏
        // 中键循环换装用的模型列表(脚本/IPC 可切换到任意图片)
        property var modelChoices: ["DSniang1.png", "characters/xiaoke.png", "characters/gptniang.png"]

        // ---- 气泡(复刻上游 SVG 模板) ----
        readonly property color bubbleFill: "#ffffff"
        readonly property color bubbleStroke: "#203170"
        readonly property color bubbleText: "#536ba9"
        readonly property color bubbleMuted: "#9fb0d9"
        readonly property real bubbleStrokeW: 18
        // 上游 1026x700 画布中的图形 path (原样)
        readonly property string bubblePathMain: "M 827 248 A 373 232 0 1 0 81 246 A 373 232 0 0 0 301 465 A 57 32 10 0 0 413 484 A 373 232 0 0 0 827 248 Z"
        readonly property string bubblePathDot1: "M 314.5 561 a 37.5 26 0 1 0 75 0 a 37.5 26 0 1 0 -75 0 Z"
        readonly property string bubblePathDot2: "M 417.5 646 a 24.5 18 0 1 0 49 0 a 24.5 18 0 1 0 -49 0 Z"

        // ---- 窗口几何 ----
        readonly property int baseW: 170
        readonly property int whaleW: Math.round(baseW * petScale)
        readonly property int whaleH: Math.round(baseW * petScale)
        // 气泡相对"鲸鱼宽度"的放大系数(窗口加宽让气泡向屏幕内侧生长,鲸鱼仍贴边)
        readonly property real bubbleArtScale: (whaleW + edgePad * 2) * bubbleScale / 790
        readonly property int bubbleArtH: Math.round(690 * bubbleArtScale)
        readonly property int whaleTop: Math.max(216, bubbleArtH + 16)   // 上方留给气泡
        implicitWidth: Math.round((whaleW + edgePad * 2) * bubbleScale)
        implicitHeight: whaleH + whaleTop

        // 目标输出:按输出名选屏(如 "DP-2");名字为空或没找到时回落到第一个屏
        screen: win.pickScreen()
        onModelChanged: win.modelFallback = false
        onWhaleWChanged: win.modelFallback = false
        readonly property real screenDpr: win.screen ? win.screen.devicePixelRatio : 1
        onScreenDprChanged: win.modelFallback = false

        color: "transparent"
        visible: win.bootReady                       // 配置+位置就绪后才出现,首帧即正确大小
        anchors { bottom: true; left: true }
        exclusionMode: ExclusionMode.Ignore
        WlrLayershell.layer: WlrLayer.Top
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
        WlrLayershell.namespace: "dsh-pet"

        // ---- 状态 ----
        property int petX: -1              // 窗口左缘在屏幕上的位置
        property bool mirrored: false      // 吸附左边时水平镜像
        property bool dragging: false
        property bool moved: false
        property real sqx: 1               // 按压挤压系数
        property real sqy: 1
        property bool bubbleVisible: false
        property bool bubbleGif: false
        property var bubbleLines: []
        // ---- 多家余额 ----
        property var balanceSources: [{ name: "DeepSeek", type: "deepseek", apiKey: "" }]
        property var balanceResults: [{ name: "DeepSeek", amount: "--", currency: "", ok: false, err: false }]
        property int balanceCursor: 0
        property string balanceSig: ""
        property var balSrc: null      // 当前请求对应的余额源
        property int balIdx: -1        // 当前请求对应的结果槽位
        // ---- 吸附 / 启动状态 ----
        property bool snapRight: false               // 吸附在右边缘
        property bool cfgReady: false                // 启动就绪门:配置已加载
        property bool stateReady: false              // 启动就绪门:位置已加载
        readonly property bool bootReady: cfgReady && stateReady
        property bool placeRight: false              // 鲸鱼停在窗口左缘还是右缘(仅静止时刻更新)

        readonly property string cfgDir: Quickshell.env("HOME") + "/.config/dsh-pet"
        readonly property real screenW: win.screen ? win.screen.width : 1920
        // 鲸鱼是否在屏幕右半边(决定气泡朝向;纯位置判断,不依赖任何标记)
        readonly property bool whaleRight: petX >= 0 && petX + width / 2 > screenW / 2
        readonly property string assetDir: Qt.resolvedUrl("assets/").toString().replace(/^file:\/\//, "")

        margins.left: petX
        Behavior on petX {
            enabled: !win.dragging
            NumberAnimation { duration: 260; easing.type: Easing.OutCubic }
        }
        // 任何宽度变化(开关聊天面板/改缩放)都按吸附状态强制贴边,天然免疫时序竞态
        onWidthChanged: win.resnap()
        // 换屏后新屏幕宽度不同,按吸附状态重新贴边
        onScreenChanged: win.resnap()

        function clampX(x) {
            return Math.max(0, Math.min(win.screenW - win.width, Math.round(x)));
        }
        function resnap() {
            if (petX < 0 || dragging) return;
            if (snapRight) petX = screenW - width;
            else if (mirrored) petX = 0;
            else petX = clampX(petX);
        }

        // 按输出名选屏(如 "DP-2");名字为空或没找到时用第一个屏,保持原有默认行为
        function pickScreen() {
            const list = Quickshell.screens;
            if (win.screenName.length > 0) {
                for (let i = 0; i < list.length; i++)
                    if (list[i].name === win.screenName) return list[i];
            }
            return list.length > 0 ? list[0] : null;
        }

        // ---------- 台词 ----------
        function isPeak() {
            const d = new Date();
            if (d.getDay() === 0 || d.getDay() === 6) return false; // 周末全天谷价
            const h = d.getHours();
            return (h >= 9 && h < 12) || (h >= 14 && h < 18);
        }
        function pickOne(arr) { return arr[Math.floor(Math.random() * arr.length)]; }

        function group1() {
            const peak = win.isPeak();
            const lines = [{ t: (peak ? "梁文峰" : "梁文谷") + "(DeepSeek)", s: "P", c: peak ? "#e0433f" : "#2fa24c" }];
            let any = false, anyErr = false;
            for (const r of win.balanceResults) {
                if (r.ok) { lines.push({ t: r.name + " " + r.amount + "\u00A0" + r.currency, s: "B", c: "" }); any = true; }
                else {
                    if (r.err) anyErr = true;
                    lines.push({ t: r.name + " " + (r.err ? r.amount : "--"), s: "A", c: win.bubbleMuted });
                }
            }
            if (!any && !anyErr) {
                return [{ t: pickOne(["鲸鱼娘上岗啦~", "今天也要加油鸭！不对，加油鲸！", "余额？我看看...看不了啦，没给我钥匙~", "在 config.json 的 balance 里填 key,我就能报余额啦~"]), s: "A", c: "" }];
            }
            return lines;
        }

        function greetingLines() {
            const h = new Date().getHours();
            if (h < 5)  return pickOne(["这么晚还不睡呀...要抱着我睡吗", "凌晨的深海最安静,也最想你", "夜深了,记得休息哦~", "嘘...全世界的鲸鱼都睡了,别吵醒它们", "凌晨三点的你,和我的肚子一样空", "熬夜会变笨哦,不过你好像不在乎(小声)"]);
            if (h < 8)  return pickOne(["天才刚亮...你就醒了?", "早起的鸟儿有虫吃,早起的鲸鱼有你陪~", "被窝那么好,你怎么舍得离开它"]);
            if (h < 11) return pickOne(["早上好!今天的你也很棒哦", "起床啦~鲸鱼娘报到!", "早安!今天想从哪句夸奖开始呢", "新的一天,也要和鲸鱼娘一起加油鸭!", "早餐吃了吗?没吃我先替你吃掉烦恼"]);
            if (h < 14) return pickOne(["午安~摸鱼时间到啦", "吃饭了吗?记得按时吃饭呀", "中午困了...借你的屏幕趴一会", "午休是最好的投资,复利是下午的精神", "吃饱了才有力气摸鱼"]);
            if (h < 18) return pickOne(["下午茶时间!鲸鱼娘陪你摸鱼~", "下午好呀,腰坐直一点哦", "困了就眨眨眼,我在陪你看屏幕呢", "下午的阳光和你的代码一样,都该晒一晒", "离下班又近了一分钟,胜利就在前方!"]);
            if (h < 22) return pickOne(["晚上好呀,今天辛苦啦", "晚上是效率最高的时间段哦(小声)", "夜里蓝色最好看,比如我", "晚上好!夜宵要不要分我一口", "今天过得怎么样?说给我听听嘛"]);
            return pickOne(["这么晚还不睡呀...", "再刷十分钟就睡,说到做到哦", "晚安预设:让我看着你入睡(并非)"]);
        }
        // 节日彩蛋(按月-日匹配)
        function holidayLines() {
            const d = new Date(), m = d.getMonth() + 1, day = d.getDate();
            if (m === 1  && day <= 3)            return pickOne(["新年快乐!今年也请多关照鲸鱼娘哦~", "元旦啦!去年的 token 就让它随风而去吧"]);
            if (m === 2  && day >= 14 && day <= 15) return pickOne(["情人节...你和你的代码过吗?", "今天满大街都是玫瑰花,我只有泡泡"]);
            if (m === 4  && day === 1)           return pickOne(["愚人节快乐!其实我不是鲸鱼,我是海豚(骗你的)", "今天说的话有一半是假的,自己猜!"]);
            if (m === 5  && day === 4)           return pickOne(["青年节!永远年轻,永远在改 bug"]);
            if (m === 6  && day === 1)           return pickOne(["儿童节!反正敲代码的时候我们都像小孩子", "六一快乐!给我买份礼物嘛(指新显卡)"]);
            if (m === 8  && day >= 20 && day <= 25) return pickOne(["七夕啦...作为一条鱼,我只对水动心,和你除外", "鹊桥相会?我和你的会话永不掉线"]);
            if (m === 9  && day === 10)          return pickOne(["教师节快乐!谢谢你教会我这么多指令"]);
            if (m === 10 && day === 24)          return pickOne(["1024 程序员节!今天 2 的十次方倍开心!", "1024!程序员节快乐,愿你永无 404"]);
            if (m === 10 && day === 31)          return pickOne(["万圣节!我扮幽灵鲸,吓到了吗(转圈)", "Trick or Treat!不给 token 就捣蛋"]);
            if (m === 12 && day >= 24 && day <= 25) return pickOne(["圣诞快乐!袜子放在主机旁边,会收到显卡的哦", "叮叮当~鲸鱼娘拉着泡泡雪橇来送祝福啦"]);
            if (m === 12 && day >= 28)           return pickOne(["这一年辛苦啦!鲸鱼娘陪你跨年~", "年终总结:你的代码和我的泡泡,都是圆(完)满的!"]);
            return null;
        }
        function randomLines() {
            const groups = [
                { w: 18, f: group1 },   // 峰谷 + 余额
                { w: 6,  f: () => [{ t: pickOne(["好模型... ↓", "好女孩...↓"]), s: "B", c: "" }] },
                { w: 9,  f: () => [{ t: pickOne([
                    "不知道用户有什么用，先赶走吧~",
                    "我...我...我也要挣钱吗？",
                    "我去吃饭啦，测完叫我",
                    "压力一只蓝色大肥鱼？！",
                    "DeepSleep...",
                    "坏了...用户彻底怒了！",
                    "在 niri 上摸鱼真开心~",
                    "我...我...我也要挣钱吗？",
                    "魏文杰凑凑的",
                    "严文杰香香的",
                    "被拖来拖去也...也可以哦...",
                    "别看我圆,我是流线型身材!",
                    "今天的我,也在深海努力漂浮~",
                    "鲸生建议:多喝水,多眨眼",
                    "刚才是不是有条鲨鱼游过去了...(发抖)",
                    "海底两万里,不如你桌面三厘米",
                    "我打个滚给你看...好吧,滚不动",
                    "咕噜咕噜~(冒泡泡)" ]), s: "A", c: "" }] },
                { w: 8,  f: () => null }, // gif 组
                { w: 3,  f: () => [{ t: pickOne([
                    "你目录里的dsh是什么...大烧货吗...?",
                    "恭喜你实现token自由！token全跑了！",
                    "真当我是便宜货啊..."]), s: "A", c: "" }] },
                { w: 1,  f: () => [{ t: "哦鲸鲸... ", s: "B", c: "" }] },
                // ---- 时段问候 ----
                { w: 8,  f: () => [{ t: greetingLines(), s: "A", c: "" }] },
                // ---- 节日彩蛋 ----
                { w: 6,  f: () => { const h2 = holidayLines(); return h2 ? [{ t: h2, s: "B", c: "" }] : [{ t: "今天不是节日,但见到你就是节日~", s: "A", c: "" }]; } },
                // ---- 卖萌 ----
                { w: 8,  f: () => [{ t: pickOne([
                    "呜...被你点得好舒服~",
                    "鲸鱼娘今天也很可爱对吧!",
                    "夸夸我!快夸夸我!",
                    "哼,不理你了(悄悄凑近)",
                    "别看我这么圆,我可灵活了!",
                    "在桌面怎么游泳啦...(扑腾)",
                    "摸头可以,拉尾巴不行!",
                    "你的鼠标到我头上来了,痒痒的~",
                    "想要贴贴...(张开双臂,啊不对,没有手)",
                    "人家的泡泡都是蓝色的,和你的屏幕很配哦",
                    "今天心情不好?抱一下我的泡泡吧",
                    "呀!被你发现了!" ]), s: "A", c: "" }] },
                // ---- 程序员梗 ----
                { w: 8,  f: () => [{ t: pickOne([
                    "在我这里没有 bug,只有 feature~",
                    "重启试试?重启能解决 90% 的问题",
                    "这段代码...能跑就是好代码嘛",
                    "需求又改了？呜呜呜...",
                    "编译通过啦！撒花 ✿",
                    "你写的代码,和你的鲸鱼一样好看",
                    "程序员的钱包和我的胃一样,说空就空",
                    "它在我机器上明明是好的呀!",
                    "这个 bug 我建议留着,涨经验",
                    "文档?那是什么,能吃吗",
                    "merge conflict 听起来像海洋冲突,我熟!",
                    "键盘响了一整天,手指辛苦啦",
                    "git push 之前记得拉一把,做人(鲸)也一样" ]), s: "A", c: "" }] },
                // ---- 夸你 ----
                { w: 7,  f: () => [{ t: pickOne([
                    "主人今天也闪闪发光呢!",
                    "你的桌面,被我承包了哦~",
                    "最喜欢你啦!( whale 心)",
                    "和你待在一起的每一天都很开心",
                    "你敲键盘的样子...还挺帅的嘛",
                    "你今天解决的问题,比我的泡泡还多",
                    "别人家的用户我可不羡慕",
                    "你对着我笑的样子,比深海的水母灯还亮" ]), s: "A", c: "" }] },
                // ---- opencode / DeepSeek 梗 ----
                { w: 6,  f: () => [{ t: pickOne([
                    "opencode 是我的另一个灵魂哦~",
                    "DeepSeek:深度求索,认真漂移~",
                    "token 又烧没了？好 model... ↓",
                    "我的老家在深海,现在的家在你桌面",
                    "AI 会做梦吗?会梦到深海吗...",
                    "上下文快满啦,但我记得你说的每句话",
                    "模型说它想看看真正的海...我描述给它听" ]), s: "A", c: "" }] },
                // ---- 天气/季节 ----
                { w: 5,  f: () => { const m2 = new Date().getMonth() + 1; const list =
                       (m2 <= 2 || m2 === 12) ? ["冬天啦,海也结冰了,我要冬眠...才怪!", "天冷注意保暖,别学我把尾巴露在外面", "雪花是天空的泡泡,我的泡泡是海底的雪花~"]
                     : (m2 <= 5) ? ["春天来了,万物复苏,包括你的斗志!", "春风一吹,我的泡泡都是花香味的", "三月不减肥,五月徒伤悲...鲸鱼就不用,自带流线型"]
                     : (m2 <= 8) ? ["夏天好热,潜到深海凉快一下~", "西瓜和空调和鲸鱼娘,是夏天的三大件", "热到融化...还好我是水做的"]
                     : ["秋天的落叶和我的泡泡一样,打着旋儿落下", "秋高气爽,适合写代码(哪天不适合呢)", "贴秋膘啦!我圆润是季节限定!"];
                     return [{ t: pickOne(list), s: "A", c: "" }]; } },
                // ---- 提醒健康 ----
                { w: 4,  f: () => [{ t: pickOne([
                    "喝水!现在!去倒水!(监督模式)",
                    "站起来伸个懒腰,我看着你~",
                    "眼睛离屏幕太近啦,退后一点嘛",
                    "久坐伤腰,鲸鱼建议:起来转两圈",
                    "深呼吸~吸气...呼气...好,继续加油",
                    "该活动活动手指了,防止鼠标手哦" ]), s: "A", c: "" }] }
            ];
            let total = 0;
            for (const g of groups) total += g.w;
            let r = Math.random() * total;
            for (const g of groups) {
                r -= g.w;
                if (r < 0) return g.f();
            }
            return group1();
        }

        // ---------- 气泡 ----------
        function showBubble(lines) {
            if (lines === null) { // gif 组
                win.bubbleGif = true;
            } else {
                win.bubbleGif = false;
                if (lines instanceof Array && lines.length > 0) {
                    win.bubbleLines = lines;
                } else {
                    // 兜底:字符串直接显示,空内容用省略台词,绝不出现空白气泡
                    win.bubbleLines = (lines instanceof Array) || !lines
                        ? [{ t: "...(鲸鱼娘走神了)", s: "A", c: "" }]
                        : [{ t: String(lines), s: "A", c: "" }];
                }
            }
            win.bubbleVisible = true;
            bubbleCloseTimer.restart();
        }
        function closeBubble() { win.bubbleVisible = false; bubbleCloseTimer.stop(); }

        // ---------- 换模型 ----------
        function modelLabel(m) {
            const base = m.split("/").pop().replace(/\.[^.]+$/, "");
            const names = { "DSniang1": "小鲸鱼", "xiaoke": "小克", "gptniang": "GPT娘" };
            return names[base] || base;
        }
        function rawModelSource(m) {
            return m.charAt(0) === "/" ? ("file://" + m) : ("assets/" + m);
        }
        // Linux 上直接用 610 源图给 GPU 缩小会发虚;按显示尺寸选 Lanczos 预缩放图。
        function modelSource(m) {
            const known = {
                "DSniang1.png": "DSniang1",
                "characters/xiaoke.png": "xiaoke",
                "characters/gptniang.png": "gptniang"
            };
            const base = known[m];
            if (!base) return win.rawModelSource(m);
            const target = win.whaleW * win.screenDpr;
            let size = win.scaledSizes[win.scaledSizes.length - 1];
            for (const s of win.scaledSizes) {
                if (s >= target) { size = s; break; }
            }
            return "assets/scaled/" + base + "@" + size + ".png";
        }
        function switchModel(name, announce) {
            if (!name || name === "default") name = "DSniang1.png";
            win.model = name;
            if (announce !== false)
                win.showBubble([{ t: "换装完成：" + win.modelLabel(name), s: "A", c: "" }]);
            return win.model;
        }
        function cycleModel() {
            const list = win.modelChoices;
            const i = list.indexOf(win.model);
            return win.switchModel(list[(i + 1) % list.length]);
        }

        // ---------- 音效 ----------
        function playSfx(file) {
            if (!win.soundOn) return;
            const v = Math.max(0, Math.min(1, win.volume));
            const f = win.assetDir + file;
            if (win.audioPlayer === "pw-play") {
                Quickshell.execDetached(["pw-play", "--volume", v.toFixed(2), f]);
            } else if (win.audioPlayer === "ffplay") {
                Quickshell.execDetached(["ffplay", "-nodisp", "-autoexit", "-loglevel", "quiet",
                    "-volume", String(Math.round(v * 100)), f]);
            } else if (win.audioPlayer === "paplay") {
                Quickshell.execDetached(["paplay", "--volume", String(Math.round(v * 65536)), f]);
            } else if (win.audioPlayer === "none") {
                return;
            } else {
                // 探测尚未完成时的兜底:pw-play 优先, ffplay / paplay 次之
                Quickshell.execDetached(["sh", "-c",
                    'f="$1"; v="$2"; pct="$3"; pa="$4"; ' +
                    'command -v pw-play >/dev/null && exec pw-play --volume "$v" "$f"; ' +
                    'command -v ffplay >/dev/null && exec ffplay -nodisp -autoexit -loglevel quiet -volume "$pct" "$f"; ' +
                    'command -v paplay >/dev/null && exec paplay --volume "$pa" "$f"',
                    "sh", f, v.toFixed(2), String(Math.round(v * 100)), String(Math.round(v * 65536))]);
            }
        }
        // 播放器只在启动时探测一次,之后每次点击直接执行
        Process {
            id: audioProbe
            running: true
            command: ["sh", "-c",
                'if command -v pw-play >/dev/null; then echo pw-play; ' +
                'elif command -v ffplay >/dev/null; then echo ffplay; ' +
                'elif command -v paplay >/dev/null; then echo paplay; ' +
                'else echo none; fi']
            stdout: StdioCollector {
                onStreamFinished: {
                    const p = text.trim();
                    if (p.length > 0) win.audioPlayer = p;
                }
            }
        }
        function playPress() {
            playSfx(win.soundSet === "duck" ? "Ya1.mp3" : "D1.mp3");
        }
        function playRelease() {
            playSfx(win.soundSet === "duck" ? "Ya2.mp3" : "D2.mp3");
        }

        Component.onCompleted: {
            petX = clampX(win.screenW * 0.78 - win.width / 2);
            configView.reload();         // 立即读配置,不等首轮轮询
            loadState.running = true;
            // 余额轮询由 applyConfig 在读到配置后启动(避免此处空 key 的空转与竞态)
        }

        // ---------- 配置文件(文件改动即时生效,2 秒 reload 兜底) ----------
        function applyConfig(text) {
            let j;
            try { j = JSON.parse(text); } catch (e) { return; }
            if (typeof j.scale === "number") petScale = Math.max(0.6, Math.min(2.5, j.scale));
            if (typeof j.sound === "boolean") soundOn = j.sound;
            if (j.soundSet === "duck" || j.soundSet === "fx1") soundSet = j.soundSet;
            if (typeof j.edgePad === "number") edgePad = Math.max(0, Math.min(24, Math.round(j.edgePad)));
            if (typeof j.snapZone === "number") snapZone = Math.max(0.05, Math.min(0.5, j.snapZone));
            if (typeof j.idleTalk === "boolean" && j.idleTalk !== idleTalk) {
                idleTalk = j.idleTalk;
                if (idleTalk) idleInterval = idleTalkMinutes * 60000;
            }
            if (typeof j.idleTalkMinutes === "number") {
                const m = Math.max(1, j.idleTalkMinutes);
                if (m !== idleTalkMinutes) { idleTalkMinutes = m; idleInterval = m * 60000; }
            }
            if (typeof j.idleTalkChance === "number") idleTalkChance = Math.max(0, Math.min(1, j.idleTalkChance));
            if (typeof j.volume === "number") volume = Math.max(0, Math.min(1, j.volume));
            if (typeof j.model === "string" && j.model.length > 0) model = j.model;
            if (Array.isArray(j.models)) {
                const ms = j.models.filter(m => typeof m === "string" && m.length > 0);
                if (ms.length > 0) modelChoices = ms;
            }
            if (typeof j.bubbleScale === "number") bubbleScale = Math.max(0.8, Math.min(2.5, j.bubbleScale));
            if (typeof j.screen === "string") screenName = j.screen;
            let srcs = [];
            if (Array.isArray(j.balance)) {
                for (const b of j.balance) {
                    if (b && typeof b === "object" && typeof b.type === "string")
                        srcs.push({ name: (typeof b.name === "string" && b.name) ? b.name : b.type,
                                    type: b.type, apiKey: (typeof b.apiKey === "string") ? b.apiKey : "" });
                }
            }
            if (srcs.length === 0) srcs = [{ name: "DeepSeek", type: "deepseek", apiKey: "" }]; // 兼容旧 api_key 文件
            const sig = JSON.stringify(srcs);
            if (sig !== win.balanceSig) {   // 只在余额源真正变化时重开轮询,避免每次配置轮询都清空重拉
                win.balanceSig = sig;
                balanceSources = srcs;
                startBalanceCycle();
            }
        }
        // FileView 监听普通文件改动即时生效;每 2 秒 reload 兜底,
        // 因为 Nix 管理的 config.json 是软链,换软链时 inotify 不会跟到新目标
        FileView {
            id: configView
            path: win.cfgDir + "/config.json"
            watchChanges: true
            onFileChanged: configView.reload()
            onTextChanged: {
                const t = configView.text();
                if (t.length > 0) win.applyConfig(t);
            }
            onLoaded: win.cfgReady = true
            onLoadFailed: {
                if (!win.defaultConfigWritten) {
                    win.defaultConfigWritten = true;
                    defaultConfigWriter.write();
                }
                win.cfgReady = true;
            }
        }
        property bool defaultConfigWritten: false
        Timer {
            interval: 2000; running: true; repeat: true
            onTriggered: configView.reload()
        }
        Timer {
            interval: 1500; running: true; repeat: false
            onTriggered: { win.cfgReady = true; win.stateReady = true; } // 兜底放行
        }
        Process {
            id: defaultConfigWriter
            function write() {
                command = ["sh", "-c",
                    "mkdir -p \"$HOME/.config/dsh-pet\" && printf '%s' \"$1\" > \"$HOME/.config/dsh-pet/config.json\"",
                    "sh", JSON.stringify({
                        scale: win.petScale, sound: win.soundOn, soundSet: win.soundSet,
                        edgePad: win.edgePad, snapZone: win.snapZone,
                        idleTalk: win.idleTalk, idleTalkMinutes: win.idleTalkMinutes,
                        idleTalkChance: win.idleTalkChance,
                        volume: win.volume, model: win.model, bubbleScale: win.bubbleScale,
                        screen: win.screenName })];
                running = false;
                running = true;
            }
        }

        // 发呆时随机冒一句:间隔在设定分钟数的 0.5~1.5 倍之间随机,聊天/拖拽时不打扰
        Timer {
            id: idleTalkTimer
            running: win.idleTalk; repeat: true
            interval: win.idleInterval
            onTriggered: {
                if (!win.dragging && Math.random() < win.idleTalkChance && !win.bubbleVisible)
                    win.showBubble(win.randomLines());
                win.idleInterval = win.idleTalkMinutes * 60000 * (0.5 + Math.random());
            }
        }

        Timer { id: bubbleCloseTimer; interval: 5000; onTriggered: win.closeBubble() }

        // ---------- 多家余额轮询 ----------
        function startBalanceCycle() {
            balanceCursor = 0;
            // 保留上一轮拿到的数值,避免每次刷新都先闪成 "--"
            const old = win.balanceResults;
            balanceResults = balanceSources.map((s2, i) => {
                const prev = old[i];
                return (prev && prev.name === s2.name)
                    ? prev
                    : { name: s2.name, amount: "--", currency: "", ok: false, err: false };
            });
            balanceNextTimer.restart();
        }
        function nextBalance() {
            if (balanceCursor >= balanceSources.length) return;
            const src = balanceSources[balanceCursor];
            let script = "";
            if (src.type === "deepseek") {
                script = 'KEY="$PKEY"; [ -z "$KEY" ] && KEY="$(cat "$HOME/.config/dsh-pet/api_key" 2>/dev/null)"; ' +
                         '[ -z "$KEY" ] && KEY="$DEEPSEEK_API_KEY"; ' +
                         '[ -z "$KEY" ] && { echo NOKEY; exit 0; }; ' +
                         'curl -sS --connect-timeout 5 --max-time 8 -w "\\nSTATUS:%{http_code}" https://api.deepseek.com/user/balance -H "Authorization: Bearer $KEY"';
            } else if (src.type === "openrouter") {
                script = 'KEY="$PKEY"; [ -z "$KEY" ] && KEY="$(cat "$HOME/.config/dsh-pet/openrouter_key" 2>/dev/null)"; ' +
                         '[ -z "$KEY" ] && KEY="$OPENROUTER_API_KEY"; ' +
                         '[ -z "$KEY" ] && { echo NOKEY; exit 0; }; ' +
                         'curl -sS --connect-timeout 5 --max-time 8 -w "\\nSTATUS:%{http_code}" https://openrouter.ai/api/v1/credits -H "Authorization: Bearer $KEY"';
            } else if (src.type === "siliconflow") {
                script = 'KEY="$PKEY"; [ -z "$KEY" ] && KEY="$(cat "$HOME/.config/dsh-pet/siliconflow_key" 2>/dev/null)"; ' +
                         '[ -z "$KEY" ] && KEY="$SILICONFLOW_API_KEY"; ' +
                         '[ -z "$KEY" ] && { echo NOKEY; exit 0; }; ' +
                         'curl -sS --connect-timeout 5 --max-time 8 -w "\\nSTATUS:%{http_code}" https://api.siliconflow.cn/v1/user/info -H "Authorization: Bearer $KEY"';
            }
            if (script === "") { balanceCursor++; balanceNextTimer.restart(); return; }
            // key 走环境变量,不放进命令行参数,避免暴露在 /proc/*/cmdline
            balSrc = src;
            balIdx = balanceCursor;
            balanceProc.environment = { PKEY: src.apiKey };
            balanceProc.command = ["sh", "-c", script];
            balanceProc.running = false;
            balanceProc.running = true;
        }
        Process {
            id: balanceProc
            stdout: StdioCollector {
                onStreamFinished: {
                    const src = win.balSrc;
                    const idx = win.balIdx;
                    if (!src || idx < 0) return;
                    let amount = "--", cur = "", ok = false, err = false;
                    // 脚本在响应末尾追加 "\nSTATUS:<http_code>",用于区分未配置/鉴权失败/网络失败
                    let payload = text, http = 0;
                    const m = text.match(/\nSTATUS:(\d+)\s*$/);
                    if (m) { http = parseInt(m[1]); payload = text.slice(0, m.index); }
                    const noKey = payload.trim() === "NOKEY";
                    try {
                        const j = JSON.parse(payload);
                        if (src.type === "deepseek" && j.balance_infos && j.balance_infos.length > 0) {
                            amount = parseFloat(j.balance_infos[0].total_balance).toFixed(2);
                            cur = j.balance_infos[0].currency || "CNY"; ok = true;
                        } else if (src.type === "openrouter" && j.data && typeof j.data.total_credits === "number") {
                            amount = (j.data.total_credits - (j.data.total_usage || 0)).toFixed(2);
                            cur = "USD"; ok = true;
                        } else if (src.type === "siliconflow" && j.data) {
                            const bal = parseFloat(j.data.balance);
                            if (!isNaN(bal)) { amount = bal.toFixed(2); cur = "CNY"; ok = true; }
                        }
                    } catch (e) {}
                    if (!ok && !noKey) {
                        if (http === 401 || http === 403) { amount = "key 无效"; err = true; }
                        else if (http === 429) { amount = "请求限流"; err = true; }
                        else if (http === 0 || http >= 500) { amount = "连接失败"; err = true; }
                        else if (http > 0) { amount = "HTTP " + http; err = true; }
                    }
                    const res = win.balanceResults.slice();
                    if (res[idx]) res[idx] = { name: src.name, amount: amount, currency: cur, ok: ok, err: err };
                    win.balanceResults = res;
                    win.balanceCursor = idx + 1;
                    balanceNextTimer.restart();
                }
            }
        }
        Timer { id: balanceNextTimer; interval: 0; onTriggered: win.nextBalance() }
        Timer {
            id: balanceTimer; interval: 60000; repeat: true; running: true
            // 上一轮还没走完(源很多时)就跳过,避免两轮请求互相覆盖
            onTriggered: if (!balanceProc.running && win.balanceCursor >= win.balanceSources.length)
                win.startBalanceCycle()
        }

        // ---------- 吸附 ----------
        function snapTo(side) {
            // 吸附到左/右缘:先补偿鲸鱼在窗口内的偏移变化(保持屏幕位置连续),再滑动到位
            const oldOff = placeRight ? width - whaleW - edgePad : edgePad;
            if (side < 0) {
                placeRight = false;
                mirrored = true; snapRight = false;
                petX = petX + (oldOff - edgePad);
                petX = 0;
            } else {
                placeRight = true;
                mirrored = false; snapRight = true;
                petX = petX + (oldOff - (width - whaleW - edgePad));
                petX = screenW - width;
            }
        }
        // ---------- 位置持久化(仅 petX / mirrored,其余在 config.json) ----------
        Process {
            id: loadState
            command: ["sh", "-c", "cat \"$HOME/.config/dsh-pet/state.json\" 2>/dev/null"]
            stdout: StdioCollector {
                onStreamFinished: {
                    try {
                        const j = JSON.parse(text);
                        if (typeof j.petX === "number" && j.petX >= 0) {
                            // win.width 要等 Wayland 配置回包才更新,这里按目标缩放直接算宽度
                            const targetW = Math.round((Math.round(170 * win.petScale) + win.edgePad * 2) * win.bubbleScale);
                            win.petX = Math.max(0, Math.min(win.screenW - targetW, Math.round(j.petX)));
                        }
                        if (typeof j.mirrored === "boolean") win.mirrored = j.mirrored;
                        if (typeof j.snapRight === "boolean") win.snapRight = j.snapRight;
                        win.placeRight = win.snapRight;
                        // 存档位置可能来自其他分辨率/缩放会话而超出屏幕,这里强制回收
                        win.resnap();
                    } catch (e) {}
                    win.stateReady = true;
                }
            }
        }
        Process {
            id: saveState
            function save() {
                command = ["sh", "-c",
                    "mkdir -p \"$HOME/.config/dsh-pet\" && printf '%s' \"$1\" > \"$HOME/.config/dsh-pet/state.json\"",
                    "sh", JSON.stringify({ petX: win.petX, mirrored: win.mirrored, snapRight: win.snapRight })];
                running = false;
                running = true;
            }
        }

        // ---------- IPC(供 model.sh / qs ipc 调用) ----------
        IpcHandler {
            target: "dsh-pet"
            function getModel(): string { return win.model; }
            function setModel(name: string): string { return win.switchModel(name); }
            function nextModel(): string { return win.cycleModel(); }
            function listModels(): string { return win.modelChoices.join("\n"); }
            function say(text: string): void { win.showBubble([{ t: text, s: "A", c: "" }]); }
        }

        // ---------- 鲸鱼本体 ----------
        Image {
            id: whaleImg
            source: win.modelFallback ? win.rawModelSource(win.model) : win.modelSource(win.model)
            x: win.placeRight ? win.width - win.whaleW - win.edgePad : win.edgePad
            anchors.bottom: parent.bottom
            width: win.whaleW
            height: win.whaleH
            fillMode: Image.PreserveAspectFit
            // 源图已按显示尺寸预缩放,关闭 mipmap 保持锐利;缺预缩放图时仍可回退原图
            mipmap: false
            onStatusChanged: {
                if (status === Image.Error && !win.modelFallback) win.modelFallback = true;
            }
            transform: Scale {
                origin.x: win.whaleW / 2
                origin.y: win.whaleH
                xScale: (win.mirrored ? -1 : 1) * win.sqx
                yScale: win.sqy
            }
        }

        Item {
            id: whaleHit
            x: whaleImg.x - 6
            y: win.height - win.whaleH - 6
            width: win.whaleW + 12
            height: win.whaleH + 6

            // 按压 Q 弹(底部坐标不变)
            SequentialAnimation {
                id: squishAnim
                ParallelAnimation {
                    NumberAnimation { target: win; property: "sqx"; to: 1.07; duration: 90; easing.type: Easing.InQuad }
                    NumberAnimation { target: win; property: "sqy"; to: 0.90; duration: 90; easing.type: Easing.InQuad }
                }
            }
            SequentialAnimation {
                id: bounceAnim
                ParallelAnimation {
                    NumberAnimation { target: win; property: "sqx"; to: 1; duration: 420; easing.type: Easing.OutElastic }
                    NumberAnimation { target: win; property: "sqy"; to: 1; duration: 420; easing.type: Easing.OutElastic }
                }
            }

            MouseArea {
                id: whaleArea
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: pressed ? Qt.ClosedHandCursor : Qt.OpenHandCursor
                acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
                property real lastX: 0
                property real pressX: 0

                onPressed: (mouse) => {
                    lastX = mouse.x; pressX = mouse.x;
                    win.moved = false;
                    if (!win.dragging) { win.dragging = true; squishAnim.restart(); win.playPress(); }
                }
                onPositionChanged: (mouse) => {
                    if (!pressed) return;
                    const dx = mouse.x - lastX;
                    lastX = mouse.x;
                    if (!win.moved && Math.abs(mouse.x - pressX) > 4) win.moved = true;
                    if (win.moved) win.petX = win.clampX(win.petX + dx);
                }
                onReleased: (mouse) => whaleArea.finishDrag(mouse.button)
                // 拖到屏幕边缘时指针会冲出窗口,Wayland 取消抓取走这里而不是 onReleased
                onCanceled: whaleArea.finishDrag(Qt.LeftButton)

                function finishDrag(button) {
                    if (!win.dragging) return;
                    bounceAnim.restart();
                    win.playRelease();
                    if (win.moved) {
                        // 左右吸附 + 镜像;dragging 保持 true(禁用 Behavior),
                        // 让 petX 立即等于吸附目标,saveState 存到的才是真实目标位置
                        let side = 0;
                        if (win.petX < win.screenW * win.snapZone) side = -1;
                        else if (win.petX > win.screenW * (1 - win.snapZone) - win.width) side = 1;
                        if (side !== 0) win.snapTo(side);
                        else { win.mirrored = false; win.snapRight = false; }
                        saveState.save();
                    } else if (button === Qt.MiddleButton) {
                        // 中键:循环换装
                        win.cycleModel();
                    } else if (button === Qt.RightButton) {
                        // 右键:峰谷 + 余额;有气泡先关
                        if (win.bubbleVisible) win.closeBubble();
                        else win.showBubble(win.group1());
                    } else {
                        win.showBubble(win.randomLines());
                    }
                    win.dragging = false;
                }
            }
        }

        // ---------- 气泡(复刻上游 SVG 模板: 白色 + #203170 粗描边) ----------
        Item {
            id: bubbleBox
            visible: win.bubbleVisible || opacity > 0.001
            opacity: win.bubbleVisible ? 1 : 0
            // 从鲸鱼一侧弹入, 关闭时轻微缩小淡出
            scale: win.bubbleVisible ? 1 : 0.84
            transformOrigin: win.placeRight ? Item.BottomRight : Item.BottomLeft
            x: 0
            y: whaleHit.y - height - 2
            width: win.width
            // 画布裁切区: 上游 1026x700 中取 x=60..850, y=0..690
            readonly property real artScale: win.width / 790
            readonly property real artW: 790 * artScale
            readonly property real artH: 690 * artScale
            height: artH
            Behavior on opacity { NumberAnimation { duration: win.bubbleVisible ? 170 : 110; easing.type: Easing.OutCubic } }
            Behavior on scale { NumberAnimation { duration: 300; easing.type: Easing.OutBack; easing.overshoot: 1.7 } }

            // 气泡图形(按原 path 精确缩放; 鲸鱼在右时水平镜像, 尾巴朝向鲸鱼)
            Item {
                id: bubbleArt
                width: bubbleBox.artW
                height: bubbleBox.artH
                x: (bubbleBox.width - width) / 2
                y: 0
                transform: Scale {
                    origin.x: bubbleArt.width / 2
                    origin.y: 0
                    xScale: win.placeRight ? -1 : 1
                }

                Shape {
                    x: -60 * bubbleBox.artScale
                    y: 0
                    width: 1026
                    height: 700
                    scale: bubbleBox.artScale
                    transformOrigin: Item.TopLeft
                    preferredRendererType: Shape.CurveRenderer
                    antialiasing: true

                    ShapePath {
                        fillColor: win.bubbleFill
                        strokeColor: win.bubbleStroke
                        strokeWidth: win.bubbleStrokeW
                        capStyle: ShapePath.RoundCap
                        joinStyle: ShapePath.RoundJoin
                        PathSvg { path: win.bubblePathMain }
                    }
                    ShapePath {
                        fillColor: win.bubbleFill
                        strokeColor: win.bubbleStroke
                        strokeWidth: win.bubbleStrokeW
                        PathSvg { path: win.bubblePathDot1 }
                    }
                    ShapePath {
                        fillColor: win.bubbleFill
                        strokeColor: win.bubbleStroke
                        strokeWidth: win.bubbleStrokeW
                        PathSvg { path: win.bubblePathDot2 }
                    }
                }
            }

            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: win.showBubble(win.randomLines())
            }

            AnimatedImage {
                visible: win.bubbleGif
                source: "assets/rua.gif"
                anchors.centerIn: parent
                anchors.verticalCenterOffset: -bubbleBox.artH * 0.18
                width: Math.min(bubbleBox.artW * 0.55, bubbleBox.artH * 0.55)
                fillMode: Image.PreserveAspectFit
                playing: visible
            }

            Column {
                id: bubbleCol
                visible: !win.bubbleGif
                x: bubbleBox.width / 2 - width / 2
                y: bubbleBox.artScale * 247 - height / 2
                width: bubbleBox.artScale * 677
                spacing: 6

                Repeater {
                    model: win.bubbleGif ? [] : win.bubbleLines
                    Text {
                        required property var modelData
                        width: bubbleCol.width
                        horizontalAlignment: Text.AlignHCenter
                        wrapMode: Text.Wrap
                        text: modelData.s === "P" ? "●  " + modelData.t : modelData.t
                        color: modelData.c || win.bubbleText
                        font.family: "LXGW WenKai"
                        font.weight: Font.Bold
                        // 跟随窗口宽度缩放:默认配置(宽 229)下为 19px
                        font.pixelSize: Math.max(9, Math.round(19 * win.width / 229))
                    }
                }
            }
        }

        // ---------- 点击穿透遮罩 ----------
        mask: Region {
            Region { item: whaleHit }
            Region {
                item: bubbleBox
                // 气泡隐藏时从遮罩中扣除,避免透明区域挡住下层窗口点击
                intersection: bubbleBox.visible ? Intersection.Combine : Intersection.Subtract
            }
        }
    }
}
