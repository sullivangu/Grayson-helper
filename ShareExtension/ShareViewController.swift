//
//  ShareViewController.swift
//  ShareExtension
//
//  Created by Sullivan Gu on 2024/12/18.
//

import UIKit
import Social
import MobileCoreServices
import UserNotifications

class ShareViewController: SLComposeServiceViewController {
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        // Make sure to load shared content and update UI after view did appear, otherwise UI may not work as expected.
        
    }

    override func isContentValid() -> Bool {
        // Do validation of contentText and/or NSExtensionContext attachments here
        return true
    }

    // 处理"发送"操作
    override func didSelectPost() {
            print("=== didSelectPost 开始执行 ===")
            
            guard let extensionItem = extensionContext?.inputItems.first as? NSExtensionItem else {
                print("❌ 没有找到 extensionItem")
                completeRequest()
                return
            }
            print("✅ 找到 extensionItem")

            guard let attachments = extensionItem.attachments else {
                print("❌ 没有找到 attachments")
                completeRequest()
                return
            }
            print("✅ 找到 \(attachments.count) 个附件")

            for (index, provider) in attachments.enumerated() {
                print("🔍 处理第 \(index + 1) 个附件")
                print("📋 支持的类型: \(provider.registeredTypeIdentifiers)")
                
                provider.loadItem(forTypeIdentifier: "org.openxmlformats.spreadsheetml.sheet", options: nil) { (item, error) in
                    print("📁 loadItem 回调执行")
                    
                    if let error = error {
                        print("❌ 加载文件失败: \(error.localizedDescription)")
                        self.completeRequest()
                        return
                    }

                    if let url = item as? URL {
                        print("✅ 获得文件URL: \(url)")
                        self.handleSharedXLSXFile(url: url)
                        
                        // 文件处理完成后再唤起主应用
                        DispatchQueue.main.async {
                            print("🚀 准备唤起主应用")
                            self.openMainApp()
                        }
                    } else {
                        print("❌ item 不是 URL 类型: \(type(of: item))")
                        self.completeRequest()
                    }
                }
                break // 只处理第一个符合条件的附件
            }
        }
    
    // 单独的唤起主应用方法
    private func openMainApp() {
        print("📱 开始唤起主应用流程")
        
        // 直接发送通知，这是最可靠的方式
        self.sendNotificationToOpenApp()
        
        // 同时尝试URL Scheme（可选）
        if let url = URL(string: "helpGrayson://parse/wordlist") {
            print("🔗 尝试URL Scheme: \(url)")
            self.extensionContext?.open(url) { success in
                print("🔗 URL Scheme结果: \(success)")
            }
        }
        
        // 延迟完成请求，给通知发送时间
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            print("✅ 完成ShareExtension请求")
            self.completeRequest()
        }
    }
    
    // 发送通知提醒用户打开主应用
    private func sendNotificationToOpenApp() {
        print("📢 准备发送通知")
        
        let content = UNMutableNotificationContent()
        content.title = "Excel文件已处理完成"
        content.body = "点击打开Grayson's Helper查看处理结果"
        content.sound = .default
        content.categoryIdentifier = "OPEN_APP_CATEGORY"
        
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 0.1, repeats: false)
        let request = UNNotificationRequest(identifier: "ExcelProcessed", content: content, trigger: trigger)
        
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("❌ 发送通知失败: \(error.localizedDescription)")
            } else {
                print("✅ 通知已成功发送")
            }
        }
    }

        // 处理共享的.xlsx文件
        func handleSharedXLSXFile(url: URL) {
            print("🏠 开始处理共享文件: \(url.lastPathComponent)")
            
            // 使用App Group共享数据
            let appGroupID = "group.shenlv.broker" // 替换为你的App Group ID
            guard let sharedContainer = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupID) else {
                print("❌ 无法访问共享容器")
                return
            }
            print("✅ 共享容器路径: \(sharedContainer.path)")

            let destinationURL = sharedContainer.appendingPathComponent(url.lastPathComponent)
            print("📂 目标文件路径: \(destinationURL.path)")

            do {
                // 如果目标文件已存在，则先删除
                if FileManager.default.fileExists(atPath: destinationURL.path) {
                    try FileManager.default.removeItem(at: destinationURL)
                    print("🗑️ 已删除已存在的文件")
                }

                // 复制文件到共享容器
                try FileManager.default.copyItem(at: url, to: destinationURL)
                print("✅ 文件已复制到共享容器: \(destinationURL.path)")

                // 通过UserDefaults通知主应用
                let userDefaults = UserDefaults(suiteName: appGroupID)
                userDefaults?.set(destinationURL.path, forKey: "sharedXLSXFilePath")
                userDefaults?.synchronize()
                print("✅ UserDefaults 已更新")

            } catch {
                print("❌ 文件复制失败: \(error.localizedDescription)")
            }
        }


    // 完成请求
    func completeRequest() {
        self.extensionContext?.completeRequest(returningItems: [], completionHandler: nil)
    }

    override func configurationItems() -> [Any]! {
        // To add configuration options via table cells at the bottom of the sheet, return an array of SLComposeSheetConfigurationItem here.
        return []
    }

    
}
