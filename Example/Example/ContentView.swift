//
//  ContentView.swift
//  Example
//
//  Created by ihenryhuang on 2025/4/7.
//

import SwiftUI
import DownloadKit

struct ContentView: View {
    
    let url = URL(string: "https://github.com/BBC6BAE9/video/raw/refs/heads/master/Shogun.S01E01.2024.2160p.DSNP.WEB-DL.DDP5.1.DV.HDR.H.265-HHWEB.mp4")!
    
    init(){
        DownloadManager.shared.maxConcurrentCount = 5
        DownloadManager.shared.waitingQueueMode = .lifo
        
        let path = DownloadManager.shared.fileFullPath(of: url)
        let progress = DownloadManager.shared.hasDownloadedProgress(of: url)
        
        print("path: \(path)")
        print("progress: \(progress)")
    }
    
    var body: some View {
        Button("下载") {
            DownloadManager.shared.download(url: url, destPath: nil) { state in
              print("\(state)")
            } progress: { currentSize, totalSize, percent in
              print("currentSize:\(currentSize), totalSize:\(totalSize), percent:\(percent)")
            } completion: { isFinished, filePath, error in
              print("isFinished:\(isFinished), filePath:\(String(describing: filePath)), error:\(String(describing: error))")
            }
            
        }
    }
}

#Preview {
    ContentView()
}
