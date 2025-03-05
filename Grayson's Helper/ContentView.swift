import SwiftUI
import UniformTypeIdentifiers
import CoreXLSX
extension ScenePhase {
    var description: String {
        switch self {
        case .active:
            return "活跃"
        case .inactive:
            return "非活跃"
        case .background:
            return "后台"
        @unknown default:
            return "未知"
        }
    }
}
struct ContentView: View {
    @State private var importedFileURL: URL?
    @State private var processedData: String = "暂无数据"
    @State private var showingDocumentPicker = false
    @State private var message = "等待状态变化..."
    @Environment(\.scenePhase) private var scenePhase  // 监听应用生命周期状态
    var body: some View {
        VStack {
            Text(message)
            
            if !processedData.isEmpty {
                Text(processedData)
                    .foregroundColor(.green)
            }
        }.onChange(of: scenePhase) { newPhase in
            switch newPhase {
            case .active:
                message = "应用已恢复活跃！"
                print("App is active")
                loadSharedXLSXFile()
            case .inactive:
                message = "应用已变为非活跃状态"
                print("App is inactive")
            case .background:
                message = "应用已进入后台"
                print("App is in the background")
            @unknown default:
                message = "未知状态"
                print("Unknown state")
            }
        }
    }
    
    let appGroupID = "group.shenlv.broker" // 替换为你的App Group ID
    func loadSharedXLSXFile() {
        guard let sharedContainer = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupID) else {
            print("无法访问共享容器")
            return
        }

        // 读取共享的文件路径
        let userDefaults = UserDefaults(suiteName: appGroupID)
        if let filePath = userDefaults?.string(forKey: "sharedXLSXFilePath") {
            let fileURL = URL(fileURLWithPath: filePath)

            if FileManager.default.fileExists(atPath: fileURL.path) {
                print("找到共享的.xlsx文件: \(fileURL.path)")
                parseXlsxAndGetFirstColumn(fileURL: fileURL)
            } else {
                print("指定路径下不存在文件")
            }
        } else {
            print("没有共享的.xlsx文件路径")
        }
    }
    

    func parseXlsxAndGetFirstColumn(fileURL: URL) {
        do {
            // 打开并解析.xlsx文件
            let filepath = fileURL.path
            guard let file = XLSXFile(filepath: fileURL.path) else {
              fatalError("XLSX file at \(filepath) is corrupted or does not exist")
            }
            guard let sharedStrings = try file.parseSharedStrings() else {
                print("解析共享字符串失败")
                return
            }
            var firstColumnValues = [String]()

            for wbk in try file.parseWorkbooks() {
              for (name, path) in try file.parseWorksheetPathsAndNames(workbook: wbk) {
                if let worksheetName = name {
                  print("This worksheet has a name: \(worksheetName)")
                }
                let worksheet = try file.parseWorksheet(at: path)
                  var counter = 0 // 初始化计数器
                for row in worksheet.data?.rows ?? [] {
                    if counter < 50 && counter != 0 {
                        if let c = row.cells.first, let str = c.stringValue(sharedStrings){
                            let fixedStr = fixWord(str)
                            firstColumnValues.append(fixedStr)
                            firstColumnValues.append(str)
                        }
                    }
                    counter += 1
                }
              }
            }

            // 将所有值通过逗号连接
            let result = firstColumnValues.joined(separator: ",")
            processedData = result
            DispatchQueue.main.async {
                // 复制到剪切板
                UIPasteboard.general.string = result
            }
            print("第一列数据: \(result)")
            
        } catch {
            print("解析文件失败: \(error)")
        }
    }
      
    
    // 拼写修正方法
    func correctSpelling(of word: String) -> String {
        let checker = UITextChecker()
        let range = NSRange(location: 0, length: word.utf16.count)
        let misspelledRange = checker.rangeOfMisspelledWord(in: word, range: range, startingAt: 0, wrap: false, language: "en_US")
        
        if misspelledRange.location != NSNotFound {
            let guesses = checker.guesses(forWordRange: misspelledRange, in: word, language: "en_US") ?? []
            if let suggestion = guesses.first {
                return suggestion // 使用第一个修正建议
            }
        }
        
        return word // 如果没有拼写错误，直接返回原单词
    }

    // 单复数转换方法（简单示例）
    func correctPlurality(of word: String) -> String {
        // 如果是复数形式且以 "es" 结尾，尝试转为单数
        if word.hasSuffix("es") {
            let singular = word.dropLast(2) // 移除 "es"
            return String(singular)
        }
        
        // 如果是复数形式且以 "s" 结尾，尝试转为单数
        if word.hasSuffix("s") {
            let singular = word.dropLast() // 移除 "s"
            return String(singular)
        }

        // 如果已经是单数形式，返回原词
        return word
    }

    // 大小写修正方法
    func correctCase(of word: String) -> String {
        // 修正为首字母大写，其余小写
        return word.capitalized
    }

    // 综合修复方法
    func fixWord(_ word: String) -> String {
        var correctedWord = correctSpelling(of: word) // 修复拼写错误
//        correctedWord = correctPlurality(of: correctedWord) // 修复单复数
//        correctedWord = correctCase(of: correctedWord) // 修复大小写
        return correctedWord
    }
    
    private func application(_ application: UIApplication, open url: URL, options: [UIApplication.OpenExternalURLOptionsKey : Any] = [:]) -> Bool {
           // 处理共享的文件 URL
           handleSharedFile(url)
           return true
       }
       
       // 处理文件 URL
       func handleSharedFile(_ url: URL) {
           // 在这里根据需要处理文件，例如将文件保存到本地，读取内容等
           print("接收到文件: \(url.absoluteString)")
       }
    
}

