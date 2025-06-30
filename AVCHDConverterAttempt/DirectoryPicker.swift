//
//  DirectoryPicker.swift
//  AVCHDConverterAttempt
//
//  Created by Zachary Verbeck on 6/25/25.
//

import SwiftUI
import UniformTypeIdentifiers // For UTType.folder
import UIKit // For UIDocumentPickerViewController

struct DirectoryPicker: UIViewControllerRepresentable {
    @Environment(\.presentationMode) var presentationMode
    var onDirectoryPicked: ([VideoFile]) -> Void // Callback with URLs of files inside
    var onCancelled: () -> Void // Callback for when the picker is cancelled

    func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
        // We specify .folder as the content type to allow picking directories
        let picker = UIDocumentPickerViewController(forOpeningContentTypes: [.folder])
        picker.delegate = context.coordinator
        picker.allowsMultipleSelection = false // Picking one directory at a time
        return picker
    }

    func updateUIViewController(_ uiViewController: UIDocumentPickerViewController, context: Context) {
        // No updates needed for the picker once it's presented
    }

    // MARK: - Coordinator

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    class Coordinator: NSObject, UIDocumentPickerDelegate, UINavigationControllerDelegate {
        var parent: DirectoryPicker

        init(parent: DirectoryPicker) {
            self.parent = parent
        }

        func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
            guard let directoryURL = urls.first else {
                parent.onCancelled() // No URL picked, treat as cancelled
                parent.presentationMode.wrappedValue.dismiss()
                return
            }

            // --- IMPORTANT: Start accessing the security-scoped resource ---
            let granted = directoryURL.startAccessingSecurityScopedResource()
            defer { // Ensure stopAccessingSecurityScopedResource() is called when exiting this scope
                if granted {
                    directoryURL.stopAccessingSecurityScopedResource()
                }
            }

            if granted {
                do {
                    let fileManager = FileManager.default
                    let contents = try fileManager.contentsOfDirectory(
                        at: directoryURL,
                        includingPropertiesForKeys: nil, // No need for specific properties for just listing
                        options: .skipsHiddenFiles // Skip hidden files like .DS_Store
                    )
                    
                    let bookmarkData = try directoryURL.bookmarkData(options: [], includingResourceValuesForKeys: nil, relativeTo: nil)
                    let bookmarkKey = "directoryBookmark_\(directoryURL.lastPathComponent)"
                    UserDefaults.standard.set(bookmarkData, forKey: bookmarkKey)

                    // Filter out subdirectories if you only want files
                    let fileURLs = contents.filter { $0.isFileURL && !fileManager.isDirectory($0) }

                    let tempDirectoryURL = fileManager.temporaryDirectory // Get the temp directory URL
                    var data: [VideoFile] = []

                    for fileURL in fileURLs {
                        var fileData = VideoFile(privateUrl: fileURL, fileName: fileURL.lastPathComponent, bookmark: bookmarkData, key: bookmarkKey)
                        data.append(fileData)

                        
//                        let destinationURL = tempDirectoryURL.appendingPathComponent(fileName)
//                        copiedFiles.append(destinationURL)
//
//                        do {
//                            try fileManager.copyItem(at: fileURL, to: destinationURL) // Copy the file
//                            print("Copied \(fileName) to temporary directory.")
//                            copiedFiles.append(destinationURL)
//                        } catch {
//                            print("Error copying file \(fileName): \(error.localizedDescription)")
//                        }
                        
                    }
                    
                    parent.onDirectoryPicked(data)
                } catch {
                    print("Error reading directory contents: \(error.localizedDescription)")
                    // You might want to pass this error back or show an alert
                    parent.onCancelled() // Treat as a failed pick if reading fails
                }
            } else {
                // Access was not granted by the system, handle accordingly
                print("Access to directory not granted.")
                parent.onCancelled()
            }

            parent.presentationMode.wrappedValue.dismiss()
        }

        func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
            parent.onCancelled()
            parent.presentationMode.wrappedValue.dismiss()
        }
    }
}

// MARK: - Helper Extension for FileManager (to check if URL is a directory)

extension FileManager {
    func isDirectory(_ url: URL) -> Bool {
        var isDir: ObjCBool = false
        self.fileExists(atPath: url.path, isDirectory: &isDir)
        return isDir.boolValue
    }
}
