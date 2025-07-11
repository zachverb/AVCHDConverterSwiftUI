//
//  FileUtilities.swift
//  AVCHDConverterAttempt
//
//  Created by Zachary Verbeck on 7/10/25.
//

import PhotosUI

func requestAuthorization(completion: @escaping (Bool) -> Void) {
    PHPhotoLibrary.requestAuthorization { status in
        switch status {
        case .authorized, .limited:
            completion(true)
        default:
            completion(false)
        }
    }
}

func saveVideo(videoURL: URL, completion: @escaping (Bool) -> Void) {
    requestAuthorization { authorized in
        guard authorized else {
            completion(false)
            return
        }

        PHPhotoLibrary.shared().performChanges {
            PHAssetCreationRequest.creationRequestForAssetFromVideo(
                atFileURL: videoURL
            )
        } completionHandler: { success, error in
            if let error = error {
                print(error)
                completion(false)
            } else {
                completion(success)
            }
        }
    }
}

func accessBookmarkedFile(url: URL, key: String) -> URL? {
    guard let bookmarkData = UserDefaults.standard.data(forKey: key)
    else {
        print("no bookmark for key: \(key) - skipping")
        return nil
    }
    do {
        var isStale = false

        let directoryURL = try URL(
            resolvingBookmarkData: bookmarkData,
            options: [],  // Empty options
            relativeTo: nil,
            bookmarkDataIsStale: &isStale
        )
        if isStale {
            print(
                "Warning: Bookmark for key '\(key)' is stale. It might need to be recreated by the user."
            )
            UserDefaults.standard.removeObject(forKey: key)  // Clear stale bookmark
            return nil
        }
        return directoryURL
    } catch {
        print(
            "Error resolving bookmark for key '\(key)': \(error.localizedDescription)"
        )
        return nil
    }
}

func copyPrivateFileUsingBookmark(
    file: URL,
    destination: URL,
    bookmark: URL
) throws {
    let didStartAccessing =
        bookmark.startAccessingSecurityScopedResource()
    defer {
        if didStartAccessing {
            bookmark.stopAccessingSecurityScopedResource()
        }
    }
    if FileManager.default.fileExists(atPath: destination.path) {
        try FileManager.default.removeItem(at: destination)
    }

    try FileManager.default.copyItem(
        at: file,
        to: destination
    )
}
