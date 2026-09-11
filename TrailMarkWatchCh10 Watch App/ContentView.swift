//
//  ContentView.swift
//  TrailMarkWatchCh10 Watch App
//
//  Created by Michael Deal on 9/5/26.
//

import SwiftUI
import TrailMarkCH10Core

/// Root view for the watch app.
///
/// This is currently placeholder UI while the shared core package is available for future watch features.
struct ContentView: View {
    var body: some View {
        VStack {
            Image(systemName: "globe")
                .imageScale(.large)
                .foregroundStyle(.tint)
            Text("Hello, world!")
        }
        .padding()
    }
}

#Preview {
    ContentView()
}
