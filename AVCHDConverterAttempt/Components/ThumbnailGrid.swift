//
//  ThumbnailGrid.swift
//  AVCHDConverterAttempt
//
//  Created by Zachary Verbeck on 7/2/25.
//

import SwiftUI

struct ThumbnailGrid: View {
    @Binding var pickedFiles: [VideoFile]

    var body: some View {
        ScrollView(.vertical) {
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())]) {
                ForEach($pickedFiles) { $video in
                    NavigationLink(destination: VideoDetailsPage(video: video)) {
                        ThumbnailItem(video: video)
                    }
                }
            }
        }
    }
}

