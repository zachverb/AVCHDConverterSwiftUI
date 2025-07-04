//
//  ThumbnailItem.swift
//  AVCHDConverterAttempt
//
//  Created by Zachary Verbeck on 7/2/25.
//

import SwiftUI

struct ThumbnailItem: View {
    @Bindable var video: VideoFile

    @Environment(VideoProcessor.self) private var videoProcessor

    let height = 120.0
    let width = 120.0

    var body: some View {
        Group {
            switch video.thumbnail {
            case .success(let url):
                Image(
                    uiImage: UIImage(contentsOfFile: url.path)
                        ?? UIImage()
                )  // Load image from path
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: width, height: height)
                .shadow(radius: 5)
            case .loading:
                Rectangle()
                    .fill(Color.gray.opacity(0.1))
                    .frame(width: width, height: height)
                    .overlay(
                        VStack {
                            ProgressView()
                                .opacity(0.3)
                            Text(video.name).foregroundColor(
                                Color.gray.opacity(0.3)
                            )
                            .frame(alignment: .center)
                        }
                    )
            case .failed:
                Rectangle()
                    .foregroundColor(.red.opacity(0.3))
                    .frame(width: width, height: height)
                    .overlay(
                        VStack {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .font(.largeTitle)
                                .foregroundColor(.red.opacity(0.7))
                            Text(video.name).foregroundColor(
                                .red
                            )
                        }
                    ).frame(alignment: .center)

            case .new:
                Rectangle()
                    .fill(Color.gray.opacity(0.2))
                    .frame(width: width, height: height)
                    .overlay(
                        Text("\(video.name)").foregroundColor(.gray).frame(
                            alignment: .center
                        )
                    )
            }
        }
        .onAppear {
            switch video.thumbnail {
            case .new:
                videoProcessor.generateThumbnail(video: video)
                return
            case .loading(let taskId):
                if !videoProcessor.sessionExistsForID(id: taskId) {
                    video.thumbnail = .new
                }
            default:
                return
            }
        }
        .onDisappear {
            switch video.thumbnail {
            case .loading(let taskId):
                if videoProcessor.sessionExistsForID(id: taskId) {
                    print("cancel session for \(video.name)")
                    videoProcessor.cancelSessionForID(id: taskId)
                }
                video.thumbnail = .new
            default:
                return
            }
        }
    }
}
