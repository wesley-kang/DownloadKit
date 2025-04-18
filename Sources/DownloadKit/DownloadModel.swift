//
//  DownloadModel.swift
//  DownloadModel
//

import Foundation

public enum DownloadState: Int {
    case waiting
    case running
    case suspended
    case canceled
    case completed
    case failed
}

public typealias StateBlock = (DownloadState) -> Void
public typealias ProgressBlock = (Int, Int, CGFloat) -> Void
public typealias CompletionBlock = (Bool, String?, Error?) -> Void

class DownloadModel: NSObject {
    var outputStream: OutputStream?
    var dataTask: URLSessionDataTask?
    var url: URL?
    var totalLength: Int = 0
    var destPath: String?
    var state: StateBlock?
    var progress: ProgressBlock?
    var completion: CompletionBlock?
    
    func openOutputStream() {
        guard let outputStream = outputStream else { return }
        outputStream.open()
    }
    
    func closeOutputStream() {
        guard let outputStream = outputStream else { return }
        if outputStream.streamStatus.rawValue > Stream.Status.notOpen.rawValue && 
           outputStream.streamStatus.rawValue < Stream.Status.closed.rawValue {
            outputStream.close()
        }
        self.outputStream = nil
    }
} 
