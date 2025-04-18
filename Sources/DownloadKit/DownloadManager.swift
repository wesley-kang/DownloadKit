//
//  DownloadManager.swift
//  DownloadManager
//

import Foundation

public enum SRWaitingQueueMode: Int {
    case fifo // First In First Out
    case lifo // Last In First Out
}

public class DownloadManager: NSObject, @unchecked Sendable {
    
    // MARK: - Properties
    
    /// The directory where downloaded files are cached, default is .../Library/Caches/SRDownloadManager if not set.
    var cacheFilesDirectory: String? {
        didSet {
            guard let cacheFilesDirectory = cacheFilesDirectory else { return }
            
            var isDirectory: ObjCBool = false
            let fileManager = FileManager.default
            let isExists = fileManager.fileExists(atPath: cacheFilesDirectory, isDirectory: &isDirectory)
            
            if !isExists || !isDirectory.boolValue {
                try? fileManager.createDirectory(atPath: cacheFilesDirectory, withIntermediateDirectories: true, attributes: nil)
            }
        }
    }
    
    /// The count of max concurrent downloads, default is -1 which means no limit.
    public var maxConcurrentCount: Int = -1
    
    /// The mode of waiting download queue, default is FIFO.
    public var waitingQueueMode: SRWaitingQueueMode = .fifo
    
    private var downloadSession: URLSession!
    private var downloadModels: [String: DownloadModel] = [:]
    private var downloadingModels: [DownloadModel] = []
    private var waitingModels: [DownloadModel] = []
    private var filesTotalLengthPlist: [String: Any] = [:]
    
    // MARK: - Singleton
    
    public static let shared = DownloadManager()
    
    private override init() {
        super.init()
        
        maxConcurrentCount = -1
        waitingQueueMode = .fifo
        
        // 先设置缓存目录路径
        self.cacheFilesDirectory = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).last!
            .appendingPathComponent("CustomDownloadDirectory").path
        
        // 然后创建目录
        let downloadDirectory = self.downloadDirectory
        var isDirectory: ObjCBool = false
        let fileManager = FileManager.default
        let isExists = fileManager.fileExists(atPath: downloadDirectory, isDirectory: &isDirectory)
        
        if !isExists || !isDirectory.boolValue {
            try? fileManager.createDirectory(atPath: downloadDirectory, withIntermediateDirectories: true, attributes: nil)
        }
        
        downloadSession = URLSession(configuration: .default, delegate: self, delegateQueue: OperationQueue())
        
