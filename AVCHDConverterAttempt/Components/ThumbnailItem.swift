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
                let _ = print("Loading thumbnail for \(video.name) \(url.path)")
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
                    .fill(Color.gray.opacity(0.6))
                    .frame(width: width, height: height)
                    .overlay(
                        VStack {
                            ProgressView()
                            Text("Loading \(video.name)").foregroundColor(.gray)
                                .frame(alignment: .center)
                        }
                    )
            case .failed:
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundColor(.red)
                    .font(.largeTitle)
                    .frame(width: width, height: height)
                    .overlay(
                        Text("Failed to load: \(video.name)").foregroundColor(
                            .gray
                        ).frame(alignment: .center)
                    )
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
            default:
                return
            }
        }
        .onDisappear {
            print("cancel session for \(video.name)")
            videoProcessor.cancelSessionForID(uuid: video.id)
        }
    }
}
