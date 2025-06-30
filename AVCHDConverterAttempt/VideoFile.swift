//
//  VideoFileData.swift
//  AVCHDConverterAttempt
//
//  Created by Zachary Verbeck on 6/29/25.
//

import Foundation // For URL.

struct VideoFile {
    var privateUrl: URL
    var fileName: String
    var bookmark: Data
    var key: String
    
    var mtsUrl: URL?
    var convertedUrl: URL?
    var thumbnailUrl: URL?
}
