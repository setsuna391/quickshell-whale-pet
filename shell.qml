// DSH 小鲸鱼桌面宠物 —— quickshell 版
// 参考 DeepSeek-Balance-Whale-Widget 移植到 niri/Wayland
// 运行: ~/quickshell-pet/run.sh
// 配置: ~/.config/dsh-pet/config.json(保存后即时生效,无需重启)

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland

ShellRoot {
    id: root

    PanelWindow {
        id: win

        // ---- 可调配置(由 config.json 轮询更新,见底部 configProc) ----
        property real petScale: 1.0          // 缩放 0.6 – 2.5
        property bool soundOn: true          // 音效开关
        property string soundSet: "duck"     // duck = 小黄鸭(Ya), fx1 = 音效1(D)
        property int edgePad: 3              // 窗口左右内衬 px,越小贴边越紧
        property real snapZone: 0.22         // 左右吸附区占屏幕宽度的比例
        property bool idleTalk: true         // 发呆自言自语
        property int idleTalkMinutes: 5      // 自言自语间隔(分钟)
        property real idleTalkChance: 0.4    // 每次触发说话的概率

        // ---- 窗口几何 ----
        readonly property int baseW: 170
        readonly property int whaleW: Math.round(baseW * petScale)
        readonly property int whaleH: Math.round(baseW * petScale)
        readonly property int whaleTop: 216            // 上方留给气泡
        implicitWidth: Math.max(whaleW, chatW) + edgePad * 2   // 恒定宽度:面板空间常驻,开关聊天不伸缩
        implicitHeight: whaleH + whaleTop

        color: "transparent"
        anchors { bottom: true; left: true }
        exclusionMode: ExclusionMode.Ignore
        WlrLayershell.layer: WlrLayer.Top
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand
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
        property bool balanceOk: false
        property string balanceText: "--"
        property string currency: "CNY"
        // ---- 多家余额 ----
        property var balanceSources: [{ name: "DeepSeek", type: "deepseek", apiKey: "" }]
        property var balanceResults: [{ name: "DeepSeek", amount: "--", currency: "", ok: false }]
        property int balanceCursor: 0
        // ---- AI 对话 ----
        property string aiBase: "https://api.deepseek.com"
        property string aiKey: ""
        property string aiModel: "deepseek-chat"
        property string aiSystem: "你是 DeepSeek 小鲸鱼娘,一只可爱的桌面宠物鲸鱼。回复永远简短俏皮,不超过40个字,可以适当卖萌。"
        property int aiMaxHistory: 10
        property bool chatOpen: false
        property bool chatBusy: false
        property string chatReply: ""
        property var chatHistory: []
        // ---- opencode 对接 ----
        property bool ocEnabled: true
        property string ocBin: "opencode"
        property string ocModel: ""
        property string ocAgent: ""
        property string ocDir: ""
        property string ocSession: ""
        property bool snapRight: false               // 吸附在右边缘
        property bool placeRight: false              // 鲸鱼停在窗口左缘还是右缘(仅静止时刻更新)
        readonly property real chatW: 320            // 聊天面板宽度
        property int chatDots: 0

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
        onWidthChanged: {
            if (petX < 0 || dragging) return;
            if (snapRight) petX = screenW - width;
            else if (mirrored) petX = 0;
            else petX = clampX(petX);
        }

        function clampX(x) {
            return Math.max(0, Math.min(win.screenW - win.width, Math.round(x)));
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
            const lines = [{ t: (peak ? "高峰时段" : "空闲时段") + "(DeepSeek)", s: "P", c: peak ? "#e0433f" : "#2fa24c" }];
            let any = false;
            for (const r of win.balanceResults) {
                if (r.ok) { lines.push({ t: r.name + " " + r.amount + " " + r.currency, s: "B", c: "" }); any = true; }
                else lines.push({ t: r.name + " --", s: "A", c: "#9aa3c0" });
            }
            if (!any) {
                return [{ t: pickOne(["鲸鱼娘上岗啦~", "今天也要加油鸭！不对，加油鲸！", "余额？我看看...看不了啦，没给我钥匙~", "在 config.json 的 balance 里填 key,我就能报余额啦~"]), s: "A", c: "" }];
            }
            return lines;
        }

        function greetingLines() {
            const h = new Date().getHours();
            if (h < 5)  return pickOne(["这么晚还不睡呀...要抱着我睡吗", "凌晨的深海最安静,也最想你", "夜深了,记得休息哦~"]);
            if (h < 11) return pickOne(["早上好!今天的你也很棒哦", "起床啦~鲸鱼娘报到!", "早安!今天想从哪句夸奖开始呢"]);
            if (h < 14) return pickOne(["午安~摸鱼时间到啦", "吃饭了吗?记得按时吃饭呀", "中午困了...借你的屏幕趴一会"]);
            if (h < 18) return pickOne(["下午茶时间!鲸鱼娘陪你摸鱼~", "下午好呀,腰坐直一点哦", "困了就眨眨眼,我在陪你看屏幕呢"]);
            return pickOne(["晚上好呀,今天辛苦啦", "晚上是效率最高的时间段哦(小声)", "夜里蓝色最好看,比如我"]);
        }
        function randomLines() {
            const groups = [
                { w: 22, f: group1 },   // 峰谷 + 余额
                { w: 6,  f: () => [{ t: pickOne(["好模型... ↓", "好女孩...↓"]), s: "B", c: "" }] },
                { w: 7,  f: () => [{ t: pickOne([
                    "不知道用户有什么用，先赶走吧~",
                    "我...我...我也要挣钱吗？",
                    "我去吃饭啦，测完叫我",
                    "压力一只蓝色大肥鱼？！",
                    "DeepSleep...",
                    "坏了...用户彻底怒了！",
                    "在 niri 上摸鱼真开心~",
                    "被拖来拖去也...也可以哦...",
                    "别看我圆,我是流线型身材!",
                    "今天的我,也在深海努力漂浮~" ]), s: "A", c: "" }] },
                { w: 8,  f: () => null }, // gif 组
                { w: 3,  f: () => [{ t: pickOne([
                    "你目录里的dsh是什么...大烧货吗...?",
                    "恭喜你实现token自由！token全跑了！",
                    "真当我是便宜货啊..."]), s: "A", c: "" }] },
                { w: 1,  f: () => [{ t: "哦鲸鲸... ", s: "B", c: "" }] },
                // ---- 时段问候 ----
                { w: 8,  f: () => [{ t: greetingLines(), s: "A", c: "" }] },
                // ---- 卖萌 ----
                { w: 7,  f: () => [{ t: pickOne([
                    "呜...被你点得好舒服~",
                    "鲸鱼娘今天也很可爱对吧!",
                    "夸夸我!快夸夸我!",
                    "哼,不理你了(悄悄凑近)",
                    "别看我这么圆,我可灵活了!",
                    "在桌面怎么游泳啦...(扑腾)",
                    "摸头可以,拉尾巴不行!" ]), s: "A", c: "" }] },
                // ---- 程序员梗 ----
                { w: 7,  f: () => [{ t: pickOne([
                    "在我这里没有 bug,只有 feature~",
                    "重启试试?重启能解决 90% 的问题",
                    "这段代码...能跑就是好代码嘛",
                    "需求又改了？呜呜呜...",
                    "编译通过啦！撒花 ✿",
                    "你写的代码,和你的鲸鱼一样好看",
                    "程序员的钱包和我的胃一样,说空就空" ]), s: "A", c: "" }] },
                // ---- 夸你 ----
                { w: 6,  f: () => [{ t: pickOne([
                    "主人今天也闪闪发光呢!",
                    "你的桌面,被我承包了哦~",
                    "最喜欢你啦!( whale 心)",
                    "和你待在一起的每一天都很开心",
                    "你敲键盘的样子...还挺帅的嘛" ]), s: "A", c: "" }] },
                // ---- opencode / DeepSeek 梗 ----
                { w: 5,  f: () => [{ t: pickOne([
                    "opencode 是我的另一个灵魂哦~",
                    "DeepSeek:深度求索,认真漂移~",
                    "token 又烧没了？好 model... ↓",
                    "我的老家在深海,现在的家在你桌面",
                    "AI 会做梦吗?会梦到深海吗..." ]), s: "A", c: "" }] }
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

        // ---------- 音效 ----------
        function playSfx(file) {
            if (!win.soundOn) return;
            Quickshell.execDetached(["paplay", win.assetDir + file]);
        }
        function playPress() {
            playSfx(win.soundSet === "duck" ? "Ya1.mp3" : "D1.mp3");
        }
        function playRelease() {
            playSfx(win.soundSet === "duck" ? "Ya2.mp3" : "D2.mp3");
        }

        Component.onCompleted: {
            petX = clampX(win.screenW * 0.78 - win.width / 2);
            loadState.running = true;
            startBalanceCycle();
        }

        // ---------- 配置文件(每 2 秒轮询,改完自动生效) ----------
        function applyConfig(text) {
            let j;
            try { j = JSON.parse(text); } catch (e) { return; }
            if (typeof j.scale === "number") petScale = Math.max(0.6, Math.min(2.5, j.scale));
            if (typeof j.sound === "boolean") soundOn = j.sound;
            if (j.soundSet === "duck" || j.soundSet === "fx1") soundSet = j.soundSet;
            if (typeof j.edgePad === "number") edgePad = Math.max(0, Math.min(24, Math.round(j.edgePad)));
            if (typeof j.snapZone === "number") snapZone = Math.max(0.05, Math.min(0.5, j.snapZone));
            if (typeof j.idleTalk === "boolean") idleTalk = j.idleTalk;
            if (typeof j.idleTalkMinutes === "number") idleTalkMinutes = Math.max(1, j.idleTalkMinutes);
            if (typeof j.idleTalkChance === "number") idleTalkChance = Math.max(0, Math.min(1, j.idleTalkChance));
            if (j.opencode && typeof j.opencode === "object") {
                if (typeof j.opencode.enabled === "boolean") ocEnabled = j.opencode.enabled;
                if (typeof j.opencode.bin === "string" && j.opencode.bin) ocBin = j.opencode.bin;
                if (typeof j.opencode.model === "string") ocModel = j.opencode.model;
                if (typeof j.opencode.agent === "string") ocAgent = j.opencode.agent;
                if (typeof j.opencode.dir === "string") ocDir = j.opencode.dir;
            }
            if (j.ai && typeof j.ai === "object") {
                if (typeof j.ai.baseUrl === "string" && j.ai.baseUrl) aiBase = j.ai.baseUrl.replace(/\/+$/, "");
                if (typeof j.ai.apiKey === "string") aiKey = j.ai.apiKey;
                if (typeof j.ai.model === "string" && j.ai.model) aiModel = j.ai.model;
                if (typeof j.ai.system === "string" && j.ai.system) aiSystem = j.ai.system;
                if (typeof j.ai.maxHistory === "number") aiMaxHistory = Math.max(2, Math.min(50, Math.round(j.ai.maxHistory)));
            }
            let srcs = [];
            if (Array.isArray(j.balance)) {
                for (const b of j.balance) {
                    if (b && typeof b === "object" && typeof b.type === "string")
                        srcs.push({ name: (typeof b.name === "string" && b.name) ? b.name : b.type,
                                    type: b.type, apiKey: (typeof b.apiKey === "string") ? b.apiKey : "" });
                }
            }
            if (srcs.length === 0) srcs = [{ name: "DeepSeek", type: "deepseek", apiKey: "" }]; // 兼容旧 api_key 文件
            balanceSources = srcs;
            startBalanceCycle();
        }
        Process {
            id: configProc
            command: ["sh", "-c", "cat \"$HOME/.config/dsh-pet/config.json\" 2>/dev/null"]
            stdout: StdioCollector {
                onStreamFinished: {
                    if (text.length > 0) win.applyConfig(text);
                    else if (!win.defaultConfigWritten) {
                        win.defaultConfigWritten = true;
                        defaultConfigWriter.write();
                    }
                }
            }
        }
        property bool defaultConfigWritten: false
        Timer {
            interval: 2000; running: true; repeat: true
            onTriggered: { configProc.running = false; configProc.running = true; }
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
                        idleTalkChance: win.idleTalkChance })];
                running = false;
                running = true;
            }
        }

        // 发呆时随机冒一句:间隔在设定分钟数的 0.5~1.5 倍之间随机,聊天/拖拽时不打扰
        Timer {
            id: idleTalkTimer
            running: win.idleTalk; repeat: true
            interval: win.idleTalkMinutes * 60000
            onTriggered: {
                if (!win.dragging && !win.chatOpen && Math.random() < win.idleTalkChance && !win.bubbleVisible)
                    win.showBubble(win.randomLines());
                interval = win.idleTalkMinutes * 60000 * (0.5 + Math.random());
            }
        }

        Timer { id: bubbleCloseTimer; interval: 5000; onTriggered: win.closeBubble() }

        // ---------- 多家余额轮询 ----------
        function startBalanceCycle() {
            balanceCursor = 0;
            balanceResults = balanceSources.map(s2 => ({ name: s2.name, amount: "--", currency: "", ok: false }));
            balanceNextTimer.restart();
        }
        function nextBalance() {
            if (balanceCursor >= balanceSources.length) {
                balanceOk = balanceResults.some(r2 => r2.ok);
                return;
            }
            const src = balanceSources[balanceCursor];
            let script = "";
            if (src.type === "deepseek") {
                script = 'KEY="$PKEY"; [ -z "$KEY" ] && KEY=$(cat "$HOME/.config/dsh-pet/api_key" 2>/dev/null); ' +
                         '[ -z "$KEY" ] && KEY="$DEEPSEEK_API_KEY"; ' +
                         '[ -n "$KEY" ] && curl -s --max-time 8 https://api.deepseek.com/user/balance -H "Authorization: Bearer $KEY"';
            } else if (src.type === "openrouter") {
                script = 'KEY="$PKEY"; [ -z "$KEY" ] && KEY="$OPENROUTER_API_KEY"; ' +
                         '[ -n "$KEY" ] && curl -s --max-time 8 https://openrouter.ai/api/v1/credits -H "Authorization: Bearer $KEY"';
            } else if (src.type === "siliconflow") {
                script = 'KEY="$PKEY"; [ -z "$KEY" ] && KEY="$SILICONFLOW_API_KEY"; ' +
                         '[ -n "$KEY" ] && curl -s --max-time 8 https://api.siliconflow.cn/v1/user/info -H "Authorization: Bearer $KEY"';
            }
            if (script === "") { balanceCursor++; balanceNextTimer.restart(); return; }
            balanceProc.environment = { PKEY: src.apiKey };
            balanceProc.command = ["sh", "-c", script];
            balanceProc.running = false;
            balanceProc.running = true;
        }
        Process {
            id: balanceProc
            stdout: StdioCollector {
                onStreamFinished: {
                    const src = win.balanceSources[win.balanceCursor];
                    let amount = "--", cur = "", ok = false;
                    try {
                        const j = JSON.parse(text);
                        if (src.type === "deepseek" && j.is_balance_available && j.balance_infos && j.balance_infos.length > 0) {
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
                    const res = win.balanceResults.slice();
                    if (res[win.balanceCursor]) res[win.balanceCursor] = { name: src.name, amount: amount, currency: cur, ok: ok };
                    win.balanceResults = res;
                    win.balanceCursor++;
                    balanceNextTimer.restart();
                }
            }
        }
        Timer { id: balanceNextTimer; interval: 0; onTriggered: win.nextBalance() }
        Timer {
            id: balanceTimer; interval: 60000; repeat: true; running: true
            onTriggered: win.startBalanceCycle()
        }

        // ---------- AI 对话 ----------
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
        function aiConfigured() { return aiBase.length > 0 && (aiKey.length > 0 || true); }
        function toggleChat() {
            if (!chatOpen) {
                if (!ocEnabled && aiBase.length === 0) {
                    showBubble([{ t: "想聊天的话,先在 config.json 里配置 opencode 或 ai 段哦~", s: "A", c: "" }]);
                    return;
                }
                closeBubble();
                chatOpen = true;
                chatInputTimer.restart();
            } else {
                chatOpen = false;
            }
        }
        function sendChat(msg) {
            const m = msg.trim();
            if (!m || chatBusy) return;
            chatBusy = true;
            chatReply = "";
            if (ocEnabled) {
                chatProc.viaOc = true;
                chatProc.pendingUser = m;
                chatProc.environment = {
                    OSID: ocSession, OMODEL: ocModel, OAGENT: ocAgent,
                    ODIR: ocDir.length > 0 ? ocDir : Quickshell.env("HOME"), OBIN: ocBin
                };
                chatProc.command = ["sh", "-c",
                    'A=""; ' +
                    '[ -n "$OSID" ] && A="$A -s $OSID"; ' +
                    '[ -n "$OMODEL" ] && A="$A -m $OMODEL"; ' +
                    '[ -n "$OAGENT" ] && A="$A --agent $OAGENT"; ' +
                    'timeout 45 "$OBIN" run --format json $A --dir "$ODIR" "$1" < /dev/null',
                    "sh", m];
                chatProc.running = false;
                chatProc.running = true;
                return;
            }
            chatProc.viaOc = false;
            const hist = chatHistory.slice();
            hist.push({ role: "user", content: m });
            chatHistory = hist;
            const msgs = [{ role: "system", content: aiSystem }].concat(hist.slice(-aiMaxHistory * 2));
            const body = JSON.stringify({ model: aiModel, messages: msgs, stream: false, temperature: 0.8, max_tokens: 300 });
            chatProc.environment = { CBODY: body, CKEY: aiKey, CBASE: aiBase };
            chatProc.command = ["sh", "-c",
                '[ -z "$CKEY" ] && CKEY=$(cat "$HOME/.config/dsh-pet/ai_key" 2>/dev/null); ' +
                'curl -s --max-time 30 "$CBASE/chat/completions" -H "Authorization: Bearer $CKEY" ' +
                '-H "Content-Type: application/json" -d "$CBODY"'];
            chatProc.running = false;
            chatProc.running = true;
        }
        Timer { id: chatInputTimer; interval: 0; onTriggered: chatInput.forceActiveFocus() }
        Process {
            id: chatProc
            property string pendingUser: ""
            property bool viaOc: false
            stdout: StdioCollector {
                onStreamFinished: {
                    win.chatBusy = false;
                    let reply = "";
                    if (chatProc.viaOc) {
                        let sid = "", err = "";
                        for (const line of text.split("\n")) {
                            if (!line.trim()) continue;
                            try {
                                const j = JSON.parse(line);
                                if (j.sessionID && !sid) sid = j.sessionID;
                                if (j.type === "text" && j.part && j.part.text) reply += (reply ? "\n" : "") + j.part.text;
                                if (j.type === "error") {
                                    const e2 = j.error || {};
                                    err = (e2.data && e2.data.message) || e2.message || "未知错误";
                                }
                            } catch (e) {}
                        }
                        if (sid) win.ocSession = sid;
                        saveState.save();
                        if (err) reply = "⚠️ " + err;
                        else if (!reply) reply = "(opencode 没有回复,检查一下模型配置~)";
                    } else {
                        try {
                            const j = JSON.parse(text);
                            if (j.choices && j.choices[0] && j.choices[0].message && j.choices[0].message.content)
                                reply = String(j.choices[0].message.content).trim();
                            else if (j.error && j.error.message)
                                reply = "呜呜... " + String(j.error.message).slice(0, 90);
                        } catch (e) { reply = "呜呜... 没听清(网络或配置问题)"; }
                        if (!reply) reply = "(它好像什么都没说...)";
                        const hist = win.chatHistory.slice();
                        hist.push({ role: "assistant", content: reply });
                        win.chatHistory = hist;
                    }
                    win.chatReply = reply.slice(0, 600);
                }
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
                            const targetW = Math.max(Math.round(170 * win.petScale), win.chatW) + win.edgePad * 2;
                            win.petX = Math.max(0, Math.min(win.screenW - targetW, Math.round(j.petX)));
                        }
                        if (typeof j.mirrored === "boolean") win.mirrored = j.mirrored;
                        if (typeof j.ocSession === "string") win.ocSession = j.ocSession;
                        if (typeof j.snapRight === "boolean") win.snapRight = j.snapRight;
                        win.placeRight = win.snapRight;
                        // 存档位置可能来自其他分辨率/缩放会话而超出屏幕,这里强制回收
                        if (win.snapRight) win.petX = win.screenW - win.width;
                        else if (win.mirrored) win.petX = 0;
                    } catch (e) {}
                }
            }
        }
        Process {
            id: saveState
            function save() {
                command = ["sh", "-c",
                    "mkdir -p \"$HOME/.config/dsh-pet\" && printf '%s' \"$1\" > \"$HOME/.config/dsh-pet/state.json\"",
                    "sh", JSON.stringify({ petX: win.petX, mirrored: win.mirrored, snapRight: win.snapRight, ocSession: win.ocSession })];
                running = false;
                running = true;
            }
        }

        // ---------- 思考泡泡背景组件(椭圆身 + 渐远圆点链) ----------
        component BubbleBg: Item {
            id: bubbleBg
            property real tailX: width / 2
            property color fillColor: "#fdfdff"
            property color borderColor: "#4a5db4"
            antialiasing: true

            // 泡泡链:从大圆到小圆,连向角色头顶
            Repeater {
                model: 3
                Rectangle {
                    required property int index
                    readonly property real baseY: bubbleBg.height - 8
                    readonly property int dir: bubbleBg.tailX > bubbleBg.width / 2 ? -1 : 1
                    width: 15 - index * 3.5
                    height: width
                    radius: width / 2
                    color: bubbleBg.fillColor
                    border.color: bubbleBg.borderColor
                    border.width: 2
                    x: bubbleBg.tailX - width / 2 + dir * index * 7
                    y: baseY + index * 9
                    z: 1
                }
            }

            // 椭圆泡泡主体
            Rectangle {
                anchors.top: parent.top
                anchors.horizontalCenter: parent.horizontalCenter
                width: parent.width
                height: parent.height - 34
                radius: Math.min(width, height) * 0.42
                color: bubbleBg.fillColor
                border.color: bubbleBg.borderColor
                border.width: 2.5
            }
        }

        // ---------- 鲸鱼本体 ----------
        Image {
            id: whaleImg
            source: "assets/DSniang1.png"
            x: win.placeRight ? win.width - win.whaleW - win.edgePad : win.edgePad
            anchors.bottom: parent.bottom
            anchors.bottomMargin: 0
            width: win.whaleW
            height: win.whaleH
            mipmap: true
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
                acceptedButtons: Qt.LeftButton | Qt.RightButton
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
                    } else if (win.chatOpen) {
                        if (button === Qt.RightButton) win.toggleChat();
                        else chatInput.forceActiveFocus();
                    } else if (button === Qt.RightButton && win.bubbleVisible) {
                        win.closeBubble();                  // 有气泡先关气泡,不弹聊天
                    } else if (button === Qt.RightButton) {
                        win.toggleChat();
                    } else {
                        win.showBubble(win.randomLines());
                    }
                    win.dragging = false;
                }
            }
        }

        // ---------- 气泡 ----------
        Item {
            id: bubbleBox
            visible: win.bubbleVisible && !win.chatOpen
            opacity: 0
            x: win.edgePad
            y: whaleHit.y - height - 6
            width: win.width - win.edgePad * 2
            height: (win.bubbleGif ? 160 : bubbleCol.height + 30) + 34
            Behavior on opacity { NumberAnimation { duration: 150 } }
            onVisibleChanged: opacity = visible ? 1 : 0

            // 柔和投影
            Rectangle {
                x: 3; y: 9
                width: parent.width - 6; height: parent.height - 14
                radius: 16
                color: "#3b4a86"
                opacity: 0.10
            }

            BubbleBg { anchors.fill: parent; tailX: win.placeRight ? parent.width - win.whaleW / 2 - win.edgePad : win.whaleW / 2 + win.edgePad }

            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: win.showBubble(win.randomLines())
            }

            AnimatedImage {
                visible: win.bubbleGif
                source: "assets/rua.gif"
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.top: parent.top
                anchors.topMargin: 6
                playing: visible
            }

            Column {
                id: bubbleCol
                visible: !win.bubbleGif
                x: 16; y: 16
                width: parent.width - 28
                spacing: 6

                Repeater {
                    model: win.bubbleVisible && !win.bubbleGif ? win.bubbleLines : []
                    Text {
                        required property var modelData
                        renderType: Text.NativeRendering
                        width: bubbleCol.width
                        horizontalAlignment: Text.AlignHCenter
                        wrapMode: Text.Wrap
                        text: modelData.s === "P" ? "● " + modelData.t : modelData.t
                        color: modelData.c || "#3b3f52"
                        font.pixelSize: modelData.s === "P" ? 16 : (modelData.s === "B" ? 19 : 15)
                        font.bold: modelData.s === "P" || modelData.s === "B"
                    }
                }
            }
        }

        // ---------- 聊天面板(右键/双击鲸鱼开关) ----------
        Item {
            id: chatPanel
            visible: win.chatOpen
            opacity: 0
            x: win.whaleRight ? win.edgePad : win.width - win.edgePad - win.chatW
            y: whaleHit.y - height - 6
            width: win.chatW
            height: 240
            Behavior on opacity { NumberAnimation { duration: 150 } }
            onVisibleChanged: opacity = visible ? 1 : 0

            BubbleBg {
                anchors.top: parent.top
                anchors.horizontalCenter: parent.horizontalCenter
                width: parent.width
                height: parent.height - 34
                tailX: win.whaleRight ? parent.width - 34 : 34
            }

            // 标题栏
            Text {
                id: chatTitle
                renderType: Text.NativeRendering
                x: 14; y: 8
                text: "🐋 鲸鱼娘"
                color: "#3b4a86"
                font.pixelSize: 13
                font.bold: true
            }
            Text {
                anchors.right: parent.right
                anchors.rightMargin: 14
                anchors.verticalCenter: chatTitle.verticalCenter
                renderType: Text.NativeRendering
                text: win.chatBusy ? "思考中" + ".".repeat(win.chatDots) : (win.ocEnabled ? "opencode ●" : "AI ●")
                color: win.chatBusy ? "#e08c3f" : "#6b7bd6"
                font.pixelSize: 12
            }

            // 回复区
            Rectangle {
                id: replyBg
                x: 12; y: 32
                width: parent.width - 24
                height: 112
                radius: 10
                color: "white"
                border.color: "#dfe4ff"
                border.width: 1

                Flickable {
                    id: replyScroll
                    anchors.fill: parent
                    anchors.margins: 8
                    contentWidth: width
                    contentHeight: replyText.implicitHeight
                    clip: true
                    flickableDirection: Flickable.VerticalFlick

                    Text {
                        id: replyText
                        renderType: Text.NativeRendering
                        width: replyScroll.width
                        text: win.chatBusy ? "思考中" + ".".repeat(win.chatDots) : (win.chatReply.length > 0 ? win.chatReply : "跟鲸鱼娘聊点什么吧~")
                        color: win.chatBusy || win.chatReply.length === 0 ? "#9aa3c0" : "#3b3f52"
                        font.pixelSize: 13
                        wrapMode: Text.Wrap
                        textFormat: Text.PlainText
                    }
                }
            }

            // 输入行
            Rectangle {
                id: inputBg
                x: 12
                y: parent.height - 60
                width: parent.width - 24 - 34
                height: 34
                radius: 17
                color: "white"
                border.color: chatInput.activeFocus ? "#5b6ee1" : "#b9c3f2"
                border.width: chatInput.activeFocus ? 2 : 1

                Text {
                    visible: chatInput.text === ""
                    renderType: Text.NativeRendering
                    x: 12
                    anchors.verticalCenter: parent.verticalCenter
                    text: "和 opencode 说点什么…"
                    color: "#9aa3c0"
                    font.pixelSize: 12
                }
                TextInput {
                    id: chatInput
                    renderType: TextInput.NativeRendering
                    x: 12
                    anchors.verticalCenter: parent.verticalCenter
                    width: parent.width - 24
                    font.pixelSize: 12
                    color: "#3b3f52"
                    clip: true
                    onAccepted: { win.sendChat(chatInput.text); chatInput.text = ""; }
                    Keys.onEscapePressed: if (win.chatOpen) win.toggleChat();
                }
            }

            Rectangle {
                id: sendBtn
                x: parent.width - 12 - 30
                y: parent.height - 62
                width: 30; height: 30; radius: 15
                color: sendMa.pressed || win.chatBusy ? "#3b4a86" : "#5b6ee1"

                Text {
                    anchors.centerIn: parent
                    renderType: Text.NativeRendering
                    text: "➤"
                    color: "white"
                    font.pixelSize: 14
                }
                MouseArea {
                    id: sendMa
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: { win.sendChat(chatInput.text); chatInput.text = ""; }
                }
            }
        }
        Timer {
            running: win.chatBusy; repeat: true; interval: 400
            onTriggered: win.chatDots = (win.chatDots + 1) % 4
        }

        // ---------- 点击穿透遮罩 ----------
        mask: Region {
            Region { item: whaleHit }
            Region { item: bubbleBox }
            Region { item: chatPanel }
        }
    }
}
