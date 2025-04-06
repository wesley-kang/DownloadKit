```swift
DownloadManager.shared.maxConcurrentCount = 5
DownloadManager.shared.waitingQueueMode = .lifo

let url = URL(string: "https://github.com/BBC6BAE9/video/raw/refs/heads/master/Shogun.S01E01.2024.2160p.DSNP.WEB-DL.DDP5.1.DV.HDR.H.265-HHWEB.mp4")!
let path = DownloadManager.shared.fileFullPath(of: url)
let progress = DownloadManager.shared.hasDownloadedProgress(of: url)

DownloadManager.shared.download(url: url, destPath: nil) { state in
  print("\(state)")
} progress: { currentSize, totalSize, percent in
  print("currentSize:\(currentSize), totalSize:\(totalSize), percent:\(percent)")
} completion: { isFinished, filePath, error in
  print("isFinished:\(isFinished), filePath:\(String(describing: filePath)), error:\(String(describing: error))")
}
```
