import SwiftUI

@main
struct CivMaze: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
                .frame(width: GameScene.WIDTH, height: GameScene.HEIGHT, alignment: .topLeading)
        }
    }
}
