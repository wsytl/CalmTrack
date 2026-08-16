//
//  LaunchSplashGate.swift
//  CalmTrack
//
//  SwiftUI 首帧绘制很快时，系统 LaunchScreen 可能几乎不可见；此处用与 storyboard 一致的过渡层，保证冷启动能看到「慢养」。
//

import SwiftUI

struct LaunchSplashGate<Content: View>: View {

    @ViewBuilder var content: () -> Content

    @State private var showSplash = true

    var body: some View {
        ZStack {
            content()
            if showSplash {
                LaunchSplashOverlay()
                    .transition(.opacity)
                    .zIndex(1)
            }
        }
        .task {
            try? await Task.sleep(nanoseconds: 420_000_000)
            withAnimation(.easeOut(duration: 0.28)) {
                showSplash = false
            }
        }
    }
}

private struct LaunchSplashOverlay: View {

    @Environment(\.colorScheme) private var colorScheme
    @State private var settled = false

    var body: some View {
        ZStack {
            splashBackground
                .ignoresSafeArea()

            VStack(spacing: 18) {
                ZStack {
                    RoundedRectangle(cornerRadius: 28, style: .continuous)
                        .fill(markFill)
                        .frame(width: 88, height: 88)
                        .overlay {
                            RoundedRectangle(cornerRadius: 28, style: .continuous)
                                .strokeBorder(markStroke, lineWidth: 1)
                        }
                        .shadow(color: markShadow, radius: 18, x: 0, y: 8)

                    Image(systemName: "leaf.fill")
                        .symbolRenderingMode(.hierarchical)
                        .font(.system(size: 36, weight: .semibold))
                        .foregroundStyle(CalmChrome.calmFill(colorScheme))
                }

                VStack(spacing: 7) {
                    Text(L10n.tr("app.display_name"))
                        .font(.system(size: 38, weight: .semibold, design: .rounded))
                        .foregroundStyle(CalmChrome.calmFill(colorScheme))

                    Text(L10n.tr("launch.subtitle"))
                        .font(.system(size: 15, weight: .medium, design: .rounded))
                        .foregroundStyle(.secondary)

                    Text(L10n.tr("launch.rhythm"))
                        .font(.system(size: 12, weight: .regular, design: .rounded))
                        .foregroundStyle(rhythmColor)
                }
            }
            .scaleEffect(settled ? 1 : 0.96)
            .opacity(settled ? 1 : 0.82)
        }
        .allowsHitTesting(false)
        .onAppear {
            withAnimation(.easeOut(duration: 0.32)) {
                settled = true
            }
        }
    }

    private var splashBackground: Color {
        switch colorScheme {
        case .dark:
            return Color(red: 0.13, green: 0.15, blue: 0.13)
        default:
            return Color(red: 0.99, green: 0.97, blue: 0.91)
        }
    }

    private var markFill: Color {
        switch colorScheme {
        case .dark:
            return Color(red: 0.19, green: 0.25, blue: 0.21)
        default:
            return Color(red: 0.95, green: 0.98, blue: 0.95)
        }
    }

    private var markStroke: Color {
        switch colorScheme {
        case .dark:
            return Color.white.opacity(0.08)
        default:
            return Color(red: 0.72, green: 0.84, blue: 0.78).opacity(0.42)
        }
    }

    private var markShadow: Color {
        colorScheme == .dark ? Color.black.opacity(0.24) : Color(red: 0.34, green: 0.42, blue: 0.28).opacity(0.12)
    }

    private var rhythmColor: Color {
        switch colorScheme {
        case .dark:
            return Color(red: 0.78, green: 0.73, blue: 0.62)
        default:
            return Color(red: 0.60, green: 0.52, blue: 0.39)
        }
    }
}
