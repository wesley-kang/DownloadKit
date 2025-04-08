//
//  ContentView.swift
//  DownloadKit
//
//  Created by kangheng on 2025/4/8.
//
import SwiftUI
import SwiftData

struct DownloadItem: Identifiable {
    let id = UUID()
    var fileName: String
    var progress: Double
    var status: DownloadStatus
}

enum DownloadStatus {
    case notStarted
    case downloading
    case completed
    case failed
}

struct ContentView: View {
    @State private var downloadItems: [DownloadItem] = [
        DownloadItem(fileName: "示例文件.pdf", progress: 0.0, status: .notStarted)
    ]
    
    var body: some View {
        NavigationStack {
            List {
                ForEach(downloadItems) { item in
                    VStack(alignment: .leading, spacing: 8) {
                        Text(item.fileName)
                            .font(.headline)
                        
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
                    .padding(.vertical, 8)
                }
            }
            .navigationTitle("下载管理")
            .toolbar {
                ToolbarItem {
                    Button(action: addNewDownload) {
                        Label("添加下载", systemImage: "plus")
                    }
                }
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
        }
    }
    
    private func buttonImage(for status: DownloadStatus) -> String {
        switch status {
        case .notStarted:
            return "arrow.down.circle"
        case .downloading:
            return "stop.circle"
        case .completed:
            return "checkmark.circle"
        case .failed:
            return "arrow.clockwise.circle"
        }
    }
    
    private func startDownload(for item: DownloadItem) {
        // 模拟下载过程
        if let index = downloadItems.firstIndex(where: { $0.id == item.id }) {
            downloadItems[index].status = .downloading
            
            // 模拟进度更新
            Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { timer in
                if downloadItems[index].progress < 1.0 {
                    downloadItems[index].progress += 0.01
                } else {
                    downloadItems[index].status = .completed
                    timer.invalidate()
                }
            }
        }
    }
    
    private func addNewDownload() {
        let newItem = DownloadItem(fileName: "新文件.pdf", progress: 0.0, status: .notStarted)
        downloadItems.append(newItem)
    }
}

#Preview {
    ContentView()
}