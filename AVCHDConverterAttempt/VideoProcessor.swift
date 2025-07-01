//
//  VideoProcessor.swift
//  AVCHDConverterAttempt
//
//  Created by Zachary Verbeck on 6/25/25.
//

import SwiftUI
import ffmpegkit // Import the main framework
import Foundation // For URL, FileManager

enum ProcessorState {
    case new
    case processing
    case processed
    case failed
}

class VideoProcessor: ObservableObject {
    @Published var state: ProcessorState = .new
    
    func executeFfmpegCommand(video: Binding<VideoFile>, command: String, callback: @escaping FFmpegSessionCompleteCallback) {
        state = .processing
        guard let bookmarkData = UserDefaults.standard.data(forKey: video.wrappedValue.key) else {
            print("no bookmark for key: \(video.wrappedValue.key) - skipping")
            return
        }
        
        do {
            var isStale = false

            let directoryURL = try URL(resolvingBookmarkData: bookmarkData,
                                        options: [], // Empty options
                                        relativeTo: nil,
                                        bookmarkDataIsStale: &isStale)
            if isStale {
                print("Warning: Bookmark for key '\(video.wrappedValue.key)' is stale. It might need to be recreated by the user.")
                // In a real app, you would likely prompt the user to re-select the directory.
                UserDefaults.standard.removeObject(forKey: video.wrappedValue.key) // Clear stale bookmark
                return
            }
            let didStartAccessing = directoryURL.startAccessingSecurityScopedResource()
            defer {
                if didStartAccessing {
                    directoryURL.stopAccessingSecurityScopedResource()
                }
            }

            FFmpegKit.executeAsync(command, withCompleteCallback: callback)
        } catch {
            print("Error resolving bookmark for key '\(video.wrappedValue.key)': \(error.localizedDescription)")
            return
        }
    }
    
    func executeFfprobeCommand(video: Binding<VideoFile>) {
        state = .processing
        guard let bookmarkData = UserDefaults.standard.data(forKey: video.wrappedValue.key) else {
            print("no bookmark for key: \(video.wrappedValue.key) - skipping")
            return
        }
        
        do {
            var isStale = false

            let directoryURL = try URL(resolvingBookmarkData: bookmarkData,
                                        options: [], // Empty options
                                        relativeTo: nil,
                                        bookmarkDataIsStale: &isStale)
            if isStale {
                print("Warning: Bookmark for key '\(video.wrappedValue.key)' is stale. It might need to be recreated by the user.")
                // In a real app, you would likely prompt the user to re-select the directory.
                UserDefaults.standard.removeObject(forKey: video.wrappedValue.key) // Clear stale bookmark
                return
            }
            let didStartAccessing = directoryURL.startAccessingSecurityScopedResource()
            defer {
                if didStartAccessing {
                    directoryURL.stopAccessingSecurityScopedResource()
                }
            }

            let session = FFprobeKit.getMediaInformation(video.wrappedValue.privateURL.path)
            guard let info = session?.getMediaInformation()
            else {
                return
            }
            guard let durationString = info.getDuration(),
                let duration = Double(durationString)
            else {
                print("No duration")
                return
            }
            print("Duration: \(duration) seconds")
            guard let sizeString = info.getSize()
            else {
                print("No size")
                return
            }
            print("Size: \(sizeString)")
            
            guard let formatString = info.getFormat()
            else {
                print("No format")
                return
            }
            print("Format: \(formatString)")
            guard let videoStream: StreamInformation = info.getStreams()?.first as? StreamInformation
            else {
                print("No video???")
                return
            }
            guard let properties = videoStream.getAllProperties()
            else {
                print("no PROPERTIES??")
                return
            }
            properties.forEach { print("key: \($0) value: \($1)")}
        } catch {
            print("Error resolving bookmark for key '\(video.wrappedValue.key)': \(error.localizedDescription)")
            return
        }
    }

