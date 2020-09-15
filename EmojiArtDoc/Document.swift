//
//  Document.swift
//  EmojiArtDoc
//
//  Created by Алексей Гребенкин on 15.09.2020.
//  Copyright © 2020 Alex Grebenkin. All rights reserved.
//

import UIKit

class Document: UIDocument {
    
    override func contents(forType typeName: String) throws -> Any {
        // Encode your document with an instance of NSData or NSFileWrapper
        return Data()
    }
    
    override func load(fromContents contents: Any, ofType typeName: String?) throws {
        // Load your document from contents
    }
}

