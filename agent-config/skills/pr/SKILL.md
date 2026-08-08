---
name: pr
description: 現在のブランチからPRを作成するコマンド (push + gh pr create) を出力する
disable-model-invocation: true
---

現在のブランチの内容から、PRを作成するためのコマンドを出力してください。コマンドの実行はせず、ユーザーが実行できる形で出力すること (PR作成はユーザーが行う運用)。

引数 (任意): $ARGUMENTS — Issue番号や補足指示があればそれに従う。

手順:

1. ベースブランチを `git symbolic-ref refs/remotes/origin/HEAD` (取れなければ main / master のうち存在する方) で特定し、`git log --oneline <base>..HEAD` と `git diff --stat <base>..HEAD` で変更内容を把握する。
2. ブランチ名が `feat/#N-...` 形式ならIssue番号 N を特定し、`gh issue view N` で内容を確認して本文冒頭に `Closes #N` を入れる。Issueに紐付かない作業なら省略する。
3. 本文はこのリポジトリの過去PRの様式に合わせて次の3節で構成する (必要なら `gh pr view` で直近のマージ済みPRを参照):
   - `## 実装したこと` — 変更点を具体的な箇条書きで。設計判断 (なぜそうしたか) も一行添える
   - `## 確認したこと` — そのプロジェクトのテスト・型チェック・Lint・ビルドの実行結果 (件数を含む) と、実画面での動作確認の有無を正直に書く (未実施なら未実施と書く)
   - `## レビューしてもらいたいこと` — 挙動変更・判断が分かれる点・未確認箇所。無ければ「なし」
4. タイトルは過去PRと同様に日本語の簡潔な要約 (例: 「回答CSVの出力フォーマットを更新」)。
5. 出力するコマンドは次の2つ。それぞれ独立した bash コードブロックにする:
   - `git push -u origin <ブランチ名>`
   - `gh pr create --base <base> --head <ブランチ名> --title "..." --body "..."`
