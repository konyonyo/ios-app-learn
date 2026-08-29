import SwiftUI
import UIKit

struct ProfileView: View {
    @Binding var profile: ProfileData
    @Environment(\.dismiss) private var dismiss
    @State private var selectedDocument: ProfileDocument = .soul
    @State private var errorMessage: String?

    private var documentText: Binding<String> {
        Binding(
            get: {
                switch selectedDocument {
                case .soul: profile.soul
                case .user: profile.user
                case .memory: profile.memory
                }
            },
            set: { value in
                switch selectedDocument {
                case .soul: profile.soul = value
                case .user: profile.user = value
                case .memory: profile.memory = value
                }
            }
        )
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 12) {
                Picker("Document", selection: $selectedDocument) {
                    ForEach(ProfileDocument.allCases) { document in
                        Text(document.title).tag(document)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal)

                HStack {
                    Text(selectedDocument.description)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Button("Copy prompt") {
                        UIPasteboard.general.string = selectedDocument.prompt
                    }
                    .font(.footnote)
                }
                .padding(.horizontal)

                TextEditor(text: documentText)
                    .font(.body.monospaced())
                    .padding(8)
                    .overlay {
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(.quaternary)
                    }
                    .padding(.horizontal)

                if let errorMessage {
                    Text(errorMessage)
                        .font(.footnote)
                        .foregroundStyle(.red)
                        .padding(.horizontal)
                }
            }
            .padding(.top)
            .navigationTitle("Profile Data")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        save()
                    }
                }
            }
        }
    }

    private func save() {
        do {
            try profile.save()
            dismiss()
        } catch {
            errorMessage = "プロフィールの保存に失敗しました: \(error.localizedDescription)"
        }
    }
}

enum ProfileDocument: String, CaseIterable, Identifiable {
    case soul
    case user
    case memory

    var id: String { rawValue }

    var title: String {
        switch self {
        case .soul: "SOUL"
        case .user: "USER"
        case .memory: "MEMORY"
        }
    }

    var description: String {
        switch self {
        case .soul: "ボットの人格・口調・回答方針"
        case .user: "ユーザーの基本情報・好み・環境"
        case .memory: "長期的に保持したい事実や前提"
        }
    }

    var prompt: String {
        switch self {
        case .soul:
            """
            あなたは私専用のAIアシスタントの人格設定を作成しています。

            以下の会話や指示を分析し、AIアシスタントの人格・口調・回答方針をSOUL.mdとしてまとめてください。
            推測で情報を追加せず、明示されていない内容は不明として扱ってください。
            Markdownのコードフェンスは使わず、ファイル内容だけを出力してください。

            [ここに会話や指示を貼り付ける]
            """
        case .user:
            """
            以下の会話から、AIがユーザーを理解するために有用な情報だけを抽出し、USER.mdとしてまとめてください。

            氏名、好み、環境、経験、関心などを整理してください。
            推測や創作をせず、曖昧な情報は曖昧であることを明記してください。
            Markdownのコードフェンスは使わず、ファイル内容だけを出力してください。

            [ここに会話を貼り付ける]
            """
        case .memory:
            """
            以下の会話から、今後も役に立つ長期的な記憶だけを抽出し、MEMORY.mdとして整理してください。

            一時的な予定は除外し、ユーザーの好み、継続中のプロジェクト、重要な前提を優先してください。
            推測で情報を追加せず、Markdownのコードフェンスは使わないでください。

            [ここに会話を貼り付ける]
            """
        }
    }
}

#Preview {
    ProfileView(profile: .constant(ProfileData()))
}
