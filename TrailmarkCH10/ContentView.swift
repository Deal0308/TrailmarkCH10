//
//  ContentView.swift
//  TrailmarkCH10
//
//  Created by Michael Deal on 9/5/26.
//

import SwiftUI
import TrailMarkCH10Core

/// Root view for the iOS app.
///
/// It receives the shared `AppModel` and passes the HealthKit manager down to the dashboard.
struct ContentView: View {
    let appModel: AppModel

    var body: some View {
        TodayDashboardView(healthKitManager: appModel.healthKitManager)
    }
}

#Preview {
    ContentView(appModel: AppModel())
}
