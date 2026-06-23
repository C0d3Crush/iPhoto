import SwiftUI

enum NavItem: String, CaseIterable {
    case library = "Library"

    var icon: String {
        switch self {
        case .library: return "photo.stack"
        }
    }
}

struct NavSidebarView: View {
    @EnvironmentObject var viewModel: ImageViewModel

    var body: some View {
        List(selection: $viewModel.selectedNavItem) {
            Section(header: Text("Bibliothek")) {
                ForEach(NavItem.allCases, id: \.self) { item in
                    Label(item.rawValue, systemImage: item.icon)
                        .tag(item)
                }
            }
        }
        .listStyle(SidebarListStyle())
        .frame(minWidth: 160, idealWidth: 180, maxWidth: 220)
    }
}
