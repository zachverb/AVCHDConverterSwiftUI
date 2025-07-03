//
//  VideoProcessor.swift
//  AVCHDConverterAttempt
//
//  Created by Zachary Verbeck on 6/25/25.
//

import ffmpegkit // Import the main framework
import Foundation // For URL, FileManager
import SwiftUI

enum ProcessorState {
    case new
    case processing
    case processed
    case failed
}

class VideoProcessor: ObservableObject {
    @Published var state: ProcessorState = .new
    private var currentFFmpegSession: FFmpegSession?

    func executeFfmpegCommand(video: VideoFile, command: String, callback: @escaping FFmpegSessionCompleteCallback) {
        state = .processing
        guard let bookmarkData = UserDefaults.standard.data(forKey: video.key) else {
            print("no bookmark for key: \(video.key) - skipping")
            return
        }

        do {
            var isStale = false

            let directoryURL = try URL(resolvingBookmarkData: bookmarkData,
                                       options: [], // Empty options
                                       relativeTo: nil,
                                       bookmarkDataIsStale: &isStale)
            if isStale {
                print("Warning: Bookmark for key '\(video.key)' is stale. It might need to be recreated by the user.")
                // In a real app, you would likely prompt the user to re-select the directory.
                UserDefaults.standard.removeObject(forKey: video.key) // Clear stale bookmark
                return
            }
            let didStartAccessing = directoryURL.startAccessingSecurityScopedResource()
            defer {
                if didStartAccessing {
                    directoryURL.stopAccessingSecurityScopedResource()
                }
            }

            currentFFmpegSession = FFmpegKit.executeAsync(command, withCompleteCallback: callback)
        } catch {
            print("Error resolving bookmark for key '\(video.key)': \(error.localizedDescription)")
            return
        }
    }

    func executeFfprobeCommand(video: VideoFile) {
        guard let bookmarkData = UserDefaults.standard.data(forKey: video.key) else {
            print("no bookmark for key: \(video.key) - skipping")
            return
        }

        do {
            var isStale = false

            let directoryURL = try URL(resolvingBookmarkData: bookmarkData,
                                       options: [], // Empty options
                                       relativeTo: nil,
                                       bookmarkDataIsStale: &isStale)
            if isStale {
                print("Warning: Bookmark for key '\(video.key)' is stale. It might need to be recreated by the user.")
                // In a real app, you would likely prompt the user to re-select the directory.
                UserDefaults.standard.removeObject(forKey: video.key) // Clear stale bookmark
                return
            }
            let didStartAccessing = directoryURL.startAccessingSecurityScopedResource()
            defer {
                if didStartAccessing {
                    directoryURL.stopAccessingSecurityScopedResource()
                }
            }

            let session = FFprobeKit.getMediaInformation(video.privateURL.path)
            guard let info = session?.getMediaInformation()
            else {
                return
            }
            guard let durationString = info.getDuration(),
                  let duration = Double(durationString),
                  let videoStream: StreamInformation = info.getStreams()?.first as? StreamInformation,
                  let properties = videoStream.getAllProperties(),
                  let framerate = properties["avg_frame_rate"] as? String,
                  let height = properties["height"] as? Int,
                  let width = properties["width"] as? Int
            else {
                return
            }

            let details = VideoDetails(duration: duration, height: height, width: width, framerate: framerate)
            video.details = details
        } catch {
            print("Error resolving bookmark for key '\(video.key)': \(error.localizedDescription)")
            return
        }
    }

    func generateThumbnail(video: VideoFile) {
        let thumbnailOutputFileName = "thumbnail_\(video.privateURL.deletingPathExtension().lastPathComponent).jpg"
        let tempDirectory = FileManager.default.temporaryDirectory
        let thumbnailOutputPath = tempDirectory.appendingPathComponent(thumbnailOutputFileName)

        // Define the FFmpeg command
        // -ss 00:00:05: Seek to 5 seconds
        // -i: Input file
        // -frames:v 1: Output only one video frame
        // -an: No audio
        // -vf "scale=iw*max(100/iw\,100/ih):ih*max(100/iw\,100/ih),crop=100:100": Scale and center-crop to 100x100
        // -q:v 2: JPEG quality (1=best, 31=worst)
        let command = "-y -ss 00:00:01 -i \"\(video.privateURL.path)\" -frames:v 1 -an -vf \"scale=iw*max(100/iw\\,100/ih):ih*max(100/iw\\,100/ih),crop=100:100\" -q:v 2 \"\(thumbnailOutputPath.path)\""

        print("FFmpeg command: \(command)")

        executeFfmpegCommand(video: video, command: command) { session in
            guard let returnCode = session?.getReturnCode() else {
                DispatchQueue.main.async {
                    self.state = .failed
                }
                return
            }

            DispatchQueue.main.async {
                self.currentFFmpegSession = nil
                if ReturnCode.isSuccess(returnCode) {
                    print("Thumbnail saved! \(thumbnailOutputPath.path)")
                    self.state = .processed
                    video.thumbnail = thumbnailOutputPath
                } else if ReturnCode.isCancel(returnCode) {
                    print("Cancelled session!")
                    self.state = .new
                } else {
                    let logs = session?.getAllLogsAsString() ?? "No logs."
                    self.state = .failed
                    print("FFmpeg failed: \(returnCode.description), logs: \(logs)")
                }
            }
        }
    }

    func generateConvertedMp4(video: VideoFile) {
        let tempDirectory = FileManager.default.temporaryDirectory
        let mp4OutputFile = "converted_\(video.privateURL.deletingPathExtension().lastPathComponent).mp4"
        let convertedOutputPath = tempDirectory.appendingPathComponent(mp4OutputFile)
        parseFileInfo(video: video)

        var commandArgs = [
            "-y",
            "-i", video.privateURL.path,
            "-c:v", "copy",
            "-c:a", "copy",
            "-f", "mp4",
            "-vsync", "2",
        ]

        if let framerate = video.details?.framerate {
            commandArgs.append(contentsOf: ["-r", String(framerate)])
        }

        commandArgs.append(convertedOutputPath.path)

        let command = commandArgs.joined(separator: " ")
        print("FFmpeg command: \(command)")

        executeFfmpegCommand(video: video, command: command) { session in
            guard let returnCode = session?.getReturnCode() else {
                DispatchQueue.main.async {
                    self.state = .failed
                }
                return
            }

            DispatchQueue.main.async {
                if ReturnCode.isSuccess(returnCode) {
                    print("video saved! \(convertedOutputPath.path)")
                    self.state = .processed
                    video.convertedURL = convertedOutputPath
                } else if ReturnCode.isCancel(returnCode) {
                    print("Cancelled session!")
                    self.state = .new
                } else {
                    let logs = session?.getAllLogsAsString() ?? "No logs."
                    self.state = .failed
                    print("FFmpeg failed: \(returnCode.description), logs: \(logs)")
                }
            }
        }
    }

    func parseFileInfo(video: VideoFile) {
        return executeFfprobeCommand(video: video)
    }

    // Helper function to clean up temporary files
    func cleanUpThumbnail(video: VideoFile) {
        if video.thumbnail == nil {
            return
        }
        let url = video.thumbnail!
        do {
            try FileManager.default.removeItem(at: url)
            print("Cleaned up thumbnail at: \(video.thumbnail!)")
            video.thumbnail = nil
        } catch {
            print("Error cleaning up thumbnail: \(error.localizedDescription)")
        }
    }

    func cancelActiveSession() {
        if let session = currentFFmpegSession {
            session.cancel()
        }
        currentFFmpegSession = nil
    }
}
