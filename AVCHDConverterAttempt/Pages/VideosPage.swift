//
//  VideosPage.swift
//  AVCHDConverterAttempt
//
//  Created by Zachary Verbeck on 7/2/25.
//

import SwiftUI

struct VideosPage: View {
    @State private var showDirectoryPicker = false
    @State private var pickedFiles: [VideoFile] = []
    @State private var message: String = "No directory selected."
    @State private var directoryName: String?

    var body: some View {
        VStack(spacing: 20) {
            Section(message) {
                Button("Open Directory") {
                    showDirectoryPicker = true
                }
                .buttonStyle(.borderedProminent)
                .tint(.green)

                if pickedFiles.count > 0 {
                    Text(
                        "Files in \(directoryName ?? "Unknown Directory") (\(pickedFiles.count)):"
                    )
                    .font(.title2)
                    .padding(.top)
                    ThumbnailGrid(pickedFiles: $pickedFiles)
                } else {
                    Spacer()
                }
            }
        }
        .sheet(isPresented: $showDirectoryPicker) {
            DirectoryPicker(
                onDirectoryPicked: { directoryName, files in
                    self.directoryName = directoryName
                    self.pickedFiles = files
                    self.message =
                        "Successfully read \(files.count) files from directory."
                },
                onCancelled: {
                    self.message = "Directory picker cancelled or failed."
                    self.pickedFiles = []
                }
            )
        }
        .navigationTitle("Directory picker")
        .navigationBarTitleDisplayMode(.automatic)
    }
}

struct VideosPage_Previews: PreviewProvider {
    static var previews: some View {
        VideosPage()
    }
}
