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
    @Published var videoFile: VideoFile?
    @Published var state: ProcessorState = .new

    func generateThumbnail(videoUrl: URL) {
        state = .processing
        videoFile = nil

        // Ensure the video URL is accessible to FFmpegKit
        // If it's from DocumentPicker, it might be security-scoped.
        // FFmpegKit can sometimes handle security-scoped URLs directly,
        // but for robust access, it's safer to copy to a temporary path
        // or ensure persistent access if needed.

        // For simplicity here, let's assume videoUrl is already a file URL
        // that FFmpegKit can directly access. If not, copy it first.

        let thumbnailOutputFileName = "thumbnail_\(UUID().uuidString).jpg"
        let tempDirectory = FileManager.default.temporaryDirectory
        print(tempDirectory)
        let thumbnailOutputPath = tempDirectory.appendingPathComponent(thumbnailOutputFileName)

        // Define the FFmpeg command
        // -ss 00:00:05: Seek to 5 seconds
        // -i: Input file
        // -frames:v 1: Output only one video frame
        // -an: No audio
        // -vf "scale=iw*max(100/iw\,100/ih):ih*max(100/iw\,100/ih),crop=100:100": Scale and center-crop to 100x100
        // -q:v 2: JPEG quality (1=best, 31=worst)
        let command = "-ss 00:00:05 -i \"\(videoUrl.path)\" -frames:v 1 -an -vf \"scale=iw*max(100/iw\\,100/ih):ih*max(100/iw\\,100/ih),crop=100:100\" -q:v 2 \"\(thumbnailOutputPath.path)\""

        print("FFmpeg command: \(command)")

        FFmpegKit.executeAsync(command) { session in
            guard let returnCode = session?.getReturnCode() else {
                DispatchQueue.main.async {
                    self.state = .failed
                }
                return
            }

            if ReturnCode.isSuccess(returnCode) {
                DispatchQueue.main.async {
                    self.videoFile = thumbnailOutputPath.path
                    self.state = .processed
                    print("Thumbnail saved to: \(thumbnailOutputPath.path)")
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

    // Helper function to clean up temporary files
    func cleanUpThumbnail() {
        if let path = videoFile {
            let url = URL(fileURLWithPath: path)
            do {
                try FileManager.default.removeItem(at: url)
                print("Cleaned up thumbnail at: \(path)")
                videoFile = nil
            } catch {
                print("Error cleaning up thumbnail: \(error.localizedDescription)")
            }
        }
    }
}
