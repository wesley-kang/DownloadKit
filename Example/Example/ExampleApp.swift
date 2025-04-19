//
//  ExampleApp.swift
//  Example
//
//  Created by hong on 2025/4/7.
//

import SwiftUI
import SwiftData  // 添加 SwiftData 导入

@main
struct ExampleApp: App {
    let container: ModelContainer
    
    init() {
        do {
            container = try ModelContainer(for: DownloadItem.self)
        } catch {
            fatalError("Could not initialize ModelContainer")
        }
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(container)
    }
}