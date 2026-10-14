# sb — a web browser that lives in your terminal

`sb` opens a web page and sets it in your window like a document: headings stay
headings, lists stay lists, tables keep their rules, links are selectable, and
pictures are drawn in colour. It is one file with nothing to install alongside
it, it starts instantly, and it uses a fraction of the memory a graphical
browser does.

There is no JavaScript, so a page that builds itself in the browser shows you
what the server sent. Every page you can see without scripting comes through
whole.

## Install

    curl -fsSL https://github.com/2982136527/shell-browser-releases/raw/main/install.sh | sh

This picks the build for your machine, checks its published SHA-256, and puts it
on your PATH as `sb`. macOS and Linux, Apple silicon and Intel.

**In mainland China**, GitHub is often unreachable — the command above cannot
even download itself. The same script and the same builds are on cnb.cool:

    curl -fsSL https://cnb.cool/2982136527/shell-browser-releases/-/releases/download/latest/install.sh | sh

Both check the build's SHA-256 before running anything, and neither needs git.

## Use

    sb https://news.ycombinator.com
    sb ~/notes/meeting.md          # a markdown note, pictures and all
    sb                             # where you left off last time

Then, inside the page:

| key | what it does |
| --- | --- |
| `j` `k`, `PgDn` `PgUp`, `Space` `b`, `Home` `End` | move through the page |
| `l` | list every link, jump to one |
| `Enter` | follow the selected link |
| `←` `→` | back and forward |
| `t` | reading mode: the article alone |
| `/` | find in page, `n` for the next match |
| `g` | go to another address (`Ctrl-R` recalls where you have been) |
| `m` | keep this address |
| `w` | save the page, or the picture under the cursor |
| `o` | hand the page to a real browser |
| `P` | stop and start moving pictures |
| `I` | take the pictures off altogether: the page keeps `[img]` markers where they were |
| `K` | change how pictures are drawn: the terminal paints them (kitty, then iTerm2), or the browser draws them as coloured blocks. If a picture area is blank, this is the key: the next stop is coloured blocks |
| `Ctrl-L` | redraw the screen |
| `?` | the whole key list |

Forms work: `sb https://example.com/login`, type into the fields, `Tab` to move
between them, and the password field never leaves your keyboard for the command
line or the address bar.

## Keep it up to date

    sb update

`sb` asks which release is newest, downloads that build, checks it against the
published SHA-256, and only then replaces itself. Nothing is replaced unless the
checksum agrees.

Two places hold the builds - github.com and cnb.cool - and `sb` uses whichever
one answers, remembering it for next time. If you would rather pin one:

    SB_HOST=cnb     # or github, for the install script
    SHELL_BROWSER_HOST=cnb   # or github, for sb update

and `SB_VERSION=v0.1.4` / `SB_INSTALL_DIR=~/.local/bin` control which build and
where it goes.

The installer adds its directory to your PATH if it is not already there, writing
a guarded block into `~/.zshrc`, `~/.bashrc` or `~/.profile` depending on your
shell, and saying which file it touched. It writes nothing when the directory is
already reachable, and never writes the same block twice. To keep your shell
config out of it: `SB_NO_PATH=1`.

## Options worth knowing

    sb --help            every flag
    --graphics=off       draw pictures as coloured blocks instead of asking the
                         terminal to place an image
    --graphics=kitty     ask the terminal, with the kitty protocol
    --graphics=iterm2    ask the terminal, with the iTerm2 escape
    --image-cols=N       widest a picture may be
    --main               start in reading mode
    --no-history         do not remember where you went
    --insecure           accept an unverified certificate (a warning, not a habit)

Cookies, history and bookmarks are plain files under your config directory, and
each one can be pointed elsewhere or switched off.

## Privacy

Nothing is sent anywhere except the pages you ask for. There is no analytics, no
update pings beyond the one `sb update` makes when you run it, and no account.
