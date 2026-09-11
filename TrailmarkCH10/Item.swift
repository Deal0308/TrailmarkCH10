//
//  Item.swift
//  TrailmarkCH10
//
//  Created by Michael Deal on 9/5/26.
//

import Foundation
import SwiftData

/// Example SwiftData model that can be stored in the app's local database.
@Model
final class Item {
    /// Records when this item was created or logged.
    var timestamp: Date

    init(timestamp: Date) {
        self.timestamp = timestamp
    }
}
