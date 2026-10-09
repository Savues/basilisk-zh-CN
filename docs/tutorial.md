# Basilisk 汉化使用教程

本文面向两类读者：

- **只想装上中文界面** → 看 [第一章](#一三分钟装上)，两条命令的事；
- **想知道为什么这么麻烦 / 想自己维护** → 看 [第四章](#四basilisk-的语言机制是怎么工作的) 与 [第五章](#五官方-pale-moon-语言包为什么用不了)。

---

## 一、三分钟装上

### 前提

- 已安装 **Basilisk 52.9.2026.09.24** (x64 en-US)
- 完全退出 Basilisk（托盘里也要退）

### 步骤

**1. 拿到汉化包**

- 直接下载：<https://github.com/Savues/basilisk-zh-CN/releases> 里下载 `basilisk-zh-CN-52.9.2026.09.24.zip`，解压
- 或者克隆仓库：

```bash
git clone https://github.com/Savues/basilisk-zh-CN.git
```

**2. 运行安装脚本**

在解压出来的目录里打开 PowerShell：

```powershell
powershell -ExecutionPolicy Bypass -File .\install.ps1
```

脚本会：

1. 从注册表找 Basilisk 安装目录，找不到就提示你手动输入；
2. 把原始的 `omni.ja` / `browser\omni.ja` 备份成 `*.orig-enUS`；
3. 覆盖两个 `omni.ja`，并写入 `defaults\pref\firefox-l10n.js`。

**3. 启动 Basilisk，界面就是中文了。**

### 怎么确认装成功了

打开任意内置页面，看**窗口标题栏**（地址栏本身不会变中文，这是正常的）：

| 打开 | 标题应显示 |
| --- | --- |
| `about:preferences` | 首选项 - Basilisk |
| `about:addons` | 附加组件管理器 - Basilisk |
| `about:downloads` | 下载 - Basilisk |
| 空白页 | Basilisk 开始页 - Basilisk |

标题栏来自本地化 DTD，是最可靠的验证方式。

### 换回英文

```powershell
powershell -ExecutionPolicy Bypass -File .\uninstall.ps1
```

它会把 `omni.ja.orig-enUS` 备份盖回去。**不要手动删这两个备份文件**，删了就恢复不了。

---

## 二、自动更新后汉化会失效

Basilisk 更新时会重写 `omni.ja`，中文就没了。

- 版本没变（只是补丁更新）→ 重跑一次 `install.ps1` 就行；
- 版本变了（比如升到 52.10）→ 现有的包**不保证能用**，见 [第六章](#六想给新版本做汉化)。

---

## 三、几个常见疑问

### 拼写检查词典还是英文的？

正常。语言包**只改界面文字**，不改拼写检查用的词典。

右键任意文本框 → **语言 → 添加词典…**，自己去下载中文词典（`zh-CN`）。

### 有些地方还是英文

官方对 Pale Moon 语言包的说明里也写明了这一点。以下界面**本来就是英文**，不属于漏翻：

- 安全模式（Safe Mode）对话框
- `about:` 页面里部分字段
- 默认书签夹名称（Bookmarks Toolbar / Other Bookmarks）
- 搜索引擎专有名词（Ecosia、Wikipedia 等）
- 访问键（accesskey，即 `Alt+某键` 的助记键）——刻意保留原文，避免和译文冲突

当前覆盖率 **98.6%**（已译 9396 / 9528 条），未译部分主要是开发者工具图表标签等，本来 Mozilla 官方 zh-CN 语言包也没翻。

### 汉化包会不会和浏览器打架？

不会。它只是往 `omni.ja` 里加了 `chrome/zh-CN/` 目录并改了一行 manifest，**保留**了全部原始 en-US 资源条目。

> 提醒一个坑：如果你**删掉** en-US 实体条目只留中文，浏览器窗口会渲染失败变成白屏。必须两个都留着。

### 想改个别词条？

不能直接改打包好的 `omni.ja`（改了下次重装就丢）。正确做法是改源码再重新构建，见 [第六章](#六想给新版本做汉化)。

---

## 四、Basilisk 的语言机制是怎么工作的

### 它没有"界面语言"下拉框

Basilisk 走的是老式 Gecko 本地化方案：

- **没有** Firefox 那种 `intl.locale.requested` 首选项
- **没有**现代 WebExtension 式的 langpack 分发
- 首选项里**没有**语言选择器

安装目录 `defaults\pref/` 下只有两个 pref 文件，其中和语言有关的只有 `general.useragent.locale`。**界面语言完全由 `omni.ja` 内部决定。**

### 真正的开关是 chrome.manifest

原始的 `omni.ja` 里，`chrome/chrome.manifest` 开头是这样：

```
locale alerts     en-US  en-US/locale/en-US/alerts/
locale global     en-US  en-US/locale/en-US/global/
locale mozapps    en-US  en-US/locale/en-US/mozapps/
... 共 14 条，全部是 en-US
```

Gecko 启动时读这张 locale 注册表。想让界面变中文，就得**注册一个 zh-CN locale**。

本仓库的做法：

1. 解出 `omni.ja` 里 `chrome/en-US/locale/` 下的全部 `.dtd` / `.properties`（Basilisk 共 302 个文件）；
2. 灌入中文译文；
3. 把 zh-CN 条目**加进同一个 `omni.ja`**（en-US 原样保留）；
4. 把 manifest 里那 14 行的 locale 改指向 zh-CN 路径。

这样 Gecko 的 locale 注册表里就有了 zh-CN，界面随之切换。`general.useragent.locale` 在这套机制里其实不起决定作用（它管的是 `Accept-Language` 协商），设成 `zh-CN` 只是让 HTTP 请求头更合理。

### 为什么译文能直接搬过来

Basilisk 是从 Gecko 52 分支出来的，包名和目录结构与 Firefox 52 **完全一致**：

```
alerts/  autoconfig/  cookie/  formautofill/  global/  global-platform/
mozapps/  necko/  passwordmgr/  pipnss/  pippki/  places/
pluginproblem/  services/   + browser/  branding/  browser-region/  pdfviewer/
```

而且两边都是**纯 DTD / .properties，0 个 FTL**，所以能按键 1:1 合并。译文取自 Mozilla 官方 Firefox 52.0.2 简体中文语言包。

---

## 五、官方 Pale Moon 语言包为什么用不了

Pale Moon 官方**有**社区语言包，而且包含简体中文：

- 列表页：<https://addons.palemoon.org/language-packs/>
- 简体中文包：`langpack-zh-CN@palemoon.org`，版本 35.0.0（2026-09-17 更新）
- 官方标注兼容范围：`Pale Moon 35.0.0a1 ~ 35.0.*`

**在 Pale Moon 上**，官方给出的用法是：

```
1. 下载 .xpi，在浏览器里安装
2. about:config 里把 general.useragent.locale 从 en-US 改成 zh-CN
3. 完全退出并重启浏览器
```

也可以安装官方的 *Pale Moon Locale Switcher* 扩展，用工具栏上的地球图标图形化切换。

### 为什么不适用于 Basilisk

**Basilisk 和 Pale Moon 在 Gecko 眼里是两个不同的 application：**

| | Application ID | 版本 |
| --- | --- | --- |
| Pale Moon | `{8de7fcbb-c55c-4fbe-bfc5-fc555c87dbc4}` | 35.0.2 |
| **Basilisk** | `{ec8030f7-c20a-464f-9b0e-13a3a9e97384}` | 52.9.2026.09.24 |

而语言包的 `install.rdf` 写着：

```xml
em:strictCompatibility="true"
<em:targetApplication><em:id>{8de7fcbb-...}</em:id></em:targetApplication>
```

严格兼容性 + 应用 ID 不匹配，安装被拒。

**本仓库实测过的三条路，都不行：**

1. `basilisk.exe -install-global-extension <xpi>` → 静默失败，`extensions.json` 里没有它（`em:type="8"` 的语言包不走命令行安装路径）；
2. 用 `file://` 打开 xpi → 只渲染出一个空白页，不触发安装流程；
3. 把 `install.rdf` 的 target ID 改成 Basilisk 的、再重打包，并手动登记进 profile 的 `extensions.json` → 仍然不注册 zh-CN locale，界面仍是英文。

顺带说明：Basilisk 52.9 发布于 2026-09-24，正好落在 Pale Moon 35.0.0（09-17）到 35.0.2（10-06）之间，**版本世代是对得上的**，唯一的障碍就是这个 app ID。所以单独给 Basilisk 做一份汉化是必要的。

### 官方语言包的内容长什么样

值得一看，它正好印证了第四节：`chrome/zh-CN.manifest` 里是标准的 locale 注册表。

```
locale global zh-CN zh-CN/locale/zh-CN/global/
locale mozapps zh-CN zh-CN/locale/zh-CN/mozapps/
...
```

包内 188 个 `chrome/zh-CN/` 文件、共 292 个 `.dtd`/`.properties`，**同样 0 个 FTL**。也就是说，本仓库走的技术路线和官方语言包是完全一致的思路，只是官方那份走扩展系统（因此受 app ID 约束），本仓库直接改 `omni.ja`（因此绕开了约束）。

---

## 六、想给新版本做汉化

需要：PowerShell、一个装好的 Basilisk、以及 `work/langpack52.xpi`（Mozilla 官方 Firefox 52.0.2 zh-CN 安装程序，用 7-Zip 或 bsdtar 解出 `core/omni.ja` 和 `core/browser/omni.ja`）。

```powershell
# 1. 构建（会自动备份原始 omni.ja 为 *.orig-enUS）
powershell -ExecutionPolicy Bypass -File .\tools\build-zhcn.ps1 -Install "F:\Progeam\Basilisk"

# 2. QA 校验
powershell -ExecutionPolicy Bypass -File .\tools\qa.ps1
```

`qa.ps1` 必须输出 `QA: 0 problems` 才算通过，它会检查：文件缺失、行数不一致、键顺序错乱、多行 DTD 实体被破坏、properties 续行结构、BOM、UTF-8 合法性。

手工补译写在 `tools/patch.tsv`（浏览器侧）和 `tools/patch-toolkit.tsv`（工具包侧），格式是 `key>>>译文`。

构建完的 `omni.toolkit.zh.ja` / `omni.browser.zh.ja` 复制回安装目录，再跑一遍 `install.ps1` 即可。

---

## 七、来源与许可

- 界面译文来自 **Mozilla 官方 Firefox 52.0.2 简体中文语言包**，版权归 Mozilla 及其贡献者，以 **MPL-2.0** 授权。
- 本仓库的脚本与打包产物同样以 **MPL-2.0** 发布（见 [LICENSE](../LICENSE)）。
- Basilisk 是 Pale Moon 公司基于 Mozilla Gecko 代码库开发的浏览器。本项目为**非官方**第三方项目，与 Mozilla、Pale Moon 无隶属或背书关系。
- 如果你想要**更完整、持续维护**的译文，欢迎去 <https://crowdin.com/project/pale-moon> 参与 Pale Moon 语言包的翻译；本仓库的译文基线较旧（Firefox 52，2016 年），新界面字符串只能靠手工补。