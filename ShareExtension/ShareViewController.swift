//
//  ShareViewController.swift
//  ShareExtension
//
//  Created by Sullivan Gu on 2024/12/18.
//

import UIKit
import Social
import MobileCoreServices

class ShareViewController: SLComposeServiceViewController {
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        // Make sure to load shared content and update UI after view did appear, otherwise UI may not work as expected.
        
    }

    override func isContentValid() -> Bool {
        // Do validation of contentText and/or NSExtensionContext attachments here
        return true
    }

    // 处理“发送”操作
    override func didSelectPost() {
            guard let extensionItem = extensionContext?.inputItems.first as? NSExtensionItem else {
                completeRequest()
                return
            }

            guard let attachments = extensionItem.attachments else {
                completeRequest()
                return
            }

            for provider in attachments {
                provider.loadItem(forTypeIdentifier: "org.openxmlformats.spreadsheetml.sheet", options: nil) { (item, error) in
                    if let error = error {
                        print("加载文件失败: \(error.localizedDescription)")
                        self.completeRequest()
                        return
                    }

                    if let url = item as? URL {
                        self.handleSharedXLSXFile(url: url)
                    }
                }
                break // 只处理第一个符合条件的附件
            }

            // 完成分享请求
            self.extensionContext?.completeRequest(returningItems: [], completionHandler: nil)
        }

        // 处理共享的.xlsx文件
        func handleSharedXLSXFile(url: URL) {
            // 使用App Group共享数据
            let appGroupID = "group.shenlv.broker" // 替换为你的App Group ID
            guard let sharedContainer = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupID) else {
                print("无法访问共享容器")
                return
            }

            let destinationURL = sharedContainer.appendingPathComponent(url.lastPathComponent)

            do {
                // 如果目标文件已存在，则先删除
                if FileManager.default.fileExists(atPath: destinationURL.path) {
                    try FileManager.default.removeItem(at: destinationURL)
                }

                // 复制文件到共享容器
                try FileManager.default.copyItem(at: url, to: destinationURL)
                print("文件已复制到共享容器: \(destinationURL.path)")

                // 可以通过UserDefaults、文件触发等方式通知主应用
                // 这里使用UserDefaults（需要在App Group中配置）
                let userDefaults = UserDefaults(suiteName: appGroupID)
                userDefaults?.set(destinationURL.path, forKey: "sharedXLSXFilePath")
                userDefaults?.synchronize()
                
                // 或者使用通知机制（需主应用轮询或其他方式接收通知）

            } catch {
                print("文件复制失败: \(error.localizedDescription)")
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
