//
//  VideoDetailsPage.swift
//  AVCHDConverterAttempt
//
//  Created by Zachary Verbeck on 6/30/25.
//

import AVKit
import Photos
import SwiftUI

func formatSecondsToHMS(seconds: Double) -> String? {
    let formatter = DateComponentsFormatter()
    formatter.unitsStyle = .positional
    formatter.allowedUnits = [.hour, .minute, .second]
    formatter.zeroFormattingBehavior = .pad
    return formatter.string(from: seconds)
}

struct VideoDetailsPage: View {
    @Environment(VideoProcessor.self) private var videoProcessor
    @Bindable var video: VideoFile

    @State var player = AVPlayer()
    @State var isSaving: Bool = false
    @State var isSaved: Bool = false
    @State var selectedEncoder: EncoderType = .copy
    @State var isConverting: Bool = false

    var body: some View {
        List {
            Section {
                HStack {
                    Text(video.name)
                        .font(.headline)
                    Spacer()
                    Menu {
                        if let url = video.convertedURL.value() {
                            ShareLink(item: url) {
                                Text("Share Converted File")
                            }
                            .disabled(
                                video.convertedURL.isLoading()
                                    || isSaving
                            )
                        } else {
                            Text("Share Converted File")
                        }
                        if let url = video.mtsURL {
                            ShareLink(item: url) {
                                Text("Share original file")
                            }
                            .disabled(
                                video.convertedURL.isLoading()
                                    || isSaving
                            )
                        } else {
                            Text("Share original file")
                                .disabled(true)
                        }
                    } label: {
                        Image(systemName: "square.and.arrow.up")
                            .symbolRenderingMode(.monochrome)
                            .symbolVariant(.none)
                            .fontWeight(.regular)
                    }
                }
                ZStack {
                    VideoPlayer(player: player)
                        .aspectRatio(1.778, contentMode: .fit)
                    if video.convertedURL.isLoading() {
                        ProgressView().tint(.white)
                    }
                }
            }
            Section {
                Button("Re-Encode Video") {
                    if video.convertedURL != .new {
                        video.convertedURL = videoProcessor.deleteVideoFile(
                            at: video.convertedURL
                        )
                    }
                    player.pause()
                    player = AVPlayer()
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
                    LabeledContent("Framerate", value: details.framerate)
                    LabeledContent(
                        "Duration",
                        value: formatSecondsToHMS(seconds: details.duration)
                            ?? "00:00:00"
                    )
                    LabeledContent(
                        "Dimensions",
                        value:
                            "\(String(details.width))x\(String(details.height))"
                    )
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
                player.play()
            }
            if !FileManager.default.fileExists(
                atPath: video.mtsURL?.path ?? ""
            ) {
                videoProcessor.copyVideoToTemp(video: video)
            }
        }.onChange(of: video.convertedURL) { newValue, oldValue in
            if newValue == oldValue {
                return
            }
            isConverting = newValue.isLoading()
            if let url = video.convertedURL.value() {
                player = AVPlayer(url: url)
                player.play()
            }
        }.onDisappear {
            player.pause()
            player = AVPlayer()
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
                duration: 8.38,
                height: 720,
                width: 1280,
                framerate: "60000/1001"
            )
        )
    )
    .environment(VideoProcessor())
}
