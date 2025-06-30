//
//  VideoFileData.swift
//  AVCHDConverterAttempt
//
//  Created by Zachary Verbeck on 6/29/25.
//

import Foundation // For URL.

struct VideoFile: Hashable {
    var privateURL: URL
    var name: String
    var bookmark: Data
    var key: String
    var uuid: UUID = UUID()
    
    var mtsURL: URL?
    var convertedURL: URL?
    var thumbnail: URL?
    
    static func == (lhs: VideoFile, rhs: VideoFile) -> Bool {
        return lhs.privateURL == rhs.privateURL && lhs.uuid == rhs.uuid && lhs.thumbnail == rhs.thumbnail && lhs.convertedURL == rhs.convertedURL && lhs.mtsURL == rhs.mtsURL && lhs.name == rhs.name
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(privateURL)
        hasher.combine(uuid)
    }
}
