//
//  DirectoryPicker.swift
//  AVCHDConverterAttempt
//
//  Created by Zachary Verbeck on 6/25/25.
//

import SwiftUI
import UIKit  // For UIDocumentPickerViewController
import UniformTypeIdentifiers  // For UTType.folder

struct DirectoryPicker: UIViewControllerRepresentable {
    @Environment(\.presentationMode) var presentationMode
    var onDirectoryPicked: (String, [VideoFile]) -> Void  // Callback with URLs of files inside
    var onCancelled: () -> Void  // Callback for when the picker is cancelled

    func makeUIViewController(context: Context)
        -> UIDocumentPickerViewController
    {
        // We specify .folder as the content type to allow picking directories
        let picker = UIDocumentPickerViewController(forOpeningContentTypes: [
            .folder
        ])
        picker.delegate = context.coordinator
        picker.allowsMultipleSelection = false  // Picking one directory at a time
        return picker
    }

    func updateUIViewController(
        _: UIDocumentPickerViewController,
        context _: Context
    ) {
        // No updates needed for the picker once it's presented
    }

    // MARK: - Coordinator

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    class Coordinator: NSObject, UIDocumentPickerDelegate,
        UINavigationControllerDelegate
    {
        var parent: DirectoryPicker

        init(parent: DirectoryPicker) {
            self.parent = parent
        }

        func documentPicker(
            _: UIDocumentPickerViewController,
            didPickDocumentsAt urls: [URL]
        ) {
            guard let directoryURL = urls.first else {
                parent.onCancelled()  // No URL picked, treat as cancelled
                parent.presentationMode.wrappedValue.dismiss()
                return
            }

            let granted = directoryURL.startAccessingSecurityScopedResource()
            defer {
                if granted {
                    directoryURL.stopAccessingSecurityScopedResource()
                }
            }

            if granted {
                do {
                    let fileManager = FileManager.default
                    let contents = try fileManager.contentsOfDirectory(
                        at: directoryURL,
                        includingPropertiesForKeys: nil,
                        options: .skipsHiddenFiles
                    )

                    let bookmarkData = try directoryURL.bookmarkData(
                        options: [],
                        includingResourceValuesForKeys: nil,
                        relativeTo: nil
                    )
                    let bookmarkKey =
                        "directoryBookmark_\(directoryURL.lastPathComponent)"
                    UserDefaults.standard.set(bookmarkData, forKey: bookmarkKey)

                    // Filter out subdirectories if you only want files
                    let fileURLs = contents.filter {
                        $0.isFileURL && !fileManager.isDirectory($0) && isMTSFile(url: $0)
                    }

                    var videos: [VideoFile] = []

                    for fileURL in fileURLs {
                        let video = VideoFile(
                            privateURL: fileURL,
                            name: fileURL.lastPathComponent,
                            bookmark: bookmarkData,
                            key: bookmarkKey
                        )
                        videos.append(video)
                    }

                    parent.onDirectoryPicked(
                        directoryURL.lastPathComponent,
                        videos
                    )
                } catch {
                    print(
                        "Error reading directory contents: \(error.localizedDescription)"
                    )
                    // You might want to pass this error back or show an alert
                    parent.onCancelled()  // Treat as a failed pick if reading fails
                }
            } else {
                // Access was not granted by the system, handle accordingly
                print("Access to directory not granted.")
                parent.onCancelled()
            }

            parent.presentationMode.wrappedValue.dismiss()
        }

        func documentPickerWasCancelled(_: UIDocumentPickerViewController) {
            parent.onCancelled()
            parent.presentationMode.wrappedValue.dismiss()
        }
        
        func isMTSFile(url: URL) -> Bool {
            return url.absoluteString.lowercased().hasSuffix(".mts")
        }
    }
}

// MARK: - Helper Extension for FileManager (to check if URL is a directory)

extension FileManager {
    func isDirectory(_ url: URL) -> Bool {
        var isDir: ObjCBool = false
        fileExists(atPath: url.path, isDirectory: &isDir)
        return isDir.boolValue
    }
}
