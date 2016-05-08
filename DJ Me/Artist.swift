//
//  Track.swift
//  DJ Me
//
//  Created by Shawn Kim on 5/7/16.
//  Copyright © 2016 Shawn. All rights reserved.
//

import Foundation
import Gloss

class Artist: Decodable {
    let name: String?
    let images: [Image]?

    required init?(json: JSON) {
        self.name = "name" <~~ json
        self.images = "images" <~~ json
    }
}
