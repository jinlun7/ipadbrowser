import SwiftUI

/// Liquid Glass 的兼容层。
///
/// **为什么单独一个文件**：iOS 26 才引入 `glassEffect` 这套 API，而本项目最低支持
/// iPadOS 18。所有新 API 都收在这里，好处是
/// 1) 旧系统走 fallback，新系统自动吃到玻璃外观；
/// 2) 万一某个 API 签名和预期不符，只需要改这一个文件，而不是全项目找。
///
/// **设计原则：不要自己画毛玻璃。** 系统设置里有一个「Liquid Glass 透明度滑块」，
/// 辅助功能里还有「减弱透明度」「增强对比度」。只有原生材质会跟随这些设置，
/// 手绘的半透明图层不会——自己画等于制造无障碍问题。
extension View {

    /// 玻璃容器。用于工具栏、侧边栏、书签栏这类需要浮在内容之上的表面。
    @ViewBuilder
    func glassSurface(
        cornerRadius: CGFloat = 18,
        tint: Color? = nil,
        isActive: Bool = false
    ) -> some View {
        if #available(iOS 26.0, *) {
            self.glassSurfaceIOS26(
                cornerRadius: cornerRadius,
                tint: tint,
                isActive: isActive
            )
        } else {
            self.legacyGlassSurface(cornerRadius: cornerRadius, tint: tint)
        }
    }

    @available(iOS 26.0, *)
    @ViewBuilder
    private func glassSurfaceIOS26(
        cornerRadius: CGFloat,
        tint: Color?,
        isActive: Bool
    ) -> some View {
        if let tint {
            self.glassEffect(.regular.tint(tint).interactive(), in: .rect(cornerRadius: cornerRadius))
        } else if isActive {
            self.glassEffect(.regular.interactive(), in: .rect(cornerRadius: cornerRadius))
        } else {
            self.glassEffect(.regular, in: .rect(cornerRadius: cornerRadius))
        }
    }

    @ViewBuilder
    private func legacyGlassSurface(cornerRadius: CGFloat, tint: Color?) -> some View {
        self.background {
            let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            ZStack {
                shape.fill(.ultraThinMaterial)
                if let tint {
                    shape.fill(tint.opacity(0.10))
                }
                shape.strokeBorder(Color(.separator).opacity(0.2), lineWidth: 0.5)
            }
        }
    }

    /// 胶囊形玻璃表面。用于搜索栏、胶囊按钮等。
    @ViewBuilder
    func glassCapsule(
        tint: Color? = nil,
        isActive: Bool = false
    ) -> some View {
        if #available(iOS 26.0, *) {
            if let tint {
                self.glassEffect(.regular.tint(tint).interactive(), in: .capsule)
            } else if isActive {
                self.glassEffect(.regular.interactive(), in: .capsule)
            } else {
                self.glassEffect(.regular, in: .capsule)
            }
        } else {
            self.background {
                ZStack {
                    Capsule().fill(.ultraThinMaterial)
                    if let tint {
                        Capsule().fill(tint.opacity(0.10))
                    }
                    Capsule().strokeBorder(Color(.separator).opacity(0.2), lineWidth: 0.5)
                }
            }
        }
    }

    /// 玻璃按钮。图标类操作用这个，比 `.borderless` 更有层次。
    ///
    /// ⚠️ 这一段和上面的 `glassEffect` 是全项目唯一接触 iOS 26 新 API 的地方，
    /// 也是最可能因为 SDK 版本不同而编译失败的地方。报错先来这个文件看。
    @ViewBuilder
    func glassButton(isProminent: Bool = false) -> some View {
        if #available(iOS 26.0, *) {
            if isProminent {
                self.buttonStyle(.glassProminent)
            } else {
                self.buttonStyle(.glass)
            }
        } else {
            self.buttonStyle(.borderless)
        }
    }
}

// MARK: - 已知但未启用的 API
//
// iOS 27 把滚动边缘效果默认值改成了「硬边模糊」，并取消了底部的滚动边缘效果。
// 网页内容滚到工具栏下面时会显得生硬，理想情况下应该显式选回柔和渐隐，
// 对应的修饰符大致是 `.scrollEdgeEffect(.soft, for: .top)`。
//
// 这里没有启用，因为无法在本机确认它在当前 SDK 里的准确签名——
// 与其让整个项目编译不过，不如先记下来。需要时用 Xcode 的补全确认签名后，
// 在工具栏容器上加一行即可。
//

/// 内容浮在玻璃容器之上时的安全内边距。
///
/// 玻璃边缘有折射，直接贴着边缘放文字会显得被"切开"。
extension CGFloat {
    static let glassInset: CGFloat = 10
}
