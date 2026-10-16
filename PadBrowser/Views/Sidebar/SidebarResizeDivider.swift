import SwiftUI

/// 可拖拽调节宽度的侧边栏分割条。
///
/// 具备良好的触控与触控笔（Apple Pencil）支持：
/// - 拥有 16pt 的加宽手势响应热区，防止难点中；
/// - 悬浮或拖拽时手柄胶囊自动高亮；
/// - 双击（或双触）触发弹性动画快速恢复至默认宽度 280pt。
struct SidebarResizeDivider: View {

    @Binding var width: Double

    @State private var isDragging: Bool = false
    @State private var isHovering: Bool = false
    @State private var startWidth: Double = 0

    var body: some View {
        ZStack {
            // 交互抓手手柄：平时极淡融入下沉背景，触控悬停或拖拽时高亮
            Capsule()
                .fill(Color.secondary.opacity(isDragging ? 0.6 : (isHovering ? 0.35 : 0.08)))
                .frame(width: 3.5, height: 32)
                .scaleEffect(isDragging ? 1.15 : 1.0)
                .animation(.easeInOut(duration: 0.15), value: isDragging)
                .animation(.easeInOut(duration: 0.15), value: isHovering)
        }
        .frame(width: 12)
        .contentShape(Rectangle())
        .onHover { hovering in
            isHovering = hovering
        }
        .gesture(
            DragGesture(minimumDistance: 1, coordinateSpace: .global)
                .onChanged { value in
                    if !isDragging {
                        isDragging = true
                        startWidth = width
                    }
                    let newWidth = startWidth + Double(value.translation.width)
                    width = min(max(newWidth, SettingsStore.minSidebarWidth), SettingsStore.maxSidebarWidth)
                }
                .onEnded { _ in
                    isDragging = false
                }
        )
        .onTapGesture(count: 2) {
            withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
                width = SettingsStore.defaultSidebarWidth
            }
        }
        .help("拖拽调整侧栏宽度，双击恢复默认")
    }
}
