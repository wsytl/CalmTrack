//
//  EmptyPlaceholder.swift
//  CalmTrack
//
//  C8：列表空态占位（分类 / 习惯 / 指标管理共用），从 CategoryManagementView 移出，
//  避免共享 helper 藏在不相关的文件里。
//

import SwiftUI

func emptyPlaceholder(title: String, subtitle: String, systemImage: String) -> some View {
    VStack(spacing: 12) {
        Image(systemName: systemImage)
            .font(.system(size: 36))
            .foregroundStyle(.secondary)
        Text(title)
            .font(.headline)
        Text(subtitle)
            .font(.subheadline)
            .foregroundStyle(.secondary)
            .multilineTextAlignment(.center)
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .padding()
}
