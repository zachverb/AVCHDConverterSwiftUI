//
//  ContentView.swift
//  AVCHDConverterAttempt
//
//  Created by Zachary Verbeck on 6/24/25.
//

import SwiftUI
import AVKit

struct ThumbnailItem: View {
    @Binding var video: VideoFile
    
    @StateObject private var videoProcessor = VideoProcessor()
    
    let height = 120.0
    let width = 120.0
    
    var body: some View {
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
                    videoProcessor.generateThumbnail(video: $video)
                }
        }
    }
}

struct ThumbnailGrid: View {
    @Binding var pickedFiles: [VideoFile]
    
    var body: some View {
        ScrollView(.vertical) {
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())]) {
                ForEach($pickedFiles, id: \.self) { $video in
                    NavigationLink(destination: VideoDetailsPage(video: $video)) {
                        ThumbnailItem(video: $video)
                    }
                }
            }
        }
    }
}

struct VideoDetailsPage: View {
    @Binding var video: VideoFile
    
    @State var player: AVPlayer? = nil
    @StateObject private var videoProcessor = VideoProcessor()

    var body: some View {
        VStack {
            Text(video.name)
                .font(.headline)
            if let player = player { // Safely unwrap player before using it
                VideoPlayer(player: player)
                    .aspectRatio(1.778, contentMode: .fit)
                    .onAppear {
                        player.play() // Start playing once the view appears
                    }
            } else {
                ThumbnailItem(video: $video)
            }
        }.onAppear {
            videoProcessor.generateConvertedMp4(video: $video)
        }.onChange(of: videoProcessor.state) { newValue, oldValue in
            print("Changed!")
            print("new value \(newValue), url: \(video.convertedURL ?? URL(string: "invalid url")!)")
            if newValue != oldValue, let url = video.convertedURL {
                print("is this thing on")
                player = AVPlayer(url: url)
            }
        }
    }
}

struct VideosPage: View {
    @State private var showDirectoryPicker = false
    @State private var pickedFiles: [VideoFile] = []
    @State private var message: String = "No directory selected."
    
    @State private var selectedVideoURL: URL?


    var body: some View {
        VStack(spacing: 20) {
            Text(message)
                .font(.headline)
                .multilineTextAlignment(.center)
                .padding(.horizontal)

            Button("Open Directory") {
                showDirectoryPicker = true
            }
            .buttonStyle(.borderedProminent)
            .tint(.green)

            if pickedFiles.count > 0 {
                Text("Files in Directory (\(pickedFiles.count)):")
                    .font(.title2)
                    .padding(.top)
                ThumbnailGrid(pickedFiles: $pickedFiles)
            }
        }
        .sheet(isPresented: $showDirectoryPicker) {
            DirectoryPicker(
                onDirectoryPicked: { files in
                    self.pickedFiles = files
                    self.message = "Successfully read \(files.count) files from directory."
                    print("Picked files: \(files.map { $0.name })")
                },
                onCancelled: {
                    self.message = "Directory picker cancelled or failed."
                    self.pickedFiles = []
                    print("Directory picker cancelled.")
                }
            )
        }
        .navigationTitle("Directory picker")
        .navigationBarTitleDisplayMode(.automatic)
    }
}

struct ContentView: View {
    var body: some View {
        NavigationStack {
            VideosPage()
        }
    }
}

// MARK: - Preview

#Preview {
    ContentView()
}