        if let plist = NSDictionary(contentsOfFile: filesTotalLengthPlistPath) as? [String: Any] {
            filesTotalLengthPlist = plist
        } else {
            filesTotalLengthPlist = [:]
        }
    }
    
    // MARK: - Helper Methods
    
    private var downloadDirectory: String {
        return cacheFilesDirectory ?? (NSSearchPathForDirectoriesInDomains(.cachesDirectory, .userDomainMask, true).last!
            .appending("/\(type(of: self))"))
    }
    
    private func fileName(for url: URL) -> String {
        return url.lastPathComponent
    }
    
    private func filePath(for url: URL) -> String {
        return (downloadDirectory as NSString).appendingPathComponent(fileName(for: url))
    }
    
    private var filesTotalLengthPlistPath: String {
        let xxx = (downloadDirectory as NSString).appendingPathComponent("SRFilesTotalLength.plist")
        return xxx
    }
    
    // MARK: - Download Methods
    
    public func download(url: URL, 
                 destPath: String? = nil,
                 state: StateBlock? = nil,
                 progress: ProgressBlock? = nil,
                 completion: CompletionBlock? = nil) {
        
        assert(url != URL(string: ""), "URL can not be nil, please pass the resource's URL which you want to download")
        
        if isDownloadCompleted(of: url) {
            state?(.completed)
            completion?(true, filePath(for: url), nil)
            return
        }
        
        let fileName = self.fileName(for: url)
        if downloadModels[fileName] != nil {
            return
        }
        
        var request = URLRequest(url: url)
        request.setValue("bytes=\(hasDownloadedLength(url))-", forHTTPHeaderField: "Range")
        
        let dataTask = downloadSession.dataTask(with: request)
        dataTask.taskDescription = fileName
        
        let downloadModel = DownloadModel()
        downloadModel.dataTask = dataTask
        downloadModel.outputStream = OutputStream(toFileAtPath: filePath(for: url), append: true)
        downloadModel.url = url
        downloadModel.destPath = destPath
        downloadModel.state = state
        downloadModel.progress = progress
        downloadModel.completion = completion
        
        downloadModels[fileName] = downloadModel
        
        let downloadState: DownloadState
        if canResumeDownload() {
            downloadingModels.append(downloadModel)
            dataTask.resume()
            downloadState = .running
        } else {
            waitingModels.append(downloadModel)
            downloadState = .waiting
        }
        
        downloadModel.state?(downloadState)
    }
    
    // MARK: - Download Control Methods
    
    public func suspendDownload(of url: URL) {
        suspendDownload(of: url, resumeNext: true)
    }
    
    private func suspendDownload(of url: URL, resumeNext: Bool) {
        guard let downloadModel = downloadModels[fileName(for: url)] else { return }
        
        downloadModel.state?(.suspended)
        
        if waitingModels.contains(downloadModel) {
            if let index = waitingModels.firstIndex(of: downloadModel) {
                waitingModels.remove(at: index)
            }
        } else {
            downloadModel.dataTask?.suspend()
            if let index = downloadingModels.firstIndex(of: downloadModel) {
                downloadingModels.remove(at: index)
            }
        }
        
        if resumeNext {
            resumeNextDownloadModel()
        }
    }
    
    func suspendDownloads() {
        if downloadModels.isEmpty { return }
        
        for downloadModel in downloadModels.values {
            if let url = downloadModel.url {
                suspendDownload(of: url, resumeNext: false)
            }
        }
    }
    
    public func resumeDownload(of url: URL) {
        guard let downloadModel = downloadModels[fileName(for: url)] else { return }
        
        let downloadState: DownloadState
        if canResumeDownload() {
            downloadingModels.append(downloadModel)
            downloadModel.dataTask?.resume()
            downloadState = .running
        } else {
            waitingModels.append(downloadModel)
            downloadState = .waiting
        }
        
        downloadModel.state?(downloadState)
    }
    
    func resumeDownloads() {
        if downloadModels.isEmpty { return }
        
        for downloadModel in downloadModels.values {
            if let url = downloadModel.url {
                resumeDownload(of: url)
            }
        }
    }
    
    public func cancelDownload(of url: URL) {
        cancelDownload(of: url, resumeNext: true)
    }
    
    private func cancelDownload(of url: URL, resumeNext: Bool) {
        guard let downloadModel = downloadModels[fileName(for: url)] else { return }
        
        downloadModel.closeOutputStream()
        downloadModel.dataTask?.cancel()
        
        downloadModel.state?(.canceled)
        
        if waitingModels.contains(downloadModel) {
            if let index = waitingModels.firstIndex(of: downloadModel) {
                waitingModels.remove(at: index)
            }
        } else {
            if let index = downloadingModels.firstIndex(of: downloadModel) {
                downloadingModels.remove(at: index)
            }
        }
        
        downloadModels.removeValue(forKey: fileName(for: url))
        
        if resumeNext {
            resumeNextDownloadModel()
        }
    }
    
    func cancelDownloads() {
        if downloadModels.isEmpty { return }
        
        for downloadModel in downloadModels.values {
            if let url = downloadModel.url {
                cancelDownload(of: url, resumeNext: false)
            }
        }
    }
    
    // MARK: - File Operations
    
    func isDownloadCompleted(of url: URL) -> Bool {
        let totalLength = self.totalLength(url)
        if totalLength == 0 {
            return false
        }
        
        return hasDownloadedLength(url) == totalLength
    }
    
    public func fileFullPath(of url: URL) -> String {
        return filePath(for: url)
    }
    
    public func hasDownloadedProgress(of url: URL) -> CGFloat {
        if isDownloadCompleted(of: url) {
            return 1.0
        }
        
        let total = totalLength(url)
        if total == 0 {
            return 0.0
        }
        
        return CGFloat(hasDownloadedLength(url)) / CGFloat(total)
    }
    
    func deleteFile(of url: URL) {
        cancelDownload(of: url)
        
        filesTotalLengthPlist.removeValue(forKey: fileName(for: url))
        (filesTotalLengthPlist as NSDictionary).write(toFile: filesTotalLengthPlistPath, atomically: true)
        
        let fileManager = FileManager.default
        let filePath = (downloadDirectory as NSString).appendingPathComponent(fileName(for: url))
        
        if fileManager.fileExists(atPath: filePath) {
            try? fileManager.removeItem(atPath: filePath)
        }
    }
    
    func deleteFiles() {
        cancelDownloads()
        
        let fileManager = FileManager.default
        let fileNames = try? fileManager.contentsOfDirectory(atPath: downloadDirectory)
        
        fileNames?.forEach { fileName in
            let filePath = (downloadDirectory as NSString).appendingPathComponent(fileName)
            try? fileManager.removeItem(atPath: filePath)
        }
    }
    
    // MARK: - Helper Methods
    
    private func canResumeDownload() -> Bool {
        if maxConcurrentCount == -1 {
            return true
        }
        
        return downloadingModels.count < maxConcurrentCount
    }
    
    private func totalLength(_ url: URL) -> Int {
        if filesTotalLengthPlist.isEmpty {
            return 0
        }
        
        return (filesTotalLengthPlist[fileName(for: url)] as? Int) ?? 0
    }
    
    private func hasDownloadedLength(_ url: URL) -> Int {
        let fileManager = FileManager.default
        let attributes = try? fileManager.attributesOfItem(atPath: filePath(for: url))
        
        return (attributes?[.size] as? Int) ?? 0
    }
    
    private func resumeNextDownloadModel() {
        if maxConcurrentCount == -1 || waitingModels.isEmpty {
            return
        }
        
        var downloadModel: DownloadModel
        
        switch waitingQueueMode {
        case .fifo:
            downloadModel = waitingModels.first!
        case .lifo:
            downloadModel = waitingModels.last!
        }
        
        if let index = waitingModels.firstIndex(of: downloadModel) {
            waitingModels.remove(at: index)
        }
        
        let downloadState: DownloadState
        if canResumeDownload() {
            downloadingModels.append(downloadModel)
            downloadModel.dataTask?.resume()
            downloadState = .running
        } else {
            waitingModels.append(downloadModel)
            downloadState = .waiting
        }
        
        downloadModel.state?(downloadState)
    }
}

