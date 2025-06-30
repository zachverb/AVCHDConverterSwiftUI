//
//  ContentView.swift
//  AVCHDConverterAttempt
//
//  Created by Zachary Verbeck on 6/24/25.
//

import SwiftUI

// MARK: - Example Usage in a SwiftUI View

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
                
                // Display the list of files in a scrollable view
                List {
                    ForEach(pickedFiles, id: \.self) { url in
                        Button(url.lastPathComponent) {
                            selectedVideoURL = url.absoluteURL
                            if (selectedVideoURL != nil) {
                                videoProcessor.generateThumbnail(videoUrl: selectedVideoURL!)
                            }
                        }
                        .disabled(videoProcessor.processingMessage.contains("Generating"))
                    }
                }
                .frame(maxHeight: 300) // Limit list height to prevent excessive space
                .border(Color.gray, width: 0.5)
            }
            
            if let path = videoProcessor.thumbnailPath {
                Image(uiImage: UIImage(contentsOfFile: path) ?? UIImage()) // Load image from path
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 150, height: 150)
                    .cornerRadius(10)
                    .shadow(radius: 5)
                    .onAppear {
                        // Automatically clean up after 10 seconds for demo purposes
                        // In a real app, manage cleanup based on your needs
                        DispatchQueue.main.asyncAfter(deadline: .now() + 10) {
                            videoProcessor.cleanUpThumbnail()
                        }
                    }
            } else {
                Rectangle()
                    .fill(Color.gray.opacity(0.2))
                    .frame(width: 150, height: 150)
                    .cornerRadius(10)
                    .overlay(Text("Thumbnail Area").foregroundColor(.gray))
            }


        }
        .sheet(isPresented: $showDirectoryPicker) {
            DirectoryPicker(
                onDirectoryPicked: { files in
                    self.pickedFiles = files
                    self.message = "Successfully read \(files.count) files from directory."
                    print("Picked files: \(files.map { $0.lastPathComponent })")
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

