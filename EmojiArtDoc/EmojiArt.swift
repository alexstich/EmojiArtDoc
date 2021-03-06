//
//  EmojiArt.swift
//  EmojiArt
//
//  Created by Алексей Гребенкин on 15.09.2020.
//  Copyright © 2020 Alex Grebenkin. All rights reserved.
//

import Foundation

struct EmojiArt: Codable
{
    var url: URL?
    var imageData: Data?
    var emojis = [EmojiInfo]()
    
    struct EmojiInfo: Codable {
        let x: Int
        let y: Int
        let text: String
        let size: Int
    }
    
    init (url: URL, emojis: [EmojiInfo]) {
        self.url = url
        self.emojis = emojis
    }
    
    init?(json: Data) {
        if let newValue = try? JSONDecoder().decode(EmojiArt.self, from: json) {
            self = newValue
        } else {
            return nil
        }
    }
    
    init (imageData: Data, emojis: [EmojiInfo]) {
        self.imageData = imageData
        self.emojis = emojis
    }
    
    
    var json: Data? {
        return try? JSONEncoder().encode(self)
    }    
}
