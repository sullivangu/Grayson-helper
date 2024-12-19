import SwiftUI
import UniformTypeIdentifiers
import CoreXLSX

struct ContentView: View {
    @State private var importedFileURL: URL?
    @State private var processedData: String = ""
    @State private var showingDocumentPicker = false
    
    var body: some View {
        VStack {
            Button("选择 XLSX 文件") {
                showingDocumentPicker = true
            }
            .sheet(isPresented: $showingDocumentPicker) {
                DocumentPicker(processedData: $processedData)
            }
            
            if !processedData.isEmpty {
                Text("已复制到剪切板")
                    .foregroundColor(.green)
            }
        }
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
//            // 创建临时解压目录
//            let tempDirectory = FileManager.default.temporaryDirectory
//            let unzipDirectory = tempDirectory.appendingPathComponent(UUID().uuidString)
//            try FileManager.default.createDirectory(at: unzipDirectory, withIntermediateDirectories: true)
//            
//            // 解压 XLSX 文件（ZIP 格式）
//            try Zip.unzipFile(fileURL, destination: unzipDirectory, overwrite: true, password: nil)
//            
//            // 查找 sheet1.xml 文件
//            let sheetsDirectory = unzipDirectory.appendingPathComponent("xl/worksheets")
//            let sheet1URL = sheetsDirectory.appendingPathComponent("sheet1.xml")
//            
//            // 读取 XML 内容
//            let xmlData = try Data(contentsOf: sheet1URL)
//            
//            // 解析 XML
//            let decoder = XMLDecoder()
//            let worksheet = try decoder.decode(Worksheet.self, from: xmlData)
//            
//            // 提取前 200 行的第一列数据
//            let firstColumnData = worksheet.sheetData.row
//                .prefix(200)
//                .compactMap { row -> String? in
//                    // 获取第一个单元格的值
//                    return row.c.first?.v
//                }
//                .joined(separator: ",")
//            
//            // 清理临时文件
//            try? FileManager.default.removeItem(at: unzipDirectory)
//            print(firstColumnData)
//            return firstColumnData
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


class AppDelegate: NSObject, UIApplicationDelegate {
    let appGroupID = "group.shenlv.broker" // 替换为你的App Group ID

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {
        loadSharedXLSXFile()
        return true
    }
    
    
    func applicationDidBecomeActive(_ application: UIApplication) {
        loadSharedXLSXFile()
    }
    
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
            let file = try XLSXFile(filepath: fileURL.path)

            // 获取工作簿中的所有工作表
            guard let sheets = try file.parseSheets(), let sheet = sheets.first else {
                print("没有找到工作表")
                return
            }

            // 解析该工作表的数据
            guard let rows = try file.parseRows(sheet: sheet) else {
                print("无法解析行数据")
                return
            }

            var firstColumnValues = [String]()

            // 遍历行数据，提取第2行到第100行的第一列数据
            for (index, row) in rows.enumerated() {
                let rowNumber = index + 1  // 行号从1开始

                if rowNumber >= 2 && rowNumber <= 100 {
                    if let firstCell = row.cells.first {
                        // 获取第一列单元格的值
                        if let value = firstCell.value(sharedStrings: try file.parseSharedStrings()) {
                            firstColumnValues.append(value)
                        }
                    }
                }
            }

            // 将所有值通过逗号连接
            let result = firstColumnValues.joined(separator: ",")
                    
            DispatchQueue.main.async {
                // 复制到剪切板
                UIPasteboard.general.string = result
            }
            print("第一列数据: \(result)")

        } catch {
            print("解析文件失败: \(error)")
        }
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
