//
//  ThumbnailItem.swift
//  AVCHDConverterAttempt
//
//  Created by Zachary Verbeck on 7/2/25.
//

import SwiftUI

struct ThumbnailItem: View {
    @State var video: VideoFile

    @StateObject private var videoProcessor = VideoProcessor()

    let height = 120.0
    let width = 120.0

    var body: some View {
        Group {
            if let path = video.thumbnail?.path {
                Image(uiImage: UIImage(contentsOfFile: path) ?? UIImage()) // Load image from path
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: width, height: height)
                    .shadow(radius: 5)
            } else if videoProcessor.state == .processing {
                Rectangle()
                    .fill(Color.gray.opacity(0.6))
                    .frame(width: width, height: height)
                    .overlay(Text("Loading \(video.name)").foregroundColor(.gray).frame(alignment: .center))
            } else if videoProcessor.state == .failed {
                Rectangle()
                    .fill(Color.red.opacity(0.2))
                    .frame(width: width, height: height)
                    .overlay(Text("Failed to load: \(video.name)").foregroundColor(.gray).frame(alignment: .center))
            } else {
                Rectangle()
                    .fill(Color.gray.opacity(0.2))
                    .frame(width: width, height: height)
                    .overlay(Text("\(video.name)").foregroundColor(.gray).frame(alignment: .center))
                    .onAppear {
                        videoProcessor.generateThumbnail(video: video)
                    }
            }
        }.onDisappear { videoProcessor.cancelActiveSession() }
    }
}

