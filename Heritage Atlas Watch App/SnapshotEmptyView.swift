import SwiftUI

struct SnapshotEmptyView: View {
    var body: some View {
        ContentUnavailableView {
            Label("Heritage Atlas", systemImage: "applewatch.and.iphone")
        } description: {
            Text("Open Heritage Atlas on iPhone")
        }
        .padding(.horizontal, 8)
    }
}

#Preview {
    SnapshotEmptyView()
}
