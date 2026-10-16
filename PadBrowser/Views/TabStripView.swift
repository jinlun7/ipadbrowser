import SwiftUI

/// 横向标签条。当前空间的标签平铺在这里，侧边栏收起时也能切换。
struct TabStripView: View {

    @Environment(BrowserStore.self) private var store

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                ForEach(store.currentSpaceTabs) { tab in
                    StripTab(tab: tab, isSelected: store.selectedTabID == tab.id)
                        .onTapGesture { store.select(tab.id) }
                        .contextMenu {
                            Button("关闭") { store.close(tab.id) }
                            Button("关闭其他") { store.closeOthers(keeping: tab.id) }
                        }
                }

                Button {
                    store.newTab(url: nil)
                } label: {
                    Image(systemName: "plus")
                        .frame(width: 28, height: 26)
                }
                .buttonStyle(.borderless)
                .help("新建标签页")
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
        }
        .background(Color(uiColor: .systemBackground))
    }
}

private struct StripTab: View {
    let tab: BrowserTab
    let isSelected: Bool

    @Environment(BrowserStore.self) private var store
    @State private var isTargeted = false

    var body: some View {
        HStack(spacing: 6) {
            FaviconView(url: tab.faviconURL, letter: tab.displayTitle.first.map(String.init))

            Text(tab.displayTitle)
                .font(.caption)
                .lineLimit(1)
                .frame(maxWidth: 150, alignment: .leading)

            if store.runtime(for: tab.id).isLoading {
                ProgressView().controlSize(.mini)
            }

            Button {
                store.close(tab.id)
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 9))
                    .frame(width: 16, height: 16)
            }
            .buttonStyle(.borderless)
            .opacity(isSelected ? 1 : 0)
            .allowsHitTesting(isSelected)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 5)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(isTargeted ? Color.accentColor.opacity(0.25) : (isSelected ? Color(.systemBackground) : Color.secondary.opacity(0.10)))
        )
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .strokeBorder(isTargeted ? Color.accentColor : (isSelected ? Color.secondary.opacity(0.25) : .clear), lineWidth: isTargeted ? 2 : 1)
        }
        .contentShape(Rectangle())
        .draggable(tab.id.uuidString)
        .dropDestination(for: String.self) { items, _ in
            guard let raw = items.first,
                  let sourceID = UUID(uuidString: raw),
                  sourceID != tab.id
            else { return false }

            var orderedIDs = store.currentSpaceTabs.map(\.id)
            guard let fromIndex = orderedIDs.firstIndex(of: sourceID),
                  let toIndex = orderedIDs.firstIndex(of: tab.id)
            else { return false }

            orderedIDs.remove(at: fromIndex)
            orderedIDs.insert(sourceID, at: toIndex)
            withAnimation(.easeInOut(duration: 0.2)) {
                store.reorderTabs(orderedIDs)
            }
            return true
        } isTargeted: { targeted in
            isTargeted = targeted
        }
    }
}
