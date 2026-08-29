# iOS App Learning

最小のアプリを自分で作成・実行しながら、iOSアプリ開発の基本を学ぶためのリポジトリです。

## 目的

- macOS上でのiOS開発環境を構築する
- 最小のSwiftUIアプリを作成する
- iOS Simulatorでアプリを実行する
- 画面、状態、ユーザー操作の基本を理解する
- 実際に試した手順と学んだことを記録する

## 開発環境

現時点で確認できている環境:

- 開発対象: iOS
- CPUアーキテクチャ: arm64
- Swift: 6.3.3
- Xcode: 26.6
- iOS Simulator runtime: iOS 26.5 (23F77)
- 使用するシミュレータ: iPhone 17 Pro

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

### 2. Xcodeのインストール

Xcode本体をインストールしました。

Xcodeのインストール後、Xcodeを使用する開発者ディレクトリに切り替えました。

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

## 次に行うこと

- 最小のSwiftUIプロジェクトを作成する
- `Hello, iOS!`を表示する
- Xcodeプロジェクトをビルドする
- iOS Simulatorでアプリを起動する
- ボタンと状態管理を追加する
