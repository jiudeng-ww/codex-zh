$ErrorActionPreference = 'Continue'
$port = 9222

function Find-CodexExe {
    $running = Get-Process ChatGPT -ErrorAction SilentlyContinue | Select-Object -First 1 -ExpandProperty Path
    if ($running) { return $running }
    $dir = Get-ChildItem -LiteralPath 'C:\Program Files\WindowsApps' -Directory -ErrorAction SilentlyContinue |
           Where-Object { $_.Name -like 'OpenAI.Codex*' } | Select-Object -First 1
    if ($dir) {
        $exe = Join-Path $dir.FullName 'app\ChatGPT.exe'
        if (Test-Path $exe) { return $exe }
    }
    return $null
}

$exe = Find-CodexExe
if (-not $exe) {
    Write-Host '没找到 Codex。请先手动打开一次 Codex，再运行本文件。' -ForegroundColor Red
    Read-Host '按回车退出'
    return
}
Write-Host "Codex: $exe" -ForegroundColor Cyan

Get-Process ChatGPT -ErrorAction SilentlyContinue | ForEach-Object { $_.CloseMainWindow() | Out-Null }
Start-Sleep -Seconds 3
Get-Process ChatGPT -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue
Start-Sleep -Seconds 1

Start-Process -FilePath $exe -ArgumentList @("--remote-debugging-port=$port", '--remote-allow-origins=*')
Write-Host '已用调试模式启动 Codex，等待就绪...' -ForegroundColor Cyan

$targets = $null
for ($i = 0; $i -lt 20; $i++) {
    Start-Sleep -Seconds 2
    try {
        $targets = Invoke-RestMethod "http://127.0.0.1:$port/json" -TimeoutSec 3
        if ($targets) { break }
    } catch { }
}
if (-not $targets) {
    Write-Host '等不到调试端口，启动失败。' -ForegroundColor Red
    Read-Host '按回车退出'
    return
}

$page = ($targets | Where-Object { $_.type -eq 'page' })[0]
if (-not $page) {
    Write-Host '没找到 Codex 页面。' -ForegroundColor Red
    Read-Host '按回车退出'
    return
}