// MARK: - URLSessionDataDelegate

extension DownloadManager: URLSessionDataDelegate {
    
    public func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive response: URLResponse, completionHandler: @escaping (URLSession.ResponseDisposition) -> Void) {
        
        guard let taskDescription = dataTask.taskDescription,
              let downloadModel = downloadModels[taskDescription],
              let url = downloadModel.url else {
            completionHandler(.cancel)
            return
        }
        
        downloadModel.openOutputStream()
        
        let totalLength = response.expectedContentLength + Int64(hasDownloadedLength(url))
        downloadModel.totalLength = Int(totalLength)
        
        filesTotalLengthPlist[fileName(for: url)] = Int(totalLength)
        (filesTotalLengthPlist as NSDictionary).write(toFile: filesTotalLengthPlistPath, atomically: true)
        
        completionHandler(.allow)
    }
    
    public func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive data: Data) {
        guard let taskDescription = dataTask.taskDescription,
              let downloadModel = downloadModels[taskDescription],
              let outputStream = downloadModel.outputStream,
              let url = downloadModel.url else {
            return
        }
        
        let _ = data.withUnsafeBytes { 
            outputStream.write($0.baseAddress!, maxLength: data.count)
        }
        
        DispatchQueue.main.async {
            if let progress = downloadModel.progress {
                let receivedSize = self.hasDownloadedLength(url)
                let expectedSize = downloadModel.totalLength
                
                if expectedSize != 0 {
                    progress(receivedSize, expectedSize, CGFloat(receivedSize) / CGFloat(expectedSize))
                }
            }
        }
    }
    
    public func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        if let error = error as NSError?, error.code == -999 {
            return
        }
        
        guard let taskDescription = task.taskDescription,
              let downloadModel = downloadModels[taskDescription],
              let url = downloadModel.url else {
            return
        }
        
        downloadModel.closeOutputStream()
        downloadModels.removeValue(forKey: taskDescription)
        
        if let index = downloadingModels.firstIndex(of: downloadModel) {
            downloadingModels.remove(at: index)
        }
        
        DispatchQueue.main.async {
            if let error = error {
                downloadModel.state?(.failed)
                downloadModel.completion?(false, nil, error)
            } else {
                if self.isDownloadCompleted(of: url) {
                    let fullPath = self.filePath(for: url)
                    
                    if let destPath = downloadModel.destPath {
                        try? FileManager.default.moveItem(atPath: fullPath, toPath: destPath)
                    }
                    
                    downloadModel.state?(.completed)
                    downloadModel.completion?(true, downloadModel.destPath ?? fullPath, nil)
                } else {
                    let error = NSError(domain: "file download incomplete", code: 0, userInfo: nil)
                    downloadModel.state?(.failed)
                    downloadModel.completion?(false, nil, error)
                }
            }
            
            self.resumeNextDownloadModel()
        }
    }
} 
