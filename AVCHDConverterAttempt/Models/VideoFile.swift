//
//  VideoFile.swift
//  AVCHDConverterAttempt
//
//  Created by Zachary Verbeck on 6/29/25.
//

import Foundation  // For URL.

enum LoadingURLResult: Equatable {
    case new
    case loading(String)
    case success(URL)
    case failed
    
    func value() -> URL? {
        switch self {
        case .success(let url):
            return url
        default:
            return nil
        }
    }
    
    func isLoading() -> Bool {
        switch self {
        case .loading:
            return true
        default:
            return false
        }
    }
}

@Observable class VideoFile: Equatable, Identifiable {
    var privateURL: URL
    var name: String
    var bookmark: Data
    var key: String
    var id: UUID = .init()

    var mtsURL: URL?

    var convertedURL: LoadingURLResult
    var thumbnail: LoadingURLResult
    var details: VideoDetails?

    init(
        privateURL: URL,
        name: String,
        bookmark: Data,
        key: String,
        uuid: UUID = UUID(),
        convertedURL: LoadingURLResult = .new,
        thumbnail: LoadingURLResult = .new,
        mtsURL: URL? = nil,
        details: VideoDetails? = nil
    ) {
        self.privateURL = privateURL
        self.name = name
        self.bookmark = bookmark
        self.key = key
        id = uuid
        self.mtsURL = mtsURL
        self.convertedURL = convertedURL
        self.thumbnail = thumbnail
        self.details = details
    }

    static func == (lhs: VideoFile, rhs: VideoFile) -> Bool {
        return lhs.privateURL == rhs.privateURL && lhs.id == rhs.id
            && lhs.thumbnail == rhs.thumbnail
            && lhs.convertedURL == rhs.convertedURL && lhs.mtsURL == rhs.mtsURL
            && lhs.name == rhs.name
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(privateURL)
        hasher.combine(id)
    }
}

struct VideoDetails: Equatable {
    var duration: Double
    var height: Int
    var width: Int
    var framerate: String

    static func == (lhs: VideoDetails, rhs: VideoDetails) -> Bool {
        return lhs.duration == rhs.duration && lhs.height == rhs.height
            && lhs.width == rhs.width && lhs.framerate == rhs.framerate
    }
}
