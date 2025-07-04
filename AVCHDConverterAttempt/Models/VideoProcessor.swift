//
//  VideoProcessor.swift
//  AVCHDConverterAttempt
//
//  Created by Zachary Verbeck on 6/25/25.
//

import Dispatch
import Foundation  // For URL, FileManager
import SwiftUI
import ffmpegkit  // Import the main framework

enum ConversionType: String {
    case thumbnail = "Thumbnail"
    case mp4 = "MP4VideoConversion"
}

@Observable class VideoProcessor {
    private var activeTasks: [String: DispatchWorkItem] = [:]
    private let stateLock = NSLock()
    private let queue = DispatchQueue(
        label: "com.zacharyverbeck.AVCHDConverterAttempt.VideoProcessor",
        qos: .userInitiated,
        attributes: .concurrent,
    )
    private let semaphore = DispatchSemaphore(value: 1)

    init() {}

    func executeFfmpegCommand(
        video: VideoFile,
        taskId: String,
        outputURL: URL,
        command: String,
        callback: @escaping (LoadingURLResult) -> Void
    ) {
        guard let bookmarkData = UserDefaults.standard.data(forKey: video.key)
        else {
            print("no bookmark for key: \(video.key) - skipping")
            return
        }
        do {
            var isStale = false

            let directoryURL = try URL(
                resolvingBookmarkData: bookmarkData,
                options: [],  // Empty options
                relativeTo: nil,
                bookmarkDataIsStale: &isStale
            )
            if isStale {
                print(
                    "Warning: Bookmark for key '\(video.key)' is stale. It might need to be recreated by the user."
                )
                // In a real app, you would likely prompt the user to re-select the directory.
                UserDefaults.standard.removeObject(forKey: video.key)  // Clear stale bookmark
                return
            }
            let didStartAccessing =
                directoryURL.startAccessingSecurityScopedResource()
            defer {
                if didStartAccessing {
                    directoryURL.stopAccessingSecurityScopedResource()
                }
            }
            self.stateLock.lock()
            if self.activeTasks[taskId] != nil {
                print(
                    "Current session for \(video.id) already exists, ignoring"
                )
                self.stateLock.unlock()
                return
            }
            self.stateLock.unlock()

            var task: DispatchWorkItem!
            task = DispatchWorkItem {
                self.semaphore.wait()

                defer {
                    self.stateLock.lock()
                    self.activeTasks[taskId] = nil
                    self.stateLock.unlock()
                    self.semaphore.signal()
                }

                if task.isCancelled {
                    callback(.new)
                    return
                }

                let session = FFmpegKit.execute(command)
                guard let returnCode = session?.getReturnCode() else {
                    callback(.new)
                    return
                }

                if ReturnCode.isSuccess(returnCode) {
                    callback(.success(outputURL))
                } else if ReturnCode.isCancel(returnCode) {
                    print("Cancelled generating thumbnail for \(video.name)")
                    callback(.new)
                } else {
                    print(
                        "FFmpeg failed: \(returnCode.description)"
                    )
                    callback(.failed)
                }
            }

            queue.async(execute: task)
            self.stateLock.lock()
            self.activeTasks[taskId] = task
            self.stateLock.unlock()
        } catch {
            print(
                "Error resolving bookmark for key '\(video.key)': \(error.localizedDescription)"
            )
            return
        }
    }

    func executeFfprobeCommand(video: VideoFile) {
        guard let bookmarkData = UserDefaults.standard.data(forKey: video.key)
        else {
            print("no bookmark for key: \(video.key) - skipping")
            return
        }

        do {
            var isStale = false

            let directoryURL = try URL(
                resolvingBookmarkData: bookmarkData,
                options: [],  // Empty options
                relativeTo: nil,
                bookmarkDataIsStale: &isStale
            )
            if isStale {
                print(
                    "Warning: Bookmark for key '\(video.key)' is stale. It might need to be recreated by the user."
                )
                // In a real app, you would likely prompt the user to re-select the directory.
                UserDefaults.standard.removeObject(forKey: video.key)  // Clear stale bookmark
                return
            }
            let didStartAccessing =
                directoryURL.startAccessingSecurityScopedResource()
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
                let videoStream: StreamInformation = info.getStreams()?.first
                    as? StreamInformation,
                let properties = videoStream.getAllProperties(),
                let framerate = properties["avg_frame_rate"] as? String,
                let height = properties["height"] as? Int,
                let width = properties["width"] as? Int
            else {
                return
            }

            let details = VideoDetails(
                duration: duration,
                height: height,
                width: width,
                framerate: framerate
            )
            video.details = details
        } catch {
            print(
                "Error resolving bookmark for key '\(video.key)': \(error.localizedDescription)"
            )
            return
        }
    }

