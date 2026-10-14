# sb — 住在终端里的网页浏览器

**中文** | [English](README.en.md)

`sb` 打开一个网页，然后像排版一篇文档那样铺在你的窗口里：标题还是标题，列表还是
列表，表格留着框线，链接可以选中，图片带颜色画出来。它是一个单独的文件，旁边不用
装任何东西；启动是瞬间的事，内存只用图形浏览器的一小截。

它不跑 JavaScript，所以那种要靠脚本才拼得出来的页面，你看到的就是服务器发来的那份。
不靠脚本也能看到的内容，整页都在。

## 安装

    curl -fsSL https://github.com/2982136527/shell-browser-releases/raw/main/install.sh | sh

这条会挑对你这台机器的构建，核对发布出来的 SHA-256，然后以 `sb` 这个名字放进你的
PATH。macOS 和 Linux，Apple 芯片和 Intel 都有。

**在国内**，GitHub 常常连不上——上面那条命令连自己都下载不下来。同一份脚本、同一批
构建在 cnb.cool 上也有一份：

    curl -fsSL https://cnb.cool/2982136527/shell-browser-releases/-/releases/download/latest/install.sh | sh

两条都会先核对构建的 SHA-256 再运行，都不需要 git。

## 用法

    sb https://news.ycombinator.com
    sb ~/notes/meeting.md          # 一篇 markdown 笔记，图片照画
    sb ~/小说/书.txt                # 一本 txt，文件是什么编码它就按什么读
    sb                             # 回到上次看到的地方

从自己硬盘上打开的文件，位置是按文件记的：再打开它，就回到上次停下的那句话——
哪怕这次窗口宽度不一样。按 `i` 能看到它把这份文件当成什么编码读出来的。

进了页面之后：

| 键 | 做什么 |
| --- | --- |
| `j` `k`、`PgDn` `PgUp`、`Space` `b`、`Home` `End` | 在页里移动 |
| `l` | 列出这一页所有链接，跳到其中一个 |
| `Enter` | 打开选中的链接 |
| `←` `→` | 后退和前进 |
| `t` | 阅读模式：只留正文 |
| `/` | 页内查找，`n` 是下一个 |
| `g` | 换地址（`Ctrl-R` 先翻收藏，再翻去过的地方） |
| `m` | 收藏这个地址 |
| `w` | 存下这一页，或者光标上那张图 |
| `o` | 把这一页交给真浏览器 |
| `P` | 停下和放开会动的图 |
| `I` | 图片整个关掉：原来那张图的位置留一个 `[img]` 标记 |
| `K` | 换一种画法：让终端自己画（kitty，再按一下是 iTerm2），或者由浏览器画成彩色方块。图的位置一片空白就是这一键：下一档就是彩色方块 |
| `Ctrl-L` | 重画屏幕 |
| `?` | 完整的键表 |

表单能用：`sb https://example.com/login`，直接在框里打字，`Tab` 换框；口令那一格
不会离开你的键盘，不会跑到命令行或地址栏里。

## 保持最新

    sb update

`sb` 会问哪个版本是最新的，下载那一份构建，跟发布出来的 SHA-256 核对，对上了才
替换自己。校验不过，一个文件都不动。

构建放在两个地方——github.com 和 cnb.cool——`sb` 用先答话的那个，并且把这次管用的
记下来留给下次。想钉死一个：

    SB_HOST=cnb     # 或 github，管的是安装脚本
    SHELL_BROWSER_HOST=cnb   # 或 github，管的是 sb update

`SB_VERSION=v0.1.16` / `SB_INSTALL_DIR=~/.local/bin` 管的是取哪个版本、装到哪里。

安装脚本在目录还不在 PATH 里的时候会把它加进去：按你的 shell 往 `~/.zshrc`、
`~/.bashrc` 或 `~/.profile` 写一段带守卫的块，并且说清它动了哪个文件。目录本来就
找得到的话它一个字都不写，同一段也不会写两遍。不想让它碰你的 shell 配置：
`SB_NO_PATH=1`。

## 几个值得知道的选项

    sb --help            全部选项
    --graphics=off       图片一律自己画成彩色方块，不叫终端摆放
    --graphics=kitty     用 kitty 协议问终端
    --graphics=iterm2    用 iTerm2 的转义问终端
    --charset=gbk        不信文件自己说的，按这个编码读；不指定时 auto 会猜
                         （utf-8、gb18030、big5、utf-16）
    --image-cols=N       图片最宽多少列
    --main               一进来就是阅读模式
    --no-history         不记你去过哪里
    --insecure           接受没验过的证书（这是个警告，不该变成习惯）

cookie、历史、收藏都是你配置目录下的普通文件，每一个都能另指位置或者关掉。

## 隐私

除了你要的那些页面，它什么都不往外发。没有统计，没有除你主动跑 `sb update` 之外的
更新心跳，也没有账号。
