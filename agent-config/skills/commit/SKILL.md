---
name: commit
description: 現在の変更をコミットする
disable-model-invocation: true
allowed-tools: Bash(git status), Bash(git diff *), Bash(git log *), Bash(git add *), Bash(git commit *)
---

現在の作業ツリーの変更をコミットしてください。

引数 (任意): $ARGUMENTS — コミットメッセージや対象ファイルの指定があればそれに従う。指定がなければ変更内容から自分で判断する。

手順:

1. `git status` と `git diff HEAD` で変更内容を把握する。ステージ済みの変更だけがある場合はそれをそのままコミット対象とし、未ステージの変更しかない場合は関連するファイルを `git add` する。
2. `git log --oneline -10` で、このリポジトリのコミットメッセージの言語・様式に合わせる。
3. コミットする。`git commit -m` のみを使い、`--amend` や `--no-verify` は使わない。
4. `git log --oneline -1` で結果を報告する。

注意:

- push はしない。PR作成もしない。
- ブランチが main / master の場合は、コミットしてよいか確認してから進める。
- 意図せず混ざった無関係な変更 (デバッグ用の一時ファイル、`.env` 等) があれば、コミットせずに報告する。
- pre-commit フックで失敗したら、内容を確認して修正し、フックを回避せずに再コミットする。
