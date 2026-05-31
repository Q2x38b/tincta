import SwiftUI
import SwiftData

/// Entry point for the app's UI tree. Renders the Library home screen, which
/// owns navigation into the rest of the app (Recipe Detail, Editor, Menu,
/// Settings, Share/Import sheets).
struct RootView: View {
    var body: some View {
        LibraryView()
    }
}

#Preview {
    RootView()
        .modelContainer(TinctaModelContainer.makePreview())
}
