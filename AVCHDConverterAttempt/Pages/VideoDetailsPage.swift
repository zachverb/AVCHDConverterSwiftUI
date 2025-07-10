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
    @Environment(VideoProcessor.self) private var videoProcessor
    @Bindable var video: VideoFile

    @State var player: AVPlayer? = nil
    @State var isSaving: Bool = false
    @State var isSaved: Bool = false
    @State var selectedEncoder: EncoderType = .copy
    @State var isConverting: Bool = false

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
        List {
            Section {
                HStack {
                    Text(video.name)
                        .font(.headline)
                    Spacer()
                    Menu(
                        content: {
                            Section {
                                if let url = video.convertedURL.value() {
                                    ShareLink(item: url) {
                                        Text("Share Converted File")
                                    }.disabled(
                                        video.convertedURL.isLoading()
                                            || isSaving
                                    )
                                }
                                Button("Share Original File") {
                                    let _ = print("SHARE")
                                }.disabled(
                                    video.convertedURL.isLoading()
                                        || isSaved
                                )
                                Button(
                                    isSaved
                                        ? "Video saved!"
                                        : "Save to Photo Library"
                                ) {
                                    isSaving = true
                                    if let videoURL = video.convertedURL.value()
                                    {
                                        saveVideo(videoURL: videoURL) {
                                            status in
                                            isSaving = false
                                            isSaved = status
                                        }
                                    }
                                }.disabled(
                                    self.video.convertedURL.isLoading()
                                        || isSaved
                                )
                            }
                        },
                        label: {
                            Image(systemName: "square.and.arrow.up")
                                .symbolRenderingMode(.monochrome)
                                .symbolVariant(.none)
                                .fontWeight(.regular)
                        }
                    )
                }
                if let player = player {  // Safely unwrap player before using it
                    VideoPlayer(player: player)
                        .aspectRatio(1.778, contentMode: .fit)
                        .onAppear {
                            player.play()  // Start playing once the view appears
                        }
                } else {
                    HStack {
                        Spacer()
                        ThumbnailItem(video: video).overlay(
                            Rectangle()
                                .fill(Color.gray.opacity(0.7))
                                .frame(width: 120, height: 120)
                                .overlay(ProgressView().tint(.white))
                        )
                        Spacer()
                    }
                }
            }
            Section {
                Button("Convert using options") {
                    if video.convertedURL != .new {
                        video.convertedURL = videoProcessor.deleteVideoFile(
                            at: video.convertedURL
                        )
                    }
                    player = nil
                    videoProcessor.generateConvertedMp4(
                        video: video,
                        encoder: selectedEncoder
                    )
                }.disabled(self.video.convertedURL.isLoading())
                Picker("Encoder", selection: $selectedEncoder) {
                    ForEach(EncoderType.allCases) { encoder in
                        Text(encoder.rawValue).tag(encoder)
                    }
                }
                if let details = video.details {
                    Text("Framerate: \(details.framerate)")
                    Text("Duration: \(details.duration)")
                    Text("Height: \(String(details.height))")
                    Text("Width: \(String(details.width))")
                }
            }
        }
        .onAppear {
            if !FileManager.default.fileExists(
                atPath: video.convertedURL.value()?.path ?? ""
            ) {
                videoProcessor.generateConvertedMp4(
                    video: video,
                    encoder: selectedEncoder
                )
                videoProcessor.parseFileInfo(video: video)
            } else if let url = video.convertedURL.value() {
                player = AVPlayer(url: url)
            }
        }.onChange(of: video.convertedURL) { newValue, oldValue in
            if newValue == oldValue {
                return
            }
            isConverting = newValue.isLoading()
            if let url = video.convertedURL.value() {
                player = AVPlayer(url: url)
            }
        }.onDisappear {
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

#Preview {
    VideoDetailsPage(
        video: VideoFile(
            privateURL: URL(filePath: "")!,
            name: "0000.MTS",
            bookmark: Data(),
            key: "key",
            details: VideoDetails(
                duration: 0.01,
                height: 720,
                width: 1280,
                framerate: "60000/1001"
            )
        )
    )
    .environment(VideoProcessor())
}
