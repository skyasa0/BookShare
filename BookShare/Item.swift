//
//  Item.swift
//  BookShare
//
//  Created by Srijan Kyasa on 7/20/26.
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
