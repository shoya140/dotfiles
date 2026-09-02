#!/bin/bash

# macOSのシステム設定をCLIで適用するスクリプト
# 実行後、一部の設定はログアウトまたは再起動後に反映される

set -eu

# ------------------------------------------------------------
# キーボード
# ------------------------------------------------------------

# キーリピート速度を最速に近い値にする (GUIの最速より速い)
defaults write NSGlobalDomain KeyRepeat -int 2
defaults write NSGlobalDomain InitialKeyRepeat -int 15

# キー長押しでアクセント記号メニューを出さずリピート入力する
defaults write NSGlobalDomain ApplePressAndHoldEnabled -bool false

# ダッシュ・ピリオド・引用符の自動置換を無効にする
defaults write NSGlobalDomain NSAutomaticDashSubstitutionEnabled -bool false
defaults write NSGlobalDomain NSAutomaticPeriodSubstitutionEnabled -bool false
defaults write NSGlobalDomain NSAutomaticQuoteSubstitutionEnabled -bool false

# 入力ソース切替時の言語インジケータ (画面中央のポップアップ) を表示しない
defaults write NSGlobalDomain TSMLanguageIndicatorEnabled -bool false

# ------------------------------------------------------------
# キーボードショートカット
# ------------------------------------------------------------

# システムのキーボードショートカットをIDで指定して無効にする
# 引数: ID、キーのASCIIコード、キーコード、修飾キーのビットマスク
disable_shortcut() {
  defaults write com.apple.symbolichotkeys AppleSymbolicHotKeys -dict-add "$1" "
    <dict>
      <key>enabled</key><false/>
      <key>value</key>
      <dict>
        <key>type</key><string>standard</string>
        <key>parameters</key>
        <array><integer>$2</integer><integer>$3</integer><integer>$4</integer></array>
      </dict>
    </dict>"
}

disable_shortcut 32 65535 126 8650752 # Mission Control (^↑)
disable_shortcut 33 65535 125 8650752 # アプリケーションウインドウ (^↓)
disable_shortcut 79 65535 123 8650752 # 左の操作スペースに移動 (^←)
disable_shortcut 81 65535 124 8650752 # 右の操作スペースに移動 (^→)
disable_shortcut 65 32 49 1572864     # Finderの検索ウインドウを表示 (⌥⌘Space)

# ------------------------------------------------------------
# 外観
# ------------------------------------------------------------

# ダークモードにする
defaults write NSGlobalDomain AppleInterfaceStyle -string "Dark"

# ------------------------------------------------------------
# Dock
# ------------------------------------------------------------

# Dockを自動的に隠す
defaults write com.apple.dock autohide -bool true

# アイコンサイズを小さくして、カーソルを合わせたときに拡大する
defaults write com.apple.dock tilesize -int 27
defaults write com.apple.dock magnification -bool true
defaults write com.apple.dock largesize -int 46

# 最近使ったアプリケーションを表示しない
defaults write com.apple.dock show-recents -bool false

# ホットコーナー: 右下でディスプレイをスリープさせる (修飾キーなし)
defaults write com.apple.dock wvous-br-corner -int 10
defaults write com.apple.dock wvous-br-modifier -int 0

# ------------------------------------------------------------
# デスクトップとウインドウ
# ------------------------------------------------------------

# 壁紙クリックでのデスクトップ表示を「ステージマネージャ使用時のみ」にする
defaults write com.apple.WindowManager EnableStandardClickToShowDesktop -bool false

# タイル表示されたウインドウの間隔を空けない
defaults write com.apple.WindowManager EnableTiledWindowMargins -bool false

# ------------------------------------------------------------
# Finder
# ------------------------------------------------------------

# 隠しファイルを表示する
defaults write com.apple.finder AppleShowAllFiles -bool true

# デフォルトをリスト表示にする
defaults write com.apple.finder FXPreferredViewStyle -string "Nlsv"

# 新規ウィンドウでホームディレクトリを開く
defaults write com.apple.finder NewWindowTarget -string "PfHm"

# デスクトップに外付けディスクとリムーバブルメディアのみ表示する
defaults write com.apple.finder ShowHardDrivesOnDesktop -bool false
defaults write com.apple.finder ShowExternalHardDrivesOnDesktop -bool true
defaults write com.apple.finder ShowRemovableMediaOnDesktop -bool true

# ------------------------------------------------------------
# トラックパッド
# ------------------------------------------------------------

# タップでクリックを有効にする (内蔵・Bluetooth・ログイン画面の3箇所に書く)
defaults write com.apple.AppleMultitouchTrackpad Clicking -bool true
defaults write com.apple.driver.AppleBluetoothMultitouch.trackpad Clicking -bool true
defaults -currentHost write NSGlobalDomain com.apple.mouse.tapBehavior -int 1

# 3本指ドラッグを有効にする
defaults write com.apple.AppleMultitouchTrackpad TrackpadThreeFingerDrag -bool true
defaults write com.apple.driver.AppleBluetoothMultitouch.trackpad TrackpadThreeFingerDrag -bool true

# 軌跡の速さ
defaults write NSGlobalDomain com.apple.trackpad.scaling -float 0.875

# ------------------------------------------------------------
# スクリーンショット
# ------------------------------------------------------------

# 撮影後のサムネイルプレビューを表示しない
defaults write com.apple.screencapture show-thumbnail -bool false

# ------------------------------------------------------------
# メニューバー
# ------------------------------------------------------------

# 時計に曜日を表示し、日付は表示しない
defaults write com.apple.menuextra.clock ShowDayOfWeek -bool true
defaults write com.apple.menuextra.clock ShowDate -bool false

# Bluetoothを常に表示する
defaults -currentHost write com.apple.controlcenter Bluetooth -int 18

# ------------------------------------------------------------
# 反映
# ------------------------------------------------------------

killall Dock Finder SystemUIServer ControlCenter 2>/dev/null || true

# キーボードショートカットの変更を即時反映する
activate_settings="/System/Library/PrivateFrameworks/SystemAdministration.framework/Resources/activateSettings"
if [ -x "$activate_settings" ]; then
  "$activate_settings" -u
fi

echo "Done. Some settings require logout or restart to take effect."
