//
//  Track.swift
//  DJ Me
//
//  Created by Shawn Kim on 5/7/16.
//  Copyright © 2016 Shawn. All rights reserved.
//

import Foundation
import Gloss

class Track: Decodable {
    let name: String?
    let artist: Artist?
    let album: Album?

    required init?(json: JSON) {
        self.name = "name" <~~ json
        self.artist = "artist" <~~ json
        self.album = "album" <~~ json
    }
}