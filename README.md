# Basilisk 简体中文汉化（zh-CN）

给 [Basilisk](https://basilisk-browser.com/) 用的简体中文语言包。Basilisk 官方没有提供中文，
这个仓库把 Mozilla 官方 Firefox 52 的简体中文译文移植过来，打包成 Basilisk 能识别的 `omni.ja`。

| 项目 | 值 |
| --- | --- |
| 适用版本 | Basilisk **52.9.2026.09.24** (x64 en-US) |
| BuildID | 20260922233924 |
| 译文来源 | Mozilla 官方 **Firefox 52.0.2 简体中文**语言包 |
| 覆盖率 | **98.6%**（已译 9396 / 9528 条界面字符串） |
| 许可 | MPL-2.0（见 [LICENSE](LICENSE)，译文版权属 Mozilla） |

## 效果

界面、设置、附加组件管理器、下载、隐私面板、开发者工具等全部中文化：

- 首选项 / 附加组件管理器 / 下载 / 关于 Basilisk 的窗口标题均为中文
- 保留 Basilisk 自己的品牌名（不会把该显示 Basilisk 的地方换成 "Firefox"）
- 保留 UTF-8 编码与所有 DTD 实体引用，多行 DTD 实体结构逐字校验

## 安装

先把仓库克隆下来（或直接下载 [Releases](https://github.com/YOUR_ACCOUNT/basilisk-zh-CN/releases) 里的 zip 解压），
然后在仓库目录下用 PowerShell 运行：

```powershell
powershell -ExecutionPolicy Bypass -File .\install.ps1
```

脚本会自动从注册表找 Basilisk 安装目录，找不到就提示你手动输入，
然后备份原文件、覆盖语言包，最后提示你启动浏览器。

也可以手动覆盖（需先完全退出 Basilisk）：

| 文件 | 说明 |
| --- | --- |
| `<安装目录>\omni.ja` | 工具包（toolkit）语言资源 |
| `<安装目录>\browser\omni.ja` | 浏览器界面语言资源 |
| `<安装目录>\defaults\pref\firefox-l10n.js` | 设置 `general.useragent.locale` 为 `zh-CN` |

## 卸载 / 还原英文

```powershell
powershell -ExecutionPolicy Bypass -File .\uninstall.ps1
```

会把 `omni.ja.orig-enUS` 备份覆盖回去。请不要手动删掉这两个备份文件。

## 自动更新会让汉化失效

Basilisk 更新后 `omni.ja` 会被换成新的英文版，中文就没了。重新跑一次 `install.ps1` 即可，
但如果版本号变了，通常需要用对应新版本的汉化包重打一遍（见下面的「自行构建」）。

## 工作原理

Basilisk 走的是老式 Gecko 本地化：**没有** langpack 机制，也没有 `intl.locale.requested` 这个 pref。
界面语言由 `omni.ja` 里 `chrome/chrome.manifest` 的 `locale` 行决定。所以这个汉化包：

1. 从 `omni.ja` / `browser/omni.ja` 里解出 `chrome/en-US/locale/` 下的全部 `.dtd` 与 `.properties`；
2. 用 Firefox 52 zh-CN 语言包的同名文件按键合并翻译（Basilisk 的目录结构和 Firefox 52 完全一致，能 1:1 映射）；
3. **保留**原始 en-US 实体条目，把 zh-CN 条目加进同一个 `omni.ja`，并把 manifest 的 locale 行改指向 zh-CN；
4. 打回两个 `omni.ja`，替换回安装目录。

注意第 3 条：必须保留 en-US 条目，只删掉它会让浏览器窗口渲染失败（白屏）。

翻译过程中做了品牌名修正——Firefox 52 的中文译文里硬编码了 "Firefox"，
但 Basilisk 的英文原文有的用 `&brandShortName;`、有的已经去掉了品牌名，
所以只在英文原文不含 `Firefox` 时，才把译文里的 `Firefox` / `火狐` 换成 `Basilisk`（URL 里的 `firefox` 不动）。

## 目录结构

```
.
├── install.ps1              # 安装 / 备份 / 覆盖
├── uninstall.ps1            # 还原英文
├── files/
│   ├── omni.ja              # 打好包的 toolkit 语言资源（已注入 zh-CN）
│   ├── browser/omni.ja      # 打好包的浏览器界面语言资源（已注入 zh-CN）
│   └── defaults/pref/firefox-l10n.js
└── tools/                   # 构建与 QA 脚本（构建汉化包用）
    ├── build-zhcn.ps1       # 主构建：抽取 → 翻译 → 打包两个 omni.ja
    ├── translate-fx52.ps1   # 翻译器：按键合并 + 实体/占位符校验 + 品牌名修正
    ├── qa.ps1               # QA：行数/键序/续行/多行实体/BOM/UTF-8 校验
    ├── patch.tsv            # 手工补译（浏览器侧，key>>>译文）
    └── patch-toolkit.tsv    # 手工补译（工具包侧）
```

## 自行构建

需要 PowerShell、一个已安装的 Basilisk，以及 `work/langpack52.xpi`
（Mozilla 官方 Firefox 52.0.2 zh-CN 安装程序，用 7-Zip / bsdtar 解出 `core/omni.ja` 和 `core/browser/omni.ja`）：

```powershell
powershell -ExecutionPolicy Bypass -File .\tools\build-zhcn.ps1 -Install "F:\Progeam\Basilisk"
powershell -ExecutionPolicy Bypass -File .\tools\qa.ps1
```

`build-zhcn.ps1` 会保留原 en-US 备份（`omni.ja.orig-enUS`），译完再打包。
QA 必须输出 `QA: 0 problems` 才算通过。

## 未翻译的 1.4% 是什么

主要是：

- **访问键（accesskey）** —— 界面上 `Alt+某键` 的助记键，保留原样以免和译文冲突；
- **搜索引擎名称** —— Ecosia / Ekoru / Wikipedia / Yahoo 这类专有名词；
- **Firefox 52 之后新增的少数字符串** —— 绝大部分已经用 `tools/patch*.tsv` 手工补上了，
  剩下的是开发者工具里的图表轴标签之类，本来 Mozilla 自己的 zh-CN 语言包也没翻。

这些条目会以英文显示，属正常现象。

## 许可与致谢

本仓库的脚本与打包产物以 **MPL-2.0** 发布（见 `LICENSE`）。

界面译文来自 Mozilla 官方 Firefox 52.0.2 简体中文语言包，版权归 Mozilla 及其贡献者所有，
同样以 MPL-2.0 授权。本项目**不是** Mozilla 或 Pale Moon 的官方产品，
Basilisk 的商标归 Pale Moon 所有。
