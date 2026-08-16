//
//  MarkdownText.swift
//  CalmTrack
//

import SwiftUI

/// 使用系统 `AttributedString(markdown:)` 渲染 Markdown 的轻量文本视图。
/// 如果 Markdown 解析失败，则回退为普通纯文本展示。
struct MarkdownText: View {

    let text: String

    var body: some View {
        if let attributed = try? AttributedString(markdown: text) {
            Text(attributed)
        } else {
            Text(text)
        }
    }
}

#Preview {
    MarkdownText(text: "**加粗**、*斜体*、`代码`\n\n- 列表项\n- 列表项")
        .padding()
}
