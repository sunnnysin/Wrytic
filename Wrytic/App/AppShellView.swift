import SwiftUI

enum SidebarDestination: String, CaseIterable, Identifiable {
    case home = "Home"
    case settings = "Settings"

    var id: String { rawValue }

    var systemImage: String {
        switch self {
        case .home: "house"
        case .settings: "gearshape"
        }
    }
}

struct AppShellView: View {
    @State private var store = NotebookStore()
    @State private var selection: SidebarDestination? = .home

    var body: some View {
        NavigationSplitView {
            List(SidebarDestination.allCases, selection: $selection) { destination in
                Label(destination.rawValue, systemImage: destination.systemImage)
                    .tag(destination)
                    .accessibilityElement(children: .combine)
                    .accessibilityIdentifier("sidebar.\(destination.rawValue)")
            }
            .navigationTitle("Wrytic")
        } detail: {
            switch selection {
            case .settings:
                SettingsView()
            default:
                HomeView(store: store)
            }
        }
    }
}

#Preview {
    AppShellView()
}
