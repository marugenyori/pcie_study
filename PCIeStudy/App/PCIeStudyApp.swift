import SwiftUI

@main
struct PCIeStudyApp: App {
    @State private var progress = ProgressStore()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(progress)
        }
    }
}
