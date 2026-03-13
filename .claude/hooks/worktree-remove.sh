#!/bin/bash
# WorktreeRemove hook for Claude Code
#
# worktree の削除時に呼ばれる。
# git worktree remove を実行し、失敗した場合はフォールバックで強制削除する。
#
# 入力 (stdin JSON): { "worktree_path": "<path>", ... }
# 出力: なし（情報メッセージは stderr へ）

set -e

# --- stdin から JSON 入力を読む ---
INPUT=$(cat)

if ! command -v jq &>/dev/null; then
  echo "Error: jq が必要です。" >&2
  exit 1
fi

WORKTREE_PATH=$(echo "$INPUT" | jq -r '.worktree_path // .path // empty')

if [[ -z "$WORKTREE_PATH" ]]; then
  echo "Error: worktree パスが取得できませんでした" >&2
  exit 1
fi

# --- クロスプラットフォーム対応 ---
if command -v cygpath &>/dev/null; then
  WORKTREE_PATH=$(cygpath -u "$WORKTREE_PATH")
fi

# --- worktree を削除 ---
if [[ -d "$WORKTREE_PATH" ]]; then
  echo "worktree を削除中: $WORKTREE_PATH" >&2

  # まず git worktree remove を試みる
  if git worktree remove "$WORKTREE_PATH" 2>&2; then
    echo "削除完了" >&2
  else
    # ロック等で失敗した場合は --force で再試行
    echo "通常削除に失敗、--force で再試行..." >&2
    if git worktree remove --force "$WORKTREE_PATH" 2>&2; then
      echo "強制削除完了" >&2
    else
      # それでもダメならディレクトリを直接削除 + git worktree prune
      echo "git worktree remove 失敗、ディレクトリを直接削除します..." >&2
      rm -rf "$WORKTREE_PATH"
      git worktree prune 2>/dev/null || true
      echo "ディレクトリ削除 + prune 完了" >&2
    fi
  fi
else
  echo "worktree ディレクトリが存在しません: $WORKTREE_PATH" >&2
  # ディレクトリがなくても git の管理情報が残っている可能性があるので prune
  git worktree prune 2>/dev/null || true
fi