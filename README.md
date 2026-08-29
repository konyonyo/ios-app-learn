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

## 次に行うこと

- `VStack`で複数のViewを縦に並べる
- `Button`を追加する
- `@State`で画面の状態を管理する
- ボタンを押すと表示が変わるアプリにする
