//
//  AVCHDConverterAttemptApp.swift
//  AVCHDConverterAttempt
//
//  Created by Zachary Verbeck on 6/24/25.
//

import SwiftUI

@main
struct AVCHDConverterAttemptApp: App {
    @State private var videoProcessor = VideoProcessor()
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(videoProcessor)
        }
    }
}
