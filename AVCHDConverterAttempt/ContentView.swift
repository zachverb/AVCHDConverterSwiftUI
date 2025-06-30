//
//  ContentView.swift
//  AVCHDConverterAttempt
//
//  Created by Zachary Verbeck on 6/24/25.
//

import SwiftUI

struct ThumbnailItem: View {
    @Binding var video: VideoFile
    
    @StateObject private var videoProcessor = VideoProcessor()
    
    var body: some View {
        let _ = print("loading view for \(video.name), videoProcessor.state: \(videoProcessor.state) thumbPath: \(video.thumbnail?.path ?? "nil")")
        if videoProcessor.state == .processed, let path = video.thumbnail?.path {
            let _ = print("is this gonna work for \(path)")
            Image(uiImage: UIImage(contentsOfFile: path) ?? UIImage()) // Load image from path
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 100, height: 100)
                .shadow(radius: 5)
                .onAppear {
//                    // Automatically clean up after 10 seconds for demo purposes
//                    // In a real app, manage cleanup based on your needs
//                    DispatchQueue.main.asyncAfter(deadline: .now() + 10) {
//                        videoProcessor.cleanUpThumbnail()
//                    }
                }
        } else if videoProcessor.state == .processing {
            Rectangle()
                .fill(Color.gray.opacity(0.6))
                .frame(width: 100, height: 100)
                .overlay(Text("Loading \(video.name)").foregroundColor(.gray).frame(alignment: .center))
        } else if videoProcessor.state == .failed {
            Rectangle()
                .fill(Color.red.opacity(0.2))
                .frame(width: 100, height: 100)
                .overlay(Text("Failed to load: \(video.name)").foregroundColor(.gray).frame(alignment: .center))
        } else {
            Rectangle()
                .fill(Color.gray.opacity(0.2))
                .frame(width: 100, height: 100)
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
                ForEach($pickedFiles, id: \.self) { video in
                    ThumbnailItem(video: video)
                }
            }
        }
    }
}

struct ContentView: View {
    @State private var showDirectoryPicker = false
    @State private var pickedFiles: [VideoFile] = []
    @State private var message: String = "No directory selected."
    
    @StateObject private var videoProcessor = VideoProcessor()
    @State private var selectedVideoURL: URL?


    var body: some View {
        VStack(spacing: 20) {
            Text("Directory File Lister")
                .font(.largeTitle)

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
//                // Display the list of files in a scrollable view
//                List {
//                    ForEach(pickedFiles, id: \.self) { file in
//                        Button(file.name) {
//                            videoProcessor.generateThumbnail(file: file)
//                        }
//                        .disabled(videoProcessor.state == .processing)
//                    }
//                }
//                .frame(maxHeight: 300) // Limit list height to prevent excessive space
//                .border(Color.gray, width: 0.5)
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
    }
}

// MARK: - Preview

#Preview {
    ContentView()
}

