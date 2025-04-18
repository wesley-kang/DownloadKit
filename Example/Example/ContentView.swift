//
//  ContentView.swift
//  DownloadKit
//
//  Created by kangheng on 2025/4/8.
//
import SwiftUI
import SwiftData
import DownloadKit
struct DownloadItem: Identifiable {
    let id = UUID()
    var fileName: String
    var srcUrl: String
    var destPath: String
    var progress: Double
    var status: DownloadStatus
    var coverUrl: String
    var taskName: String
}

enum DownloadStatus {
    case notStarted
    case downloading
    case completed
    case failed
    case suspended
    case waiting
    case canceled
}

struct ContentView: View {
    @State private var downloadItems: [DownloadItem] = []
    @State private var isShowingURLInput = false
    @State private var inputURL = ""
    @State private var inputCoverURL = ""
    @State private var inputTaskName = ""
    
    var body: some View {
        NavigationStack {
            List {
               ForEach(downloadItems) { item in
                    HStack(spacing: 12) {
                        AsyncImage(url: URL(string: item.coverUrl)) { image in
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                        } placeholder: {
                            Image(systemName: "photo")
                                .foregroundColor(.gray)
                        }
                        .frame(width: 60, height: 60)
                        .cornerRadius(6)
                        .clipped()
                        
                        VStack(alignment: .leading, spacing: 8) {
                            Text(item.taskName)
                                .font(.headline)
                            Text(item.srcUrl)
                                .font(.caption)
                                .foregroundColor(.gray)
                                .lineLimit(1)
                            ProgressView(value: item.progress, total: 1.0)
                                .tint(.blue)
                            
                            HStack {
                                Text(statusText(for: item.status))
                                    .foregroundColor(.secondary)
                                
                                Spacer()
                                
                                Button(action: {
                                    startDownload(for: item)
                                }) {
                                    Image(systemName: buttonImage(for: item.status))
                                }
                            }
                        }
                    }
                    .padding(.vertical, 8)
                    .contextMenu {
                        Button(role: .destructive) {
                            deleteDownload(item)
                        } label: {
                            Label("删除文件", systemImage: "trash")
                        }
                    }
                }
            }
            .navigationTitle("下载管理")
            .toolbar {
                ToolbarItem {
                    Button(action: {
                        isShowingURLInput = true
                    }) {
                        Label("添加下载", systemImage: "plus")
                    }
                }
            }
            .alert("添加下载", isPresented: $isShowingURLInput) {
                TextField("任务名称", text: $inputTaskName)
                TextField("下载链接", text: $inputURL)
                TextField("封面链接", text: $inputCoverURL)
                Button("取消", role: .cancel) {
                    inputURL = ""
                }
                Button("确定") {
                    if !inputURL.isEmpty {
                        addNewDownload(with: inputURL)
                    }
                    inputURL = ""
                }
            } message: {
                 Text("请输入下载任务信息")
            }

        }
    }
    // 添加删除功能函数
    private func deleteDownload(_ item: DownloadItem) {
        // 删除本地文件
        if FileManager.default.fileExists(atPath: item.destPath) {
            do {
                print("删除文件: \(item.destPath)")
                try FileManager.default.removeItem(atPath: item.destPath)
                 // 更新状态为已删除
                if let index = downloadItems.firstIndex(where: { $0.id == item.id }) {
                    downloadItems[index].status = .notStarted
                    downloadItems[index].progress = 0.0
                }
            } catch {
                print("删除文件失败: \(error)")
            }
        }else{
            print("文件不存在: \(item.destPath)")
            if let index = downloadItems.firstIndex(where: { $0.id == item.id }) {
            downloadItems[index].status = .canceled
            downloadItems[index].progress = 0.0
        }
        }
    }
    private func statusText(for status: DownloadStatus) -> String {
        switch status {
        case .notStarted:
            return "等待下载"
        case .downloading:
            return "下载中..."
        case .completed:
            return "已完成"
        case .failed:
            return "下载失败"
        case .suspended:
            return "停止下载"
        case .waiting:
            return "等待下载"
        case .canceled:
            return "取消下载"
        }
    }
    
    private func buttonImage(for status: DownloadStatus) -> String {
        switch status {
        case .notStarted:
            return "arrow.down.circle"
        case .downloading:
             return "arrow.down.circle.fill" // 修改为实心下载
        case .completed:
            return "checkmark.circle"
        case .failed:
            return "arrow.clockwise.circle"
        case .suspended:
            return "stop.circle"
        case .waiting:
            return "arrow.down.circle"
        case .canceled:
            return "xmark.circle"
        }
    }
    
    private func startDownload(for item: DownloadItem) {
        if let index = downloadItems.firstIndex(where: { $0.id == item.id }) {
            guard let url = URL(string: downloadItems[index].srcUrl) else {
                downloadItems[index].status = .failed
                return
            }
            print(downloadItems[index].status)
            // 如果正在下载，则暂停
            if downloadItems[index].status == .downloading {
                DownloadManager.shared.suspendDownload(of: url)
                downloadItems[index].status = .suspended
                return
            }
              // 如果是暂停状态，则恢复下载
            if downloadItems[index].status == .suspended {
                DownloadManager.shared.resumeDownload(of: url)
                downloadItems[index].status = .downloading
                return
            }
            downloadItems[index].status = .downloading
            DownloadManager.shared.download(url: url, destPath: item.destPath){ state in
                        print("\(state)")
                        // 根据下载状态更新 UI
                        switch state {
                        case DownloadState.running:
                            downloadItems[index].status = .downloading
                        case DownloadState.completed:
                            downloadItems[index].status = .completed
                        case DownloadState.failed:
                            downloadItems[index].status = .failed
                        case DownloadState.suspended:
                            downloadItems[index].status = .suspended
                        case DownloadState.waiting:
                            downloadItems[index].status = .waiting
                        case DownloadState.canceled:
                            downloadItems[index].status = .canceled
                        }
            
                    } progress: { currentSize, totalSize, percent in
                        downloadItems[index].progress = percent
                        print(percent, currentSize, totalSize)
                    } completion: { isFinished, filePath, error in
                        if(error != nil){
                            downloadItems[index].status = .failed
                            return
                        }
                        downloadItems[index].progress = 1.0
                        downloadItems[index].status = .completed
                        downloadItems[index].destPath = filePath!
                    }
        }
        
         
    }
    private func resetInputFields() {
        inputURL = ""
        inputCoverURL = ""
        inputTaskName = ""
    }
    private func addNewDownload(with urlString: String) {
        // https://github.com/BBC6BAE9/video/raw/refs/heads/master/Shogun.S01E01.2024.2160p.DSNP.WEB-DL.DDP5.1.DV.HDR.H.265-HHWEB.mp4
        guard let sourceURL = URL(string: urlString) else { return }
        let fileName = sourceURL.lastPathComponent
         // 获取 Documents 目录路径
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let destPath = documentsPath.appendingPathComponent(fileName).path
        let newItem = DownloadItem(fileName: fileName,
                                 srcUrl: urlString,
                                 destPath: destPath,
                                 progress: 0.0,
                                 status: .notStarted,
                                 coverUrl: inputCoverURL,
                                 taskName: inputTaskName)
        downloadItems.append(newItem)
    }
}

#Preview {
    ContentView()
}