$js = @'
(function () {
  "use strict";
  var SKIP_TAGS = new Set(["SCRIPT","STYLE","NOSCRIPT","TEXTAREA","INPUT","SELECT","KBD","SAMP","SVG","CANVAS"]);
  var CODE_SEL = "pre,code,.monaco-editor,.cm-editor,[data-cx-zh-ignore]";
  var EDIT_SEL = "[contenteditable='true']";
  var MAX_TEXT_LEN = 220;
  var KEEP = new Set(["Codex","ChatGPT","OpenAI","GPT","API","CLI","Git","GitHub","JSON","URL","ID","Git","Visual Studio","PowerShell","MCP"]);
  var DICT = {
    "New chat":"新对话","Search":"搜索","Settings":"设置","Archive":"归档","Delete":"删除","Rename":"重命名",
    "Pin":"置顶","Unpin":"取消置顶","Share":"分享","Copy":"复制","Copy code":"复制代码","Copied":"已复制",
    "Edit":"编辑","Save":"保存","Cancel":"取消","Close":"关闭","Open":"打开","Done":"完成","Back":"返回",
    "Next":"下一步","Previous":"上一步","Continue":"继续","Skip":"跳过","Retry":"重试","Try again":"重试",
    "Refresh":"刷新","Reset":"重置","Clear":"清除","Add":"添加","Remove":"移除","Enable":"启用","Disable":"禁用",
    "Yes":"是","No":"否","OK":"确定","All":"全部","None":"无","More":"更多","Show more":"展开","Show less":"收起",
    "Show":"显示","Hide":"隐藏","View":"查看","Apply":"应用","Confirm":"确认","Dismiss":"忽略",
    "Scheduled":"已计划","Plugins":"插件","Explore":"探索","Recents":"最近","Projects":"项目","Project":"项目",
    "Pinned":"已置顶","Chats":"对话","Chat":"对话","Tasks":"任务","Task":"任务","Task list":"任务列表",
    "Loading":"加载中","Loading...":"加载中…","Error":"错误","Warning":"警告","Success":"成功","Failed":"失败",
    "No results":"无结果","Optional":"可选","Beta":"测试版","Coming soon":"即将推出","Send":"发送","Stop":"停止",
    "Message":"消息","Reply":"回复","Regenerate":"重新生成","You":"你","Thinking":"思考中","Reasoning":"推理",
    "Working":"处理中","Generating":"生成中","Agent":"智能体","Agents":"智能体","Environment":"环境",
    "Repository":"仓库","Branch":"分支","Pull request":"拉取请求","Commit":"提交","Diff":"差异","Changes":"更改",
    "Files":"文件","File":"文件","Folder":"文件夹","Code":"代码","Terminal":"终端","Output":"输出","Logs":"日志",
    "Preview":"预览","Browser":"浏览器","Run":"运行","Command":"命令","Execute":"执行","Test":"测试","Tests":"测试",
    "Build":"构建","Deploy":"部署","Merge":"合并","Revert":"还原","Worktree":"工作树","Sandbox":"沙箱",
    "Read-only":"只读","Network access":"网络访问","Working directory":"工作目录","Workspace":"工作区",
    "Summary":"总结","Context":"上下文","Plan":"计划","In progress":"进行中","Completed":"已完成","Pending":"待处理",
    "Blocked":"已阻塞","Approve":"批准","Approval":"审批","Deny":"拒绝","Allow":"允许","Allow once":"允许一次",
    "Always allow":"始终允许","Permission":"权限","Permissions":"权限","Full access":"完全访问","Log in":"登录",
    "Log out":"退出登录","Sign in":"登录","Sign up":"注册","Account":"账户","Profile":"个人资料","Upgrade":"升级",
    "Usage":"用量","Help":"帮助","About":"关于","Version":"版本","Language":"语言","Appearance":"外观","Theme":"主题",
    "Dark":"深色","Light":"浅色","Notifications":"通知","Privacy":"隐私","Keyboard shortcuts":"键盘快捷键",
    "Model":"模型","Mode":"模式","Tools":"工具","Skills":"技能","Automations":"自动化","General":"通用",
    "Advanced":"高级","Security":"安全","Members":"成员","Team":"团队","Just now":"刚刚","Today":"今天",
    "Yesterday":"昨天","This week":"本周","Earlier":"更早","Now":"现在",

    "Back to app":"返回应用","Personal":"个人","Archived chats":"已归档对话","Voice":"语音",
    "Configuration":"配置","Personalization":"个性化","Mini & Pets":"迷你助手","Integrations":"集成",
    "Computer use":"电脑操作","Hooks":"钩子","Environments":"环境","Worktrees":"工作树",
    "Default permissions":"默认权限","Projectless task folder":"无项目任务文件夹",
    "Default file open destination":"默认文件打开位置","Integrated terminal shell":"内置终端 Shell",
    "Confirm before closing a window":"关闭窗口前确认","Change":"更改","Learn more":"了解更多",
    "Language for the app UI":"应用界面语言","Default":"默认","Custom":"自定义","Select":"选择","Choose":"选择",
    "Available":"可用","Unavailable":"不可用","Manage":"管理","Connect":"连接","Disconnect":"断开",
    "Connected":"已连接","Install":"安装","Installed":"已安装","Update":"更新","Updated":"已更新","Create":"创建",
    "Created":"已创建","Import":"导入","Export":"导出","Duplicate":"复制一份","Move":"移动","Upload":"上传",
    "Download":"下载","View details":"查看详情","Show details":"显示详情","Hide details":"隐藏详情",
    "Edit settings":"编辑设置","Restore":"恢复","Restore default":"恢复默认","Restore defaults":"恢复默认",
    "Try it":"试用","Learn about":"了解","See all":"查看全部","View all":"查看全部","Go back":"返回",
    "Close window":"关闭窗口","Quit":"退出","Exit":"退出","Apply changes":"应用更改","Saved":"已保存",
    "Saving":"保存中","Saved successfully":"保存成功","Save failed":"保存失败",
    "Copied to clipboard":"已复制到剪贴板","Copy link":"复制链接","Refresh page":"刷新页面",
    "Skip for now":"暂时跳过","Not now":"暂不","Never":"从不","Always":"始终","Sometimes":"有时",
    "Never mind":"算了","Got it":"知道了","Continue anyway":"仍然继续","Are you sure?":"确定吗？",
    "You can change this later":"之后可以随时更改",

    "Attach files or connect apps":"添加文件或连接应用","Create a file or site":"创建文件或网站",
    "ChatGPT said:":"ChatGPT 说：","You said:":"你说：","Skip to content":"跳到主要内容",
    "Select effort":"选择推理强度","Minimal":"最低","Medium":"中等","High":"高","Extra High":"极高",
    "Max":"最大","Ultra":"超高","Persistent":"常驻","Latest response":"最新回复","Outputs":"输出",
    "Sources":"来源","Coding":"编程","Agent defaults":"智能体默认值","User config":"用户配置",
    "Open config.toml":"打开 config.toml","Approval policy":"审批策略",
    "Choose when ChatGPT asks for approval":"选择 ChatGPT 何时请求审批","Sandbox settings":"沙箱设置",
    "Choose how much ChatGPT can do when running commands":"选择 ChatGPT 运行命令时的权限范围",
    "Web search":"网页搜索","Choose how ChatGPT accesses the web":"选择 ChatGPT 访问网页的方式",
    "Output detail":"输出详细程度",
    "Choose how much detail ChatGPT includes in responses":"选择 ChatGPT 回复包含多少细节",
    "Reasoning summary":"推理摘要",
    "Choose how ChatGPT summarizes its reasoning":"选择 ChatGPT 如何总结推理过程",
    "Configure permissions, web access, and agent responses for new chats":"为新对话配置权限、网页访问和智能体回复",
    "On request":"按需","Read only":"只读","Cached":"使用缓存","Model default":"跟随模型默认","Auto":"自动",
    "Defaults":"默认值","Recommended":"推荐","Danger":"危险","Current":"当前",

    "Turn completion notifications":"完成时通知",
    "Set when ChatGPT alerts you that it's finished":"设置 ChatGPT 完成后何时提醒你",
    "Only when unfocused":"仅窗口未聚焦时","Enable permission notifications":"启用权限通知",
    "Show alerts when notification permissions are required":"需要通知权限时提醒",
    "Enable question notifications":"启用提问通知",
    "Show alerts when input is needed to continue":"需要你输入才能继续时提醒",
    "Enable dot notifications":"启用圆点通知",
    "Show alerts when your dot sends you a message":"你的圆点发来消息时提醒",
    "Notification sound":"通知声音",
    "Sound for task completion, permission requests, and questions":"任务完成、权限请求和提问时的提示音",
    "Visual style":"视觉风格","Accent":"强调色","Background":"背景","Foreground":"前景","Font":"字体",
    "System":"跟随系统","Dictation":"听写","Dictation unavailable":"听写不可用",
    "Dictation is not available in your current configuration":"当前配置不支持听写",
    "Codex memory":"Codex 记忆",
    "Configure how Codex manages memory for Local.":"配置 Codex 如何为本地管理记忆。","Local":"本地",
    "Enable Codex memories":"启用 Codex 记忆",
    "Create memories from chats on Local and use them to personalize future chats on Local":"从本地对话生成记忆，用于个性化以后的对话",
    "Allow memories from tool-assisted chats":"允许从使用工具的对话生成记忆",
    "Generate memories from chats that used MCP tools or web search":"从用过 MCP 工具或网页搜索的对话生成记忆",
    "Delete Codex memories":"删除 Codex 记忆","Delete all Codex memories for Local":"删除本地全部 Codex 记忆",
    "Custom instructions":"自定义指令","Codex instructions":"Codex 指令",
    "Edit the AGENTS.md file on the selected machine. Repository instructions may also apply.":"编辑所选机器上的 AGENTS.md 文件。仓库级指令可能同样生效。",
    "Search shortcuts":"搜索快捷键","Start a new chat":"开始新对话","New Temporary Chat":"新建临时对话",
    "Start a chat that won't appear in history":"开始一个不会进入历史的对话","Quick chat":"快速对话",
    "Start a lightweight chat in the quick composer":"在快速编辑器里开始一个轻量对话",
    "Archive chat":"归档对话","Archive the current chat":"归档当前对话","New standalone chat":"新建独立对话",
    "Start a new chat outside of any project":"在项目之外开始新对话","Open side chat":"打开侧边对话",
    "Open the current chat in a side chat":"把当前对话开到侧边","Copy last code block":"复制最后一个代码块",
    "Copy the last assistant code block in the current chat":"复制当前对话中最后一个助手代码块",
    "Delete chat":"删除对话","Confirm deletion of the current chat":"删除当前对话前先确认","Unassigned":"未分配",
    "Manage your Browser Use preferences and site access.":"管理浏览器使用偏好和站点访问权限。",
    "Disabled by your organization or unavailable in your region":"已被组织禁用，或在你所在地区不可用",
    "Import…":"导入…","Web URL and link open destination":"网页链接打开位置","Default browser":"默认浏览器",
    "Local URL open destination":"本地链接打开位置","Where local development sites open by default":"本地开发站点默认在哪里打开",
    "Show full URL":"显示完整网址","Include the path, query, and fragment in the address bar":"地址栏中显示路径、查询和片段",
    "Browsing data":"浏览数据",
    "Clear browsing history, site data, cache, and download history from the in-app browser":"清除内置浏览器的历史记录、站点数据、缓存和下载记录",
    "Clear browsing data":"清除浏览数据","Browsing history":"浏览历史",
    "View and manage pages visited in the built-in browser":"查看和管理内置浏览器访问过的页面",
    "Annotation screenshots":"批注截图",
    "Screenshots help ChatGPT better understand and address comments, but increase plan usage":"截图能帮 ChatGPT 更好地理解批注，但会增加套餐用量",
    "Autofill and passwords":"自动填充与密码","Branch prefix":"分支前缀",
    "Prefix used when ChatGPT creates new branches":"ChatGPT 创建新分支时使用的前缀",
    "Pull request merge method":"拉取请求合并方式","Choose how ChatGPT merges pull requests":"选择 ChatGPT 如何合并拉取请求",
    "Squash":"压缩合并","Always force push":"始终强制推送",
    "Use --force-with-lease when pushing from ChatGPT":"从 ChatGPT 推送时使用 --force-with-lease",
    "Create draft pull requests":"创建草稿拉取请求",
    "Use draft pull requests by default when creating PRs from ChatGPT":"从 ChatGPT 创建 PR 时默认用草稿",
    "Review delivery":"审查发送方式",
    "Start /review in the current chat when possible or launch a separate review chat":"尽量在当前对话里开始 /review，或另开一个审查对话",
    "Inline":"内联","Detached":"独立窗口","Watch and fix pull requests":"监视并修复拉取请求",
    "Auto-merge when ready":"就绪后自动合并","Continue watching until the pull request is merged":"持续监视直到拉取请求被合并",
    "Worktree root":"工作树根目录",
    "Directory where ChatGPT creates managed worktrees. Leave blank to use the default location":"ChatGPT 创建托管工作树的目录。留空则用默认位置",
    "Always fetch upstream before creating worktrees":"创建工作树前先拉取上游",
    "Codex normally picks up branch updates during regular Git activity. This also fetches before each new worktree.":"Codex 通常在日常 Git 操作中获取分支更新；开启后每次新建工作树前也会拉取。",
    "Automatically delete old worktrees":"自动删除旧工作树",
    "Recommended for most users. Turn this off only if you want to manage old worktrees and disk usage yourself.":"多数用户建议开启。只有你想自己管理旧工作树和磁盘占用时才关闭。",
    "Auto-delete limit":"自动删除上限","Fetching worktree details...":"正在获取工作树详情…",
    "Local environments tell ChatGPT how to set up worktrees for a project.":"本地环境告诉 ChatGPT 如何为项目准备工作树。",
    "Select a project":"选择项目","Add project":"添加项目",
    "No projects yet. Add one to configure local environments.":"还没有项目。添加一个即可配置本地环境。",

    "Composer":"编辑器","Plain text composer":"纯文本编辑器",
    "Keep code, Markdown, and links as literal text while writing messages":"写消息时把代码、Markdown 和链接当作纯文本处理",
    "Show context window usage":"显示上下文窗口用量","Send shortcut":"发送快捷键",
    "Choose when Enter sends a prompt or inserts a new line":"选择按 Enter 是发送还是换行",
    "Follow-up behavior":"后续消息行为","Queue":"排队","Steer":"转向",
    "Queue follow-ups while ChatGPT runs or steer the current run.":"ChatGPT 运行时把后续消息排队，或直接转向当前这一轮。",
    "Reasoning effort":"推理强度","Context window":"上下文窗口","Default model":"默认模型",
    "The location where tasks started outside of projects store their data by default.":"不在项目里启动的任务，其数据默认存放在这个位置。",
    "Where files and folders open by default":"文件和文件夹默认在哪里打开",
    "Choose which shell opens in the integrated terminal.":"选择内置终端使用哪个 Shell。",
    "Warn when a tab-close shortcut would close the window":"当关闭标签页的快捷键其实会关掉整个窗口时提醒",
    "Close shortcut only":"仅关闭快捷键时","Bottom panel":"底部面板",
    "Show the bottom panel control in the app header":"在应用顶栏显示底部面板按钮",
    "Compress local chat history":"压缩本地对话历史",
    "Save disk space by compressing older local chat history. Restart ChatGPT to apply changes.":"压缩较旧的本地对话历史以节省磁盘空间。重启 ChatGPT 后生效。",
    "Import work from other AI apps":"从其他 AI 应用导入",
    "Bring over your setup, projects, and recent chats":"把配置、项目和最近的对话迁移过来",
    "No data detected":"未检测到数据","Open source licenses":"开源许可证",
    "Third-party notices for bundled dependencies":"捆绑依赖的第三方声明",
    "Allow ChatGPT to use installed plugins":"允许 ChatGPT 使用已安装的插件",
    "Manage lifecycle hooks from config and enabled plugins.":"管理来自配置和已启用插件的生命周期钩子。",
    "No hooks found":"未找到钩子",
    "Configured hooks will appear here":"配置好的钩子会显示在这里",
    "Commit instructions":"提交信息指令",
    "Added to commit message generation prompts":"会加入生成提交信息的提示词中",
    "Add commit message guidance...":"添加提交信息指引…",
    "Pull request instructions":"拉取请求指令",
    "Added to PR title/description generation prompts":"会加入生成 PR 标题和描述的提示词中",
    "Add pull request guidance...":"添加拉取请求指引…",
    "For example: Comment /merge after checks pass and approve unrelated Chromatic changes...":"例如：检查通过后评论 /merge，并批准不相关的 Chromatic 变更…"
};
  var PLACEHOLDER = { "Work with Codex":"与 Codex 协作", "Ask for approval":"每次请求审批" };
  var RULES = [
    [/^(\d+)\s+files? changed$/i, function(m){return m[1] + " 个文件已更改";}],
    [/^Showing\s+(\d+)\s+of\s+(\d+)$/i, function(m){return "显示 " + m[1] + " / " + m[2];}],
    [/^(\d+)\s+results?$/i, function(m){return m[1] + " 个结果";}],
    [/^Ran for\s+(.+)$/i, function(m){return "运行了 " + m[1];}],
    [/^Thought for\s+(.+)$/i, function(m){return "思考了 " + m[1];}],
    [/^(\d+)\s+minutes? ago$/i, function(m){return m[1] + " 分钟前";}],
    [/^(\d+)\s+hours? ago$/i, function(m){return m[1] + " 小时前";}],
    [/^(\d+)\s+days? ago$/i, function(m){return m[1] + " 天前";}],
    [/^Codex is ignoring (\d+) unrecognized configuration setting/i, function(m){return "Codex 忽略了 " + m[1] + " 个无法识别的配置项，请检查拼写或已弃用的设置。";}]
  ];
  var originals = new WeakMap();
  var attrOriginals = new WeakMap();
  function collapse(s) { return s.replace(/\s+/g, " ").trim(); }
  function tr(raw) {
    if (!raw) return null;
    var key = collapse(raw);
    if (!key || key.length > MAX_TEXT_LEN) return null;
    if (KEEP.has(key)) return null;
    if (/[\u4e00-\u9fff]/.test(key)) return null;
    if (!/[A-Za-z]/.test(key)) return null;
    if (Object.prototype.hasOwnProperty.call(DICT, key)) return DICT[key];
    for (var i = 0; i < RULES.length; i++) { var m = key.match(RULES[i][0]); if (m) return RULES[i][1](m); }
    return null;
  }
  function doText(node) {
    var p = node.parentNode;
    if (!p || SKIP_TAGS.has(p.tagName)) return;
    if (p.closest && p.closest(CODE_SEL)) return;
    var key = collapse(node.nodeValue || "");
    var t = tr(node.nodeValue);
    if (!t && PLACEHOLDER[key]) t = PLACEHOLDER[key];
    if (!t) return;
    if (p.closest && p.closest(EDIT_SEL) && !PLACEHOLDER[key]) return;
    if (!originals.has(node)) originals.set(node, node.nodeValue);
    var a = node.nodeValue.match(/^\s*/)[0];
    var b = node.nodeValue.match(/\s*$/)[0];
    node.nodeValue = a + t + b;
  }
  var ATTRS = ["placeholder","data-placeholder","aria-placeholder","title","aria-label","alt"];
  function doAttr(el) {
    if (el.closest && el.closest("[data-cx-zh-ignore]")) return;
    for (var i = 0; i < ATTRS.length; i++) {
      var attr = ATTRS[i];
      if (!el.hasAttribute || !el.hasAttribute(attr)) continue;
      var raw = el.getAttribute(attr);
      var key = collapse(raw || "");
      var t = tr(raw) || PLACEHOLDER[key];
      if (!t) continue;
      var store = attrOriginals.get(el);
      if (!store) { store = {}; attrOriginals.set(el, store); }
      if (!(attr in store)) store[attr] = raw;
      el.setAttribute(attr, t);
    }
  }
  function walk(root) {
    if (!root) return;
    if (root.nodeType === Node.TEXT_NODE) return doText(root);
    if (root.nodeType !== Node.ELEMENT_NODE && root.nodeType !== Node.DOCUMENT_FRAGMENT_NODE) return;
    if (root.nodeType === Node.ELEMENT_NODE) {
      if (SKIP_TAGS.has(root.tagName)) return;
      if (root.closest && root.closest(CODE_SEL)) return;
      doAttr(root);
    }
    var w = document.createTreeWalker(root, NodeFilter.SHOW_TEXT | NodeFilter.SHOW_ELEMENT);
    var n = w.currentNode;
    while (n) {
      if (n.nodeType === Node.TEXT_NODE) doText(n);
      else if (n.nodeType === Node.ELEMENT_NODE) doAttr(n);
      n = w.nextNode();
    }
  }
  if (!window.__cxzhObserver) {
    var q = new Set(), s = false;
    var flush = function () { s = false; var b = q; q = new Set(); b.forEach(function(n){ if (n.isConnected) walk(n); }); };
    window.__cxzhObserver = new MutationObserver(function (ms) {
      ms.forEach(function (m) {
        if (m.type === "characterData") q.add(m.target);
        else m.addedNodes.forEach(function (n) { if (n.nodeType === 1 || n.nodeType === 3) q.add(n); });
      });
      if (!s) { s = true; requestAnimationFrame(flush); }
    });
    window.__cxzhObserver.observe(document.documentElement, { childList:true, subtree:true, characterData:true });
  }
  window.CXZH = {
    add: function (map) { Object.assign(DICT, map); walk(document.body); },
    rescan: function () { walk(document.body); },
    dict: DICT
  };
  walk(document.body);
  return "OK";
})();
'@

