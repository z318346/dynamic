import ActivityKit
import WidgetKit
import SwiftUI

@main
struct DynamicWidgetBundle: WidgetBundle {
    var body: some Widget { BlankIslandActivity() }
}

private struct Blank: View {
    var body: some View {
        Color.clear.frame(width: 1, height: 1).accessibilityHidden(true)
    }
}

struct BlankIslandActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: IslandAttributes.self) { context in
            VStack(alignment: .leading, spacing: 4) {
                Text("dynamic").font(.headline)
                Text(context.state.vietnamese ? "Phiên Dynamic Island" : "Dynamic Island session")
                    .font(.caption).foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(16)
        } dynamicIsland: { _ in
            DynamicIsland {
                DynamicIslandExpandedRegion(.center) { Blank() }
            } compactLeading: {
                Blank()
            } compactTrailing: {
                Blank()
            } minimal: {
                Blank()
            }
        }
    }
}