extension UTType {

    static let doc: Self = .init(filenameExtension: "doc")!
    static let docx: Self = .init(filenameExtension: "docx")!

    static let xls: Self = .init(filenameExtension: "xls")!
    static let xlsx: Self = .init(filenameExtension: "xlsx")!

    static let ppt: Self = .init(filenameExtension: "ppt")!
    static let pptx: Self = .init(filenameExtension: "pptx")!

}

struct DocumentPicker: UIViewControllerRepresentable {
    @Binding var processedData: String
    @Environment(\.presentationMode) var presentationMode
    
    func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
        let documentPicker = UIDocumentPickerViewController(
            forOpeningContentTypes: [.xlsx, .xls],
            asCopy: false
        )
        documentPicker.delegate = context.coordinator
        return documentPicker
    }
    
    func updateUIViewController(_ uiViewController: UIDocumentPickerViewController, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, UIDocumentPickerDelegate {
        var parent: DocumentPicker
        
        init(_ parent: DocumentPicker) {
            self.parent = parent
        }
        
        func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
            guard let fileURL = urls.first else { return }
            proceed(fileURL)
        }
        
        func proceed(_ fileURL:URL) {
            // 将文件复制到应用沙盒
            let documentsDirectory = FileManager.default.urls(
                for: .documentDirectory,
                in: .userDomainMask
            ).first!
            
            let destinationURL = documentsDirectory.appendingPathComponent(fileURL.lastPathComponent)
            
            do {
                try FileManager.default.copyItem(at: fileURL, to: destinationURL)
                let processedData = try processExcelFile(destinationURL)
                
                DispatchQueue.main.async {
                    // 复制到剪切板
                    UIPasteboard.general.string = processedData
                    self.parent.processedData = processedData
                    self.parent.presentationMode.wrappedValue.dismiss()
                }
            } catch {
                print("文件处理失败: \(error)")
            }
        }
        
        func processExcelFile(_ fileURL: URL) throws -> String {
            return ""
        }
    }
}

// XML 解码结构体
struct Worksheet: Codable {
    let sheetData: SheetData
}

struct SheetData: Codable {
    let row: [RowData]
}

struct RowData: Codable {
    let c: [CellData]
}

struct CellData: Codable {
    let v: String?
}
