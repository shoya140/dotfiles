---
name: share-memory
description: プロジェクトの auto memory を Dropbox の共有フォルダに移して、ほかの Mac と同じメモリを使えるようにする。「このプロジェクトのメモリを共有して」と頼まれたときに使う。
---

# プロジェクトのメモリを共有する

共有フォルダは `~/Library/CloudStorage/Dropbox/active/config/claude/memory/<名前>`。
<名前> は、プロジェクトのルートの実際のパス (シンボリックリンクをたどった先) が `~/Library/CloudStorage/Dropbox/active/` の中ならそこからの相対パス (例: `src/www/peco-generator`)、外ならホームからの相対パスに `home/` を付けたもの (例: `home/dotfiles`)。

1. プロジェクトのルートを決める。git のリポジトリなら本体のルート (worktree の中にいても本体の方。`git rev-parse --path-format=absolute --git-common-dir` の親)、そうでなければ今のディレクトリ。
2. 共有フォルダを作る。
3. この Mac の元のメモリ (`~/.claude/projects/` と `~/.claude-api/projects/` の中の、ルートのパスの英数字以外を `-` にした名前のフォルダの `memory/`) にファイルがあれば、共有フォルダにコピーする。同じ名前のファイルがすでにあれば上書きせず、中身を比べてまとめる。MEMORY.md は足りない行だけ足す。マシン固有の値 (シミュレータの UDID、インストール先のパスなど) が書かれていれば、調べ方に書き換える。元のフォルダはそのまま残す。
4. ルートの `.claude/settings.local.json` (なければ作る) に `"autoMemoryDirectory": "~/Library/CloudStorage/Dropbox/active/config/claude/memory/<名前>"` を足す。ほかの設定は消さない。
5. 開いているセッションを起動し直すよう伝える。プロジェクトが Dropbox の外なら、ほかの Mac でもこのスキルを使うよう伝える。
