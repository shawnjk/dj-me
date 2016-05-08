//
//  Album.swift
//  DJ Me
//
//  Created by Shawn Kim on 4/17/16.
//  Copyright © 2016 Shawn. All rights reserved.
//

import Foundation
import Gloss

struct Image: Decodable {
    let URL: NSURL?

    init?(json: JSON) {
        self.URL = "url" <~~ json
    }
}

class Album: Decodable {
    let name: String?
    let images: [Image]?
    //let artistName: String?

    required init?(json: JSON) {
        self.name = "name" <~~ json
        self.images = "images" <~~ json
    }
}
