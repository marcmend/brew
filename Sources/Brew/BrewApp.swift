import SwiftUI

@main
struct BrewApp: App {
    @StateObject private var brewer = Brewer()

    var body: some Scene {
        MenuBarExtra {
            MenuView(brewer: brewer)
        } label: {
            Image(systemName: brewer.mode?.menuBarSymbol ?? "cup.and.saucer")
        }
        .menuBarExtraStyle(.window)
    }
}
