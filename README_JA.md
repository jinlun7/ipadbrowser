# PadBrowser

<p align="center">
  <img src="https://img.shields.io/badge/Platform-iPadOS%2018.0+-007AFF?style=flat-square&logo=apple&logoColor=white" alt="Platform" />
  <img src="https://img.shields.io/badge/Swift-6.0-F05138?style=flat-square&logo=swift&logoColor=white" alt="Swift" />
  <img src="https://img.shields.io/badge/Framework-SwiftUI%20%2F%20Observation-0055FF?style=flat-square" alt="SwiftUI" />
  <img src="https://img.shields.io/badge/Target-iPad%20Only-teal?style=flat-square" alt="iPad Only" />
  <img src="https://img.shields.io/badge/License-MIT-green?style=flat-square" alt="License" />
</p>

<p align="center">
  <strong>iPad の大画面、Magic Keyboard、トラックパッドのために設計されたデスクトップ級ネイティブ Web ブラウザ</strong>
</p>

<p align="center">
  <a href="README.md">English</a> •
  <a href="README_CN.md">简体中文</a> •
  <strong>日本語</strong>
</p>

---

## プロジェクト概要

現代の iPad は、高性能な Apple Silicon、高リフレッシュレートの Liquid Retina ディスプレイ、そして Magic Keyboard やトラックパッドといった優れたハードウェアを備えています。しかし、従来のモバイルブラウザは、スマートフォン向けの拡大表示、画面上部を圧迫する横並びのタブバー、限定的なショートカット操作など、大画面ハードウェアのポテンシャルを活かしきれていません。

**PadBrowser** は、Swift 6 と SwiftUI で一から開発された、iPadOS 専用のデスクトップ級 Web ブラウザです。デスクトップ基準の WebKit レンダリング、ワークスペース（Spaces）による分離、垂直タブシステム、カーネルレベルのコンテンツブロック、そして完全なハードウェアキーボード操作体系を備え、iPad に本格的なデスクトップ並みの閲覧環境を提供します。

---

## 主な機能

### 1. デスクトップ級 WebKit エンジン
- **デスクトップ表示の標準化**: `preferredContentMode = .desktop` を標準適用。GitHub、Figma、Notion などの複雑な Web アプリケーションを、デスクトップと同じ完全なレイアウトと機能で描画します。
- **macOS Safari User-Agent**: 完全な macOS Safari User-Agent 署名を送信し、モバイル向けレイアウトへの強制転送や「非対応ブラウザ」の警告表示を防止します。
- **ピクチャ・イン・ピクチャ（PiP）**: HTML5 ネイティブの PiP、要素のフルスクリーン、インライン再生に対応。音声付きメディアの自動再生を制限し、バックグラウンドでの誤作動を防ぎます。
- **Web インスペクタ対応**: `isInspectable = true` を有効化しており、Mac の Safari から iPad 上のページ DOM やコンソールを直接デバッグ可能です。

### 2. ワークスペース（Spaces）と階層型タブ管理
- **独立したワークスペース**: 「開発」「リサーチ」「個人」など、用途ごとのスペースを自由に作成可能。スペースごとに独立したタブ一覧、入れ子構造のフォルダ、ピン留めサイト（Pinned Sites）を保持します。
- **プライベートスペースの完全分離**: `IncognitoDataStorePool` により、プライベートスペースごとに独立したメモリ常駐型 `WKWebsiteDataStore.nonPersistent()` を割り当てます。Cookie やセッションはスペース内でのみ保持され、スペース終了時に破棄されます。
- **幅調整可能な垂直サイドバー**: 220 pt 〜 420 pt の間でドラッグして幅を調整できる垂直サイドバーを搭載。タブのドラッグ＆ドロップ分類に対応し、画面縦方向の表示領域を最大限に確保します。
- **従来の横並びタブバー**: 従来のタブ配置を好むユーザー向けに、滑らかなアニメーション付きの横並びタブバーも提供しています。
- **モダンなスタートページ**: 検索、ピン留めサイト、最近のブックマークを統合したカード型スタートページを備えています。

### 3. カーネルレベルのプライバシー保護とシステム連携
- **WebKit ネイティブ広告ブロック**: `WKContentRuleList` を活用し、WebKit のネットワークレイヤーで直接トラッカーや広告ドメインを遮断。CSS スタイルの最適化と連携し、サードパーティ製ライブラリを介さず極めて軽量に動作します。
- **iCloud キーチェーン自動入力**: iPadOS の `AuthenticationServices`（`ASAuthorizationPasswordProvider`）と統合。Touch ID / Face ID 認証を経て、保存されたパスワードを Web フォームへ安全に入力します。
- **ユーザースクリプト機能**: Tampermonkey 互換の `@match` ルールをサポートする軽量スクリプトエンジンを内蔵し、ページの読み込みタイミングでスクリプトを安全に挿入可能です。
- **Netscape ブックマーク読み込み**: Chrome、Safari、Firefox などの標準 HTML ブックマークエクスポート形式に対応し、階層フォルダ構造をそのままインポートできます。

### 4. ハードウェア入力への最適化
- **macOS 準拠のショートカット**: タブの作成・削除、アドレスバーフォーカス、タブ切り替え（⌘1〜9）、拡大・縮小など、15 以上の標準キーボードショートカットを網羅。
- **コマンドパレット（<kbd>⌘</kbd> + <kbd>⇧</kbd> + <kbd>P</kbd>）**: キーボードだけでアクションの実行や URL の直接入力を瞬時に行えるクイックランチャーを搭載。
- **トラックパッドジェスチャー**: 2 本指での画面端スワイプによる「進む / 戻る」のスムーズなナビゲーションに対応。

### 5. Apple HIG に準拠したデザインシステム
- **ディスプレイ角丸に同期したキャンバス**: iPad の物理画面の丸みに合わせた 24 pt の連続角丸（Continuous Corner Radius）と上品なシャドウを採用。
- **Liquid Glass 互換レイヤー**: iPadOS 26+ のネイティブ `glassEffect` を活用しつつ、iPadOS 18 環境では `.ultraThinMaterial` へ自然にフォールバックする抽象化レイヤーを構築。
- **全画面没入モード**: システムステータスバーを非表示にし、Web コンテンツを全画面いっぱいに広げることが可能です。

---

## アーキテクチャとエンジニアリング

PadBrowser は、Swift 6 の厳密な並行性と Observation フレームワークに基づいた単方向データフローを採用しています：

```text
PadBrowser/
├── PadBrowserApp.swift                # アプリケーションのエントリーポイント
├── Models/                            # ドメインモデル
│   ├── BrowserTab.swift               # タブ情報（UUID、URL、スクロール位置スナップショット）
│   ├── BrowserSpace.swift             # スペース、フォルダ階層、ピン留めサイト
│   └── Bookmark.swift                 # ブックマークツリー構造と Netscape パーサー
├── Stores/                            # 状態管理（SwiftUI Observation）
│   ├── BrowserStore.swift             # 全体状態ルート（TabRuntime による細粒度分離）
│   ├── PersistenceStore.swift         # JSON セッション永続化と復元
│   ├── SettingsStore.swift            # UserDefaults による設定保存
│   ├── BookmarkStore.swift            # ブックマークコレクション管理
│   └── CredentialStore.swift          # 検索エンジン定義と HTTP 認証キャッシュ
├── Web/                               # WebKit 連携レイヤー
│   ├── BrowserWebView.swift           # デスクトップ向けに設定された WKWebView サブクラス
│   ├── WebContainer.swift             # UIViewRepresentable ブリッジと Coordinator
│   ├── ContentBlockerManager.swift    # WKContentRuleList ルールコンパイルエンジン
│   ├── IncognitoDataStorePool.swift   # 非永続ストレージのプール管理
│   ├── PasswordAutofillHelper.swift   # キーチェーン生体認証連携
│   ├── UserScriptBridge.swift         # スクリプト挿入ブリッジ
│   └── UserScriptStore.swift          # ユーザースクリプト管理
├── Commands/                          # キーボードショートカット
│   └── BrowserCommands.swift          # CommandMenu によるショートカット定義
└── Views/                             # UI コンポーネント群
    ├── RootView.swift                 # メインレイアウトと丸角キャンバス
    ├── WebSurface.swift               # タブ常駐プール制御とクラッシュ自動復旧
    ├── StartPageView.swift            # スタートページ
    ├── TabStripView.swift             # 横並びタブバー
    ├── Sidebar/                       # スペース切り替え、区切り線、垂直タブ一覧
    ├── Toolbar/                       # アドレスバー（Omnibox）、ナビゲーション、コマンドパレット
    ├── Settings/                      # 設定パネル
    └── Compatibility/                 # Liquid Glass 互換実装
```

---

## キーボードショートカット一覧

| ショートカット | 機能 |
|---|---|
| <kbd>⌘</kbd> + <kbd>T</kbd> | 新規タブを開く |
| <kbd>⌘</kbd> + <kbd>W</kbd> | 現在のタブを閉じる |
| <kbd>⌘</kbd> + <kbd>⌥</kbd> + <kbd>⇧</kbd> + <kbd>W</kbd> | 他のタブをすべて閉じる |
| <kbd>⌘</kbd> + <kbd>⇧</kbd> + <kbd>N</kbd> | 新規プライベートタブを開く |
| <kbd>⌘</kbd> + <kbd>L</kbd> | アドレスバー（Omnibox）にフォーカス |
| <kbd>⌘</kbd> + <kbd>R</kbd> | ページを再読み込み |
| <kbd>⌘</kbd> + <kbd>[</kbd> / <kbd>]</kbd> | 戻る / 進む |
| <kbd>⌘</kbd> + <kbd>1</kbd> 〜 <kbd>9</kbd> | 1 〜 9 番目のタブに切り替え |
| <kbd>⌘</kbd> + <kbd>⌃</kbd> + <kbd>S</kbd> | サイドバーの表示 / 非表示 |
| <kbd>⌘</kbd> + <kbd>⇧</kbd> + <kbd>P</kbd> | コマンドパレットを表示 |
| <kbd>⌘</kbd> + <kbd>D</kbd> | 現在のページをブックマークに追加 |
| <kbd>⌘</kbd> + <kbd>⇧</kbd> + <kbd>B</kbd> | ブックマークバーの表示 / 非表示 |
| <kbd>⌘</kbd> + <kbd>+</kbd> / <kbd>-</kbd> / <kbd>0</kbd> | 拡大 / 縮小 / 倍率リセット（50% 〜 200%） |

---

## ビルドと実行方法

### 必要要件
- **Xcode**: 16.0 以降
- **言語**: Swift 6.0
- **対応 OS**: iPadOS 18.0 以降
- **アーキテクチャ**: arm64（実機）/ arm64（シミュレータ）

### ソースコードの取得
```bash
git clone https://github.com/jinlun7/ipadbrowser.git
cd ipadbrowser
open PadBrowser.xcodeproj
```

### コード署名（Signing）の設定
1. Xcode 左側のプロジェクトナビゲーターで `PadBrowser` プロジェクトを選択します。
2. **Signing & Capabilities** タブを開きます。
3. **Automatically manage signing** にチェックを入れ、**Team** から自身の Apple Developer チーム（無料の個人用 Apple ID も可）を選択します。
4. iPad 実機または iPadOS 18+ のシミュレータ（例: `iPad Pro 13-inch (M4)`）を選択します。
5. <kbd>⌘</kbd> + <kbd>R</kbd> を押してビルドと実行を行います。

### コマンドラインでのビルド
```bash
xcodebuild -project PadBrowser.xcodeproj \
           -scheme PadBrowser \
           -destination 'platform=iOS Simulator,name=iPad Pro 13-inch (M4)' \
           -configuration Debug \
           build
```

---

## コントリビューション

Issue の報告、機能の提案、Pull Request を歓迎します。コードを変更する際は以下にご留意ください：
1. Swift 6 の厳密な並行性チェック（Strict Concurrency）に準拠していること。
2. 画面サイズ（11 インチ、13 インチ、および Split View 分割表示）における UI の安定性を検証すること。
3. PR 提出前に実機またはシミュレータで動作確認を行うこと。

---

## ライセンス

本プロジェクトは [MIT ライセンス](LICENSE) の下で公開されています。
