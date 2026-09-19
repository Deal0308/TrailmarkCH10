//
//  TrailmarkCH10App.swift
//  TrailmarkCH10
//
//  Created by Michael Deal on 9/5/26.
//

import SwiftUI

/// Entry point for the iOS app.
@main
struct TrailmarkCH10App: App {
    /// Keeps shared app state alive for the lifetime of the app scene.
    @State private var appModel = AppModel()

    var body: some Scene {
        WindowGroup {
            ContentView(appModel: appModel)
        }
    }
}
