//
//  Grayson_s_HelperApp.swift
//  Grayson's Helper
//
//  Created by Sullivan Gu on 2024/12/18.
//

import SwiftUI
import CoreXLSX

@main
struct Grayson_s_HelperApp: App {
    @Environment(\.scenePhase) private var scenePhase
    var body: some Scene {
        WindowGroup {
            ContentView()
                .onChange(of: scenePhase) {  oldPhase, newPhase in
                                    switch newPhase {
                                    case .active:
                                        print("App is active")
                                        self.sendLocalNotification()
                                    case .inactive:
                                        print("App is inactive")
                                    case .background:
                                        print("App is in the background")
                                    @unknown default:
                                        print("Unknown state")
                                    }
                                
            }
        }
    }
    
    func sendLocalNotification() {
           let content = UNMutableNotificationContent()
           content.title = "应用已恢复活跃"
           content.body = "您的应用现在是活跃状态，可以继续使用！"
           content.sound = .default
           
           // 创建一个触发条件
           let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
           
           // 创建通知请求
           let request = UNNotificationRequest(identifier: "AppActiveNotification", content: content, trigger: trigger)
           
           // 将通知请求添加到通知中心
           UNUserNotificationCenter.current().add(request) { error in
               if let error = error {
                   print("Error adding notification: \(error.localizedDescription)")
               }
           }
       }
}
