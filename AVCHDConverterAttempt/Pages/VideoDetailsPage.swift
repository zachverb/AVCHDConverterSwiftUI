//
//  VideoDetailsPage.swift
//  AVCHDConverterAttempt
//
//  Created by Zachary Verbeck on 6/30/25.
//

import AVKit
import Photos
import PhotosUI
import SwiftUI

struct VideoDetailsPage: View {
    @State var video: VideoFile

    @State var player: AVPlayer? = nil
    @State var isSaving: Bool = false
    @State var isSaved: Bool = false
    @StateObject private var videoProcessor = VideoProcessor()

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
                    completion(false)
                } else {
                    completion(success)
                }
            }
        }
    }

    var body: some View {
        VStack {
            Text(video.name)
                .font(.headline)
            if let player = player {  // Safely unwrap player before using it
                VideoPlayer(player: player)
                    .aspectRatio(1.778, contentMode: .fit)
                    .onAppear {
                        player.play()  // Start playing once the view appears
                    }
                Button(isSaved ? "Video saved!" : "Save to photos") {
                    isSaving = true
                    saveVideo(videoURL: video.convertedURL!) { _ in
                        isSaving = false
                    }
                }.disabled(
                    self.video.convertedURL == nil || isSaving || isSaved
                )
            } else {
                ThumbnailItem(video: video)
            }
            if let details = video.details {
                Text("Framerate: \(details.framerate)")
                Text("Duration: \(details.duration)")
                Text("Height: \(details.height)")
                Text("Width: \(details.width)")
            }
            if isSaving {
                ProgressView()
            }
            Spacer()
        }.onAppear {
            if !FileManager.default.fileExists(
                atPath: video.convertedURL?.path ?? ""
            ) {
                videoProcessor.generateConvertedMp4(video: video)
                videoProcessor.parseFileInfo(video: video)
            } else if let url = video.convertedURL {
                player = AVPlayer(url: url)
            }
        }.onChange(of: videoProcessor.state) { newValue, oldValue in
            if newValue != oldValue, let url = video.convertedURL {
                player = AVPlayer(url: url)
            }
        }.onDisappear {
            player?.pause()
            player = nil
            videoProcessor.cancelActiveSession()
        }
    }
}