$ws = New-Object System.Net.WebSockets.ClientWebSocket
$ct = [System.Threading.CancellationToken]::None
$ws.ConnectAsync([Uri]$page.webSocketDebuggerUrl, $ct).Wait()

$script:seq = 0
function Send-Cdp([string]$method, $params) {
    $script:seq++
    $json = @{ id = $script:seq; method = $method; params = $params } | ConvertTo-Json -Depth 15 -Compress
    $bytes = [System.Text.Encoding]::UTF8.GetBytes($json)
    $ws.SendAsync([System.ArraySegment[byte]]::new($bytes), [System.Net.WebSockets.WebSocketMessageType]::Text, $true, $ct).Wait()
}
function Receive-Cdp {
    $buf = [byte[]]::new(4194304)
    $sb = New-Object System.Text.StringBuilder
    do {
        $r = $ws.ReceiveAsync([System.ArraySegment[byte]]::new($buf), $ct).Result
        [void]$sb.Append([System.Text.Encoding]::UTF8.GetString($buf, 0, $r.Count))
    } while (-not $r.EndOfMessage)
    return $sb.ToString()
}

Send-Cdp 'Page.addScriptToEvaluateOnNewDocument' @{ source = $js }
Receive-Cdp | Out-Null
Send-Cdp 'Runtime.evaluate' @{ expression = $js; returnByValue = $true }
$resp = Receive-Cdp | ConvertFrom-Json
$ws.Dispose()

if ($resp.result.exceptionDetails) {
    Write-Host '注入失败：' -ForegroundColor Red
    Write-Host ($resp.result.exceptionDetails | ConvertTo-Json -Depth 8)
} else {
    Write-Host '汉化完成！Codex 已在中文界面启动。' -ForegroundColor Green
}
Start-Sleep -Seconds 2