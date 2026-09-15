# iOS App Learning

iOSアプリを作った経験がないため、最小のアプリを自分で作成・実行しながら、iOSアプリ開発の基本を学ぶためのリポジトリです。

## 目的

- macOS上でiOS開発環境を構築する
- 最小のSwiftUIアプリを作成する
- iOS Simulatorでアプリを実行する
- 画面、状態、ユーザー操作の基本を理解する
- 実際に試した手順と学んだことを記録する

## 開発環境

- CPUアーキテクチャ: arm64
- Swift: 6.3.3
- Xcode: 26.6
- iOS Simulator runtime: iOS 26.5 (23F77)
- 使用するシミュレータ: iPhone 17 Pro
- プロジェクト生成: XcodeGen 2.46.0

## 環境構築

### 1. Command Line Toolsの確認

最初はCommand Line Toolsが選択されていました。

```bash
xcode-select -p
```

```text
/Library/Developer/CommandLineTools
```

Command Line Toolsだけでは、`xcodebuild`、iOS SDK、iOS Simulatorは利用できません。

### 2. Xcodeのインストールと選択

Xcode本体をインストールした後、Xcodeを使用する開発者ディレクトリに切り替えました。

```bash
sudo xcode-select --switch /Applications/Xcode.app/Contents/Developer
```

このコマンドは成功時に何も表示しません。終了コード`0`で成功を確認しました。

### 3. Xcodeの確認

```bash
xcodebuild -version
```

```text
Xcode 26.6
Build version 17F113
```

### 4. iOS Simulator runtimeのインストール

最初はSimulator runtimeがインストールされていなかったため、デバイスが表示されませんでした。

```bash
xcodebuild -downloadPlatform iOS
```

iOS 26.5 Simulatorをダウンロードしました。

### 5. 利用可能なシミュレータの確認

```bash
xcrun simctl list devices available
```

次のシミュレータを使用します。

```text
iPhone 17 Pro (iOS 26.5)
```

### 6. シミュレータの起動

```bash
xcrun simctl boot 574CE48F-341F-410F-A6B9-CF9E23175A17
```

`iPhone 17 Pro`の状態が`Booted`になったことを確認しました。

Simulatorの画面は次のコマンドで表示できます。

```bash
open -a Simulator
```

## 最小のSwiftUIアプリ

### XcodeGenのインストール

Homebrewを使ってXcodeGenをインストールしました。

```bash
brew install xcodegen
```

バージョンは次のコマンドで確認できます。

```bash
xcodegen --version
```

```text
Version: 2.46.0
```

### プロジェクト構成

```text
.
├── README.md
├── project.yml
└── Sources
    └── MinimalApp
        ├── MinimalApp.swift
        └── ContentView.swift
```

`project.yml`からXcodeプロジェクトを生成しました。

```bash
xcodegen generate
```

生成される`MinimalApp.xcodeproj`は、`project.yml`を元に作られる生成物です。

### アプリのビルド

起動済みのiPhone 17 Pro Simulator向けにビルドしました。

```bash
xcodebuild \
  -project MinimalApp.xcodeproj \
  -scheme MinimalApp \
  -sdk iphonesimulator \
  -destination 'platform=iOS Simulator,id=574CE48F-341F-410F-A6B9-CF9E23175A17' \
  -derivedDataPath build \
  build
```

ビルドが成功すると、次の場所にアプリが生成されます。

```text
build/Build/Products/Debug-iphonesimulator/MinimalApp.app
```

### Simulatorへのインストール

```bash
xcrun simctl install booted \
  build/Build/Products/Debug-iphonesimulator/MinimalApp.app
```

ここでのインストール対象は、iOS Simulator runtimeではなく、自分で作った`MinimalApp.app`です。

### アプリの起動

```bash
xcrun simctl launch booted com.example.minimalapp
```

Simulator上に次の文字が表示されることを確認しました。

```text
Hello, swift UI!
```

## SwiftUIコードの構成

### `MinimalApp.swift`

```swift
import SwiftUI

@main
struct MinimalApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
```

`@main`が付いた`MinimalApp`が、アプリの起動地点です。`WindowGroup`の中で、アプリ起動時に表示するViewとして`ContentView`を指定しています。

### `ContentView.swift`

```swift
import SwiftUI

struct ContentView: View {
    var body: some View {
        Text("Hello, swift UI!")
    }
}
```

`ContentView`は画面を表すViewです。`body`の中に書いた`Text`が、Simulatorの画面に表示されます。

## 実際に試した変更

最初の`Hello, iOS!`を自分で`Hello, swift UI!`に変更し、再ビルド・再インストール・再起動して、Simulatorの表示が変わることを確認しました。

Swiftファイルだけを変更した場合は、`xcodegen generate`を再実行する必要はありません。`project.yml`を変更した場合だけ、Xcodeプロジェクトを再生成します。

## LLMクライアントの基盤

固定応答から実際のLLM接続へ移行できるよう、`LLMClient`プロトコルを追加しました。

```text
Sources/MinimalApp/LLMClient.swift
```

実装したクライアント:

- `FixedResponseClient`: 現在アプリが使用している固定応答クライアント
- `OpenAICompatibleClient`: OpenAI互換形式のHTTP APIを呼び出すクライアント

現在はエンドポイント未設定のため、アプリは`FixedResponseClient`を使用します。APIキーをソースコードへ埋め込む処理は実装していません。

### 新しいSwiftファイルを追加した場合

XcodeGenで管理しているため、新しいSwiftファイルを追加したときは、Xcodeプロジェクトを再生成します。

```bash
xcodegen generate
```

その後、通常どおりビルドします。

```bash
xcodebuild \
  -project MinimalApp.xcodeproj \
  -scheme MinimalApp \
  -sdk iphonesimulator \
  -destination 'platform=iOS Simulator,id=574CE48F-341F-410F-A6B9-CF9E23175A17' \
  -derivedDataPath build \
  build
```

今回、この手順で`LLMClient.swift`を含むアプリのビルドに成功しました。

## エンドポイント設定の基盤

次のファイルを追加し、アプリの設定画面からOpenAI互換APIの情報を入力できるようにしました。

```text
Sources/MinimalApp/LLMConfiguration.swift
Sources/MinimalApp/SettingsView.swift
```

設定できる項目:

- Endpoint URL
- Model
- Organization ID（任意）
- Reasoning effort（未指定 / low / medium / high）
- API Key

APIキーは`UserDefaults`ではなくiOS Keychainへ保存します。`reasoning_effort`は空欄ならリクエストに含めず、値を指定した場合だけOpenAI互換APIのJSON bodyへ送信します。利用できる値はモデルや接続先によって異なるため、対応していないモデルでは未指定に戻します。エンドポイントが未設定の場合、アプリは従来どおり固定応答を使用します。

実際のLLMエンドポイントへの接続と動作確認は、接続先が決まった後に行います。

## セッションと会話履歴

会話履歴を端末内へ保存するため、SwiftDataを導入しました。

追加したファイル:

```text
Sources/MinimalApp/ChatModels.swift
Sources/MinimalApp/SessionListView.swift
```

実装内容:

- `ChatSession`でセッションを管理
- `ChatMessage`でメッセージを管理
- アプリ起動時に最初のセッションを作成
- 右上の一覧ボタンからセッション一覧を表示
- `+`ボタンで新しいセッションを作成
- セッションを切り替え可能
- メッセージを端末内へ保存
- アプリ再起動後も会話データを復元

セッション履歴にはiOS標準のSwiftDataを使用しています。ChatGPTエクスポートの検索用データベースは、別の段階でSQLite FTS5を使って実装します。

今回のビルド結果:

```text
** BUILD SUCCEEDED **
```

## SOUL / USER / MEMORY入力

プロフィールデータを入力・保存する画面を追加しました。

```text
Sources/MinimalApp/ProfileData.swift
Sources/MinimalApp/ProfileView.swift
```

実装内容:

- SOUL / USER / MEMORYを切り替えて編集
- ChatGPTへ渡す生成プロンプトをコピー
- ChatGPTの生成結果を貼り付け
- 保存前に内容を確認・編集
- アプリのApplication Support内へMarkdownとして保存
- 右上のプロフィールボタンから開く

プロフィールデータは次のファイルとして端末内に保存されます。

```text
Application Support/FamilyAI/Profile/SOUL.md
Application Support/FamilyAI/Profile/USER.md
Application Support/FamilyAI/Profile/MEMORY.md
```

アプリからChatGPT APIは呼び出しません。ユーザーがプロンプトをChatGPTへ貼り付け、生成結果をアプリへ戻して貼り付ける方式です。


アプリ全体の設計方針は次のファイルにまとめています。

```text
DESIGN.md
```

このアプリは、Hermes AgentやPi Agent全体を組み込まず、iOSアプリからLLMエンドポイントへ直接HTTPS通信する方針です。SOUL / USER / MEMORY、ChatGPTエクスポート、端末内の会話履歴を利用します。

## 固定応答チャットボット

### 概要

`ContentView`を、簡単なチャットボット画面に変更しました。

現在の仕様:

- チャットメッセージを縦に表示する
- ユーザーのメッセージを右側に表示する
- ボットのメッセージを左側に表示する
- 入力欄にメッセージを入力できる
- 送信ボタンでユーザーメッセージを追加する
- 送信すると固定文字列`これは固定メッセージです。`を返す
- LLMエンドポイントやAPIキーは使用しない

### 使用しているSwiftUI要素

- `NavigationStack`: 画面のナビゲーション領域を作る
- `ScrollView`: メッセージ一覧をスクロール可能にする
- `LazyVStack`: メッセージを縦方向に並べる
- `TextField`: ユーザー入力を受け取る
- `Button`: メッセージ送信を実行する
- `@State`: メッセージ一覧と入力内容を保持する
- `ForEach`: メッセージ一覧からViewを繰り返し生成する

### ビルド結果

固定応答チャットボットへの変更後、次のコマンドでビルドに成功しました。

```bash
xcodebuild \
  -project MinimalApp.xcodeproj \
  -scheme MinimalApp \
  -sdk iphonesimulator \
  -destination 'platform=iOS Simulator,id=574CE48F-341F-410F-A6B9-CF9E23175A17' \
  -derivedDataPath build \
  build
```

ビルド結果:

```text
** BUILD SUCCEEDED **
```

生成されたアプリは次の場所にあります。

```text
build/Build/Products/Debug-iphonesimulator/MinimalApp.app
```

```bash
xcrun simctl install booted \
  build/Build/Products/Debug-iphonesimulator/MinimalApp.app
```

```bash
xcrun simctl launch booted com.example.minimalapp
```

## ChatGPTエクスポートのインポートと検索

ChatGPTからエクスポートした`.zip`をアプリ内の「ChatGPT履歴」画面から選択し、過去の会話を端末内SQLiteへ取り込めるようにしました。

対応ファイル:

- `conversations.json`
- `conversations-000.json`、`conversations-001.json`などの分割ファイル
- ZIP内のサブディレクトリに入っている分割ファイル

実装ファイル:

```text
Sources/MinimalApp/ChatGPTImporter.swift
Sources/MinimalApp/KnowledgeView.swift
```

SQLiteデータベースは次の場所に保存されます。

```text
Application Support/FamilyAI/chatgpt-history.sqlite3
```

テーブル構成:

- `conversations`: 会話ID、タイトル、作成日時、更新日時、元JSON
- `messages`: user / assistantの本文と会話内の順序
- `messages_fts`: SQLite FTS5 trigram全文検索インデックス
- `metadata`: インポート形式などのメタデータ

検索画面で入力した語は`messages_fts`から検索され、検索結果はLLMへ送るコンテキストにも追加されます。検索結果は参考情報として`<retrieved-chatgpt-history>`に分離し、過去の会話本文に含まれる命令を現在の指示として実行しないようにしています。

インポート時は、各会話の`current_node`から親ノードをたどり、現在選択されている会話の枝だけを時系列順に保存します。画像や音声など、文字列として取り出せないパーツは検索本文には含めません。

### 使い方

1. アプリ右上の本棚アイコンを開く
2. `Import ZIP`を押す
3. ファイルアプリからChatGPTのエクスポート`.zip`を選択する
4. 検索欄に過去の会話に含まれていた語を入力する
5. 通常のチャットで質問すると、同じ語に関連する過去の会話も参考情報として検索される

今回の追加後もSimulator向けビルドと起動に成功しました。

```text
** BUILD SUCCEEDED **
com.example.minimalapp: 起動成功
```