    func generateThumbnail(video: VideoFile) {
        let thumbnailOutputFileName =
            "thumbnail_\(video.privateURL.deletingPathExtension().lastPathComponent).jpg"
        let tempDirectory = FileManager.default.temporaryDirectory
        let thumbnailOutputPath = tempDirectory.appendingPathComponent(
            thumbnailOutputFileName
        )

        // Define the FFmpeg command
        // -ss 00:00:01: Seek to 1 seconds
        // -i: Input file
        // -frames:v 1: Output only one video frame
        // -an: No audio
        // -vf "scale=iw*max(100/iw\,100/ih):ih*max(100/iw\,100/ih),crop=100:100": Scale and center-crop to 100x100
        // -q:v 2: JPEG quality (1=best, 31=worst)
        let command =
            "-y -ss 00:00:01 -i \"\(video.privateURL.path)\" -frames:v 1 -an -vf \"scale=iw*max(100/iw\\,100/ih):ih*max(100/iw\\,100/ih),crop=100:100\" -q:v 4 \"\(thumbnailOutputPath.path)\""

        print("FFmpeg command: \(command)")

        let taskId = self.getNamespacedId(uuid: video.id, namespace: .thumbnail)
        video.thumbnail = .loading(taskId)

        executeFfmpegCommand(
            video: video,
            taskId: taskId,
            outputURL: thumbnailOutputPath,
            command: command
        ) { result in
            DispatchQueue.main.async {
                video.thumbnail = result
            }
        }
    }

    func generateConvertedMp4(video: VideoFile) {
        let tempDirectory = FileManager.default.temporaryDirectory
        let mp4OutputFile =
            "converted_\(video.privateURL.deletingPathExtension().lastPathComponent).mp4"
        let convertedOutputPath = tempDirectory.appendingPathComponent(
            mp4OutputFile
        )
        parseFileInfo(video: video)

        var commandArgs = [
            "-y",
            "-i", video.privateURL.path,
            "-c:v", "copy",
            //            "-c:a aac -strict experimental -b:a 128k",
            "-c:a", "copy",
            "-f", "mp4",
            //            "-vsync", "2",
        ]

        if let framerate = video.details?.framerate {
            commandArgs.append(contentsOf: ["-r", String(framerate)])
        }

        commandArgs.append(convertedOutputPath.path)

        let command = commandArgs.joined(separator: " ")
        print("FFmpeg command: \(command)")
        let taskId = self.getNamespacedId(uuid: video.id, namespace: .thumbnail)
        video.convertedURL = .loading(taskId)
        executeFfmpegCommand(
            video: video,
            taskId: taskId,
            outputURL: convertedOutputPath,
            command: command
        ) { result in
            DispatchQueue.main.async {
                video.convertedURL = result
            }
        }
    }

    func parseFileInfo(video: VideoFile) {
        return executeFfprobeCommand(video: video)
    }

    // Helper function to clean up temporary files
    func cleanUpFile(loadingURL: LoadingURLResult) -> LoadingURLResult {
        if let path = loadingURL.value() {
            do {
                try FileManager.default.removeItem(at: path)
                print("Cleaned up thumbnail at: \(path)")
                return LoadingURLResult.new
            } catch {
                print(
                    "Error cleaning up thumbnail: \(error.localizedDescription)"
                )
            }
        }
        return loadingURL
    }

    func cancelSessionForID(id: String) {
        self.stateLock.lock()
        if let task = activeTasks[id] {
            task.cancel()
        }
        activeTasks.removeValue(forKey: id)
        self.stateLock.unlock()
    }

    func cancelAllSessions() {
        stateLock.lock()
        for task in activeTasks.values {
            task.cancel()
        }
        activeTasks.removeAll()
        stateLock.unlock()
    }

    func sessionExistsForID(id: String) -> Bool {
        stateLock.lock()
        defer { stateLock.unlock() }
        return activeTasks[id] != nil
    }

    private func getNamespacedId(uuid: UUID, namespace: ConversionType)
        -> String
    {
        return "\(namespace)-\(uuid)"
    }
}
