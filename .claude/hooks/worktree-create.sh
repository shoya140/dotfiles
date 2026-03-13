#!/bin/bash
# WorktreeCreate hook for Claude Code
#
# デフォルトの git worktree 作成を置き換え、以下を行う:
#   1. feature/<name> 形式のブランチ命名（gitflow規約）
#   2. .worktreeinclude に記載されたファイルを新しい worktree にコピー
#
# 入力 (stdin JSON): { "name": "<slug>", "cwd": "<project-root>", ... }
# 出力 (stdout):     作成した worktree の絶対パス
#
# 情報メッセージはすべて stderr に出力し、stdout はパスのみにする。

set -e

# --- stdin から JSON 入力を読む（1回しか読めない） ---
INPUT=$(cat)

if ! command -v jq &>/dev/null; then
  echo "Error: jq が必要です。インストールしてください。" >&2
  echo "  macOS:   brew install jq" >&2
  echo "  Ubuntu:  sudo apt install jq" >&2
  exit 1
fi

NAME=$(echo "$INPUT" | jq -r '.name')
CWD=$(echo "$INPUT" | jq -r '.cwd')

# --- クロスプラットフォーム対応（Windows Git Bash 用） ---
to_unix_path() {
  if command -v cygpath &>/dev/null; then
    cygpath -u "$1"
  else
    echo "$1"
  fi
}

to_native_path() {
  if command -v cygpath &>/dev/null; then
    cygpath -w "$1"
  else
    echo "$1"
  fi
}

# --- パス設定 ---
if [[ -n "$CWD" && "$CWD" != "null" ]]; then
  GIT_ROOT=$(to_unix_path "$CWD")
else
  GIT_ROOT=$(git rev-parse --show-toplevel)
fi

WORKTREE_DIR="$GIT_ROOT/.claude/worktrees"
WORKTREE_PATH="$WORKTREE_DIR/$NAME"
BRANCH_NAME="feature/$NAME"

# --- .claude/worktrees を .gitignore に追加（未登録の場合） ---
GITIGNORE="$GIT_ROOT/.gitignore"
if ! grep -qF '.claude/worktrees' "$GITIGNORE" 2>/dev/null; then
  if [[ -f "$GITIGNORE" ]] && [[ -n "$(tail -c 1 "$GITIGNORE")" ]]; then
    echo "" >> "$GITIGNORE"
  fi
  echo ".claude/worktrees" >> "$GITIGNORE"
  echo ".claude/worktrees を .gitignore に追加しました" >&2
fi

# --- ベースブランチの特定 ---
DEFAULT_BRANCH=$(git symbolic-ref refs/remotes/origin/HEAD 2>/dev/null \
  | sed 's@^refs/remotes/origin/@@') || true

if [[ -z "$DEFAULT_BRANCH" ]]; then
  for candidate in dev main master; do
    if git show-ref --verify --quiet "refs/remotes/origin/$candidate" 2>/dev/null; then
      DEFAULT_BRANCH="$candidate"
      break
    fi
  done
fi
DEFAULT_BRANCH="${DEFAULT_BRANCH:-main}"

# --- worktree を作成 ---
mkdir -p "$WORKTREE_DIR"

if git show-ref --verify --quiet "refs/heads/$BRANCH_NAME" 2>/dev/null; then
  echo "既存ブランチを使用: $BRANCH_NAME" >&2
  git worktree add "$WORKTREE_PATH" "$BRANCH_NAME" >&2
else
  echo "ブランチ作成: $BRANCH_NAME (origin/$DEFAULT_BRANCH から)" >&2
  git worktree add -b "$BRANCH_NAME" "$WORKTREE_PATH" "origin/$DEFAULT_BRANCH" >&2
fi

# --- .worktreeinclude に基づいてファイルをコピー ---
INCLUDE_FILE="$GIT_ROOT/.worktreeinclude"

if [[ -f "$INCLUDE_FILE" ]]; then
  # git ls-files で .worktreeinclude のパターンにマッチする未追跡ファイルを取得
  # --others: 未追跡ファイル
  # --ignored: .worktreeinclude をignoreファイルとして扱い、マッチしたものを返す
  file_list=$(git -C "$GIT_ROOT" ls-files \
    --others --ignored \
    --exclude-from="$INCLUDE_FILE" 2>/dev/null)

  if [[ -z "$file_list" ]]; then
    echo ".worktreeinclude にマッチするファイルなし" >&2
  else
    count=$(echo "$file_list" | wc -l | tr -d ' ')
    echo "$count 個のファイルをコピー中..." >&2

    # tar パイプで一括コピー（高速・スペース入りパスにも対応）
    git -C "$GIT_ROOT" ls-files -z \
      --others --ignored \
      --exclude-from="$INCLUDE_FILE" 2>/dev/null | \
      tar -C "$GIT_ROOT" --null -T - -cf - 2>/dev/null | \
      tar -C "$WORKTREE_PATH" -xf - 2>/dev/null

    # コピー結果のサマリーを表示
    echo "$file_list" | awk -F/ '{print ($2 ? $1"/" : $0)}' | sort | uniq -c | \
      while read -r cnt path; do
        if [[ "$cnt" -eq 1 && "$path" != */ ]]; then
          echo "  + $path" >&2
        else
          echo "  + $path ($cnt files)" >&2
        fi
      done
  fi
else
  echo ".worktreeinclude が見つかりません - ファイルコピーをスキップ" >&2
fi

# --- stdout に worktree パスを出力（Claude Code が読み取る） ---
ABSOLUTE_PATH=$(cd "$WORKTREE_PATH" && pwd)
echo "$(to_native_path "$ABSOLUTE_PATH")"