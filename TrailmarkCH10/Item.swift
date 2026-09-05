//
//  Item.swift
//  TrailmarkCH10
//
//  Created by Michael Deal on 9/5/26.
//

import Foundation
import SwiftData

@Model
final class Item {
    var timestamp: Date
    
    init(timestamp: Date) {
        self.timestamp = timestamp
    }
}