    func generateThumbnail(video: Binding<VideoFile>) {
        let thumbnailOutputFileName = "thumbnail_\(video.wrappedValue.name).jpg"
        let tempDirectory = FileManager.default.temporaryDirectory
        let thumbnailOutputPath = tempDirectory.appendingPathComponent(thumbnailOutputFileName)
        
        // Define the FFmpeg command
        // -ss 00:00:05: Seek to 5 seconds
        // -i: Input file
        // -frames:v 1: Output only one video frame
        // -an: No audio
        // -vf "scale=iw*max(100/iw\,100/ih):ih*max(100/iw\,100/ih),crop=100:100": Scale and center-crop to 100x100
        // -q:v 2: JPEG quality (1=best, 31=worst)
        let command = "-y -ss 00:00:01 -i \"\(video.wrappedValue.privateURL.path)\" -frames:v 1 -an -vf \"scale=iw*max(100/iw\\,100/ih):ih*max(100/iw\\,100/ih),crop=100:100\" -q:v 2 \"\(thumbnailOutputPath.path)\""

        print("FFmpeg command: \(command)")
        
        executeFfmpegCommand(video: video, command: command) { session in
            guard let returnCode = session?.getReturnCode() else {
                DispatchQueue.main.async {
                    self.state = .failed
                }
                return
            }

            if ReturnCode.isSuccess(returnCode) {
                DispatchQueue.main.async {
                    print("Thumbnail saved! \(thumbnailOutputPath.path)")
                    self.state = .processed
                    video.wrappedValue.thumbnail = thumbnailOutputPath
                }
            } else if ReturnCode.isCancel(returnCode) {
                DispatchQueue.main.async {
                    self.state = .new
                }
            } else {
                DispatchQueue.main.async {
                    let logs = session?.getAllLogsAsString() ?? "No logs."
                    self.state = .failed
                    print("FFmpeg failed: \(returnCode.description), logs: \(logs)")
                }
            }
        }
    }
    
    func generateConvertedMp4(video: Binding<VideoFile>) {
        let tempDirectory = FileManager.default.temporaryDirectory
        let mp4OutputFile = "converted_\(video.wrappedValue.privateURL.deletingPathExtension().lastPathComponent).mp4"
        let convertedOutputPath = tempDirectory.appendingPathComponent(mp4OutputFile)
        
        let command = "-y -i \"\(video.wrappedValue.privateURL.path)\" -c copy \"\(convertedOutputPath.path)\""

        print("FFmpeg command: \(command)")
        
        executeFfmpegCommand(video: video, command: command) { session in
            guard let returnCode = session?.getReturnCode() else {
                DispatchQueue.main.async {
                    self.state = .failed
                }
                return
            }

            if ReturnCode.isSuccess(returnCode) {
                DispatchQueue.main.async {
                    print("video saved saved! \(convertedOutputPath.path)")
                    self.state = .processed
                    video.wrappedValue.convertedURL = convertedOutputPath
                }
            } else if ReturnCode.isCancel(returnCode) {
                DispatchQueue.main.async {
                    self.state = .new
                }
            } else {
                DispatchQueue.main.async {
                    let logs = session?.getAllLogsAsString() ?? "No logs."
                    self.state = .failed
                    print("FFmpeg failed: \(returnCode.description), logs: \(logs)")
                }
            }
        }
    }
    
    func parseFileInfo(video: Binding<VideoFile>) {
        return executeFfprobeCommand(video: video)
    }

    // Helper function to clean up temporary files
    func cleanUpThumbnail(video: Binding<VideoFile>) {
        if (video.wrappedValue.thumbnail == nil) {
            return
        }
        let url = video.wrappedValue.thumbnail!
        do {
            try FileManager.default.removeItem(at: url)
            print("Cleaned up thumbnail at: \(video.wrappedValue.thumbnail!)")
            video.wrappedValue.thumbnail = nil
        } catch {
            print("Error cleaning up thumbnail: \(error.localizedDescription)")
        }
    }
}
