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
    @Bindable var video: VideoFile

    @State var player: AVPlayer? = nil
    @State var isSaving: Bool = false
    @State var isSaved: Bool = false
    @Environment(VideoProcessor.self) private var videoProcessor

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
                    if let videoURL = video.convertedURL.value() {
                        saveVideo(videoURL: videoURL) { _ in
                            isSaving = false
                        }
                    }
                }.disabled(
                    self.video.convertedURL.isLoading() || isSaving || isSaved
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
            print("on appear of \(video.name) video details")
            if !FileManager.default.fileExists(
                atPath: video.convertedURL.value()?.path ?? ""
            ) {
                videoProcessor.generateConvertedMp4(video: video)
                videoProcessor.parseFileInfo(video: video)
            } else if let url = video.convertedURL.value() {
                player = AVPlayer(url: url)
            }
        }.onChange(of: video.convertedURL) { newValue, oldValue in
            print("Change, \(newValue)")
            if newValue != oldValue, let url = video.convertedURL.value() {
                player = AVPlayer(url: url)
            }
        }.onDisappear {
            print("on disappear!")
            player?.pause()
            player = nil
            switch video.convertedURL {
            case .loading(let taskId):
                videoProcessor.cancelSessionForID(id: taskId)
                return
            default:
                return
            }
        }
    }
}
