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
    var body: some View {
        TabView {
            ProcessingView()
                .tabItem {
                    Image(systemName: "doc.text")
                    Text("处理")
                }
            
            CleanupView()
                .tabItem {
                    Image(systemName: "trash")
                    Text("清理")
                }
        }
    }
}

struct WordPair {
    let original: String
    let corrected: String
    let dictionaryForm: String
}

struct ProcessingView: View {
    @State private var importedFileURL: URL?
    @State private var processedData: String = "暂无数据"
    @State private var wordPairs: [WordPair] = []
    @State private var showingDocumentPicker = false
    @State private var message = "等待状态变化..."
    @State private var showToast = false
    @State private var toastMessage = ""
    @Environment(\.scenePhase) private var scenePhase  // 监听应用生命周期状态
    
    var body: some View {
        NavigationView {
            VStack {
                Text(message)
                    .padding()
                
                if !wordPairs.isEmpty {
                    List(wordPairs.indices, id: \.self) { index in
                        let pair = wordPairs[index]
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text("原始:")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                Spacer()
                            }
                            Text(pair.original)
                                .font(.body)
                                .foregroundColor(.primary)
                            
                            HStack {
                                Text("修正:")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                Spacer()
                            }
                            Text(pair.corrected)
                                .font(.body)
                                .foregroundColor(.green)
                                .fontWeight(.medium)
                            
                            HStack {
                                Text("字典形式:")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                Spacer()
                            }
                            Text(pair.dictionaryForm)
                                .font(.body)
                                .foregroundColor(.blue)
                                .fontWeight(.medium)
                        }
                        .padding(.vertical, 4)
                    }
                } else if processedData != "暂无数据" {
                    Text(processedData)
                        .foregroundColor(.green)
                        .padding()
                }
            }
            .navigationTitle("Grayson's Helper")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        copyToClipboard()
                    }) {
                        Image(systemName: "doc.on.clipboard")
                            .foregroundColor(.blue)
                    }
                    .disabled(wordPairs.isEmpty)
                }
            }
            .overlay(
                // Toast notification
                VStack {
                    Spacer()
                    if showToast {
                        HStack {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.white)
                            Text(toastMessage)
                                .foregroundColor(.white)
                                .font(.system(size: 14, weight: .medium))
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        .background(Color.black.opacity(0.8))
                        .cornerRadius(25)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                        .onAppear {
                            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                                withAnimation(.easeOut(duration: 0.3)) {
                                    showToast = false
                                }
                            }
                        }
                    }
                }
                .padding(.bottom, 100)
                .animation(.easeInOut(duration: 0.3), value: showToast)
            )
        }
        .onOpenURL { url in
            print("收到URL: \(url)")
            // 当通过URL Scheme唤起时，立即加载共享文件
            loadSharedXLSXFile()
        }
        .onChange(of: scenePhase) { oldPhase, newPhase in
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
    
    func copyToClipboard() {
        // 创建包含原始单词和字典形式的数组
        var allWords: [String] = []
        
        for pair in wordPairs {
            allWords.append(pair.original)      // 添加原始单词
            allWords.append(pair.dictionaryForm) // 添加字典形式
        }
        
        let result = allWords.joined(separator: ",")
        UIPasteboard.general.string = result
        
        // 显示toast提示
        toastMessage = "已复制到剪贴板"
        withAnimation(.easeInOut(duration: 0.3)) {
            showToast = true
        }
        
        print("已复制到剪贴板: \(result)")
    }
    
    let appGroupID = "group.shenlv.broker"
    func loadSharedXLSXFile() {
        guard FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupID) != nil else {
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
            var pairs = [WordPair]()

            for wbk in try file.parseWorkbooks() {
              for (name, path) in try file.parseWorksheetPathsAndNames(workbook: wbk) {
                if let worksheetName = name {
                  print("This worksheet has a name: \(worksheetName)")
                }
                let worksheet = try file.parseWorksheet(at: path)
                  var counter = 0 // 初始化计数器
                for row in worksheet.data?.rows ?? [] {
                    if counter < 100 && counter != 0 {
                        if let c = row.cells.first, let str = c.stringValue(sharedStrings){
                            let fixedStr = fixWord(str)
                            let dictionaryStr = createDictionaryForm(str)
                            pairs.append(WordPair(original: str, corrected: fixedStr, dictionaryForm: dictionaryStr))
                        }
                    }
                    counter += 1
                }
              }
            }

            DispatchQueue.main.async {
                self.wordPairs = pairs
                let correctedWords = pairs.map { $0.corrected }
                let result = correctedWords.joined(separator: ",")
                self.processedData = result
                // 自动复制到剪切板
                UIPasteboard.general.string = result
            }
            print("处理了 \(pairs.count) 个单词")
            
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

    // 单复数转换方法（增强版）
    func correctPlurality(of word: String) -> String {
        let lowercased = word.lowercased()
        
        // 不规则复数形式
        let irregularPlurals = [
            "children": "child",
            "feet": "foot",
            "teeth": "tooth",
            "mice": "mouse",
            "geese": "goose",
            "men": "man",
            "women": "woman",
            "people": "person",
            "oxen": "ox"
        ]
        
        if let singular = irregularPlurals[lowercased] {
            return restoreOriginalCase(original: word, transformed: singular)
        }
        
        // 以 "ies" 结尾的单词，替换为 "y"
        if lowercased.hasSuffix("ies") && lowercased.count > 3 {
            let base = String(lowercased.dropLast(3))
            let singular = base + "y"
            return restoreOriginalCase(original: word, transformed: singular)
        }
        
        // 以 "ves" 结尾的单词，替换为 "f" 或 "fe"
        if lowercased.hasSuffix("ves") {
            let base = String(lowercased.dropLast(3))
            let singular = base + "f"
            return restoreOriginalCase(original: word, transformed: singular)
        }
        
        // 以 "ses", "ches", "shes", "xes", "zes" 结尾的单词，移除 "es"
        if lowercased.hasSuffix("ses") || lowercased.hasSuffix("ches") || 
           lowercased.hasSuffix("shes") || lowercased.hasSuffix("xes") || 
           lowercased.hasSuffix("zes") {
            let singular = String(lowercased.dropLast(2))
            return restoreOriginalCase(original: word, transformed: singular)
        }
        
        // 一般情况：以 "s" 结尾的单词，移除 "s"
        if lowercased.hasSuffix("s") && lowercased.count > 1 {
            let singular = String(lowercased.dropLast())
            return restoreOriginalCase(original: word, transformed: singular)
        }

        return word
    }
    
    // 动词时态转换方法
    func correctVerbTense(of word: String) -> String {
        let lowercased = word.lowercased()
        
        // 不规则动词过去式和过去分词
        let irregularVerbs = [
            "was": "be", "were": "be", "been": "be",
            "had": "have", "has": "have",
            "did": "do", "done": "do", "does": "do",
            "went": "go", "gone": "go", "goes": "go",
            "came": "come", "comes": "come",
            "took": "take", "taken": "take", "takes": "take",
            "saw": "see", "seen": "see", "sees": "see",
            "made": "make", "makes": "make",
            "got": "get", "gotten": "get", "gets": "get",
            "gave": "give", "given": "give", "gives": "give",
            "knew": "know", "known": "know", "knows": "know",
            "thought": "think", "thinks": "think",
            "said": "say", "says": "say",
            "told": "tell", "tells": "tell",
            "found": "find", "finds": "find",
            "left": "leave", "leaves": "leave",
            "felt": "feel", "feels": "feel",
            "kept": "keep", "keeps": "keep",
            "meant": "mean", "means": "mean",
            "brought": "bring", "brings": "bring",
            "built": "build", "builds": "build",
            "bought": "buy", "buys": "buy",
            "caught": "catch", "catches": "catch",
            "taught": "teach", "teaches": "teach",
            "fought": "fight", "fights": "fight",
            "sought": "seek", "seeks": "seek",
            "ran": "run", "runs": "run",
            "won": "win", "wins": "win",
            "began": "begin", "begins": "begin",
            "drank": "drink", "drinks": "drink",
            "sang": "sing", "sings": "sing",
            "swam": "swim", "swims": "swim",
            "rang": "ring", "rings": "ring"
        ]
        
        if let baseForm = irregularVerbs[lowercased] {
            return restoreOriginalCase(original: word, transformed: baseForm)
        }
        
        // 处理规则动词
        // 以 "ied" 结尾，替换为 "y"
        if lowercased.hasSuffix("ied") && lowercased.count > 3 {
            let base = String(lowercased.dropLast(3))
            let baseForm = base + "y"
            return restoreOriginalCase(original: word, transformed: baseForm)
        }
        
        // 以 "ed" 结尾的过去式，移除 "ed"
        if lowercased.hasSuffix("ed") && lowercased.count > 2 {
            let baseForm = String(lowercased.dropLast(2))
            return restoreOriginalCase(original: word, transformed: baseForm)
        }
        
        // 以 "ing" 结尾的进行时，移除 "ing"
        if lowercased.hasSuffix("ing") && lowercased.count > 3 {
            let baseForm = String(lowercased.dropLast(3))
            return restoreOriginalCase(original: word, transformed: baseForm)
        }
        
        // 第三人称单数现在时，以 "s" 结尾
        if lowercased.hasSuffix("s") && lowercased.count > 1 {
            let baseForm = String(lowercased.dropLast())
            return restoreOriginalCase(original: word, transformed: baseForm)
        }
        
        return word
    }
    
    // 恢复原始大小写格式
    func restoreOriginalCase(original: String, transformed: String) -> String {
        guard !original.isEmpty && !transformed.isEmpty else { return transformed }
        
        if original.first?.isUppercase == true {
            return transformed.prefix(1).uppercased() + transformed.dropFirst().lowercased()
        } else if original == original.uppercased() {
            return transformed.uppercased()
        } else {
            return transformed.lowercased()
        }
    }

    // 大小写修正方法
    func correctCase(of word: String) -> String {
        // 修正为首字母大写，其余小写
        return word.capitalized
    }

    // 综合修复方法 - 返回拼写修正后的单词
    func fixWord(_ word: String) -> String {
        let correctedWord = correctSpelling(of: word) // 修复拼写错误
        return correctedWord
    }
    
    // 创建字典形式的单词（去掉单复数和时态）
    func createDictionaryForm(_ word: String) -> String {
        var dictionaryWord = correctSpelling(of: word) // 先修正拼写
        dictionaryWord = correctPlurality(of: dictionaryWord) // 转为单数
        dictionaryWord = correctVerbTense(of: dictionaryWord) // 转为动词原形
        dictionaryWord = dictionaryWord.lowercased() // 转为小写
        return dictionaryWord
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

struct CleanupView: View {
    @State private var isClearing = false
    @State private var message = "点击按钮清理所有缓存文件"
    @State private var fileCount = 0
    
    let appGroupID = "group.shenlv.broker"
    
    var body: some View {
        VStack(spacing: 20) {
            Text("文件清理")
                .font(.largeTitle)
                .fontWeight(.bold)
            
            Text(message)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            
            if fileCount > 0 {
                Text("发现 \(fileCount) 个缓存文件")
                    .foregroundColor(.orange)
            }
            
            Button(action: {
                clearCacheFiles()
            }) {
                HStack {
                    if isClearing {
                        ProgressView()
                            .scaleEffect(0.8)
                    }
                    Image(systemName: "trash.fill")
                    Text(isClearing ? "清理中..." : "清理缓存")
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.red)
                .foregroundColor(.white)
                .cornerRadius(10)
            }
            .disabled(isClearing)
            .padding(.horizontal)
            
            Button(action: {
                refreshFileCount()
            }) {
                HStack {
                    Image(systemName: "arrow.clockwise")
                    Text("刷新文件统计")
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.blue)
                .foregroundColor(.white)
                .cornerRadius(10)
            }
            .padding(.horizontal)
        }
        .padding()
        .onAppear {
            refreshFileCount()
        }
    }
    
    func refreshFileCount() {
        guard let sharedContainer = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupID) else {
            message = "无法访问共享容器"
            return
        }
        
        do {
            let files = try FileManager.default.contentsOfDirectory(at: sharedContainer, includingPropertiesForKeys: nil)
            let xlsxFiles = files.filter { $0.pathExtension.lowercased() == "xlsx" || $0.pathExtension.lowercased() == "xls" }
            fileCount = xlsxFiles.count
            
            if fileCount == 0 {
                message = "没有发现缓存文件"
            } else {
                message = "发现 \(fileCount) 个Excel缓存文件"
            }
        } catch {
            message = "检查文件失败: \(error.localizedDescription)"
            fileCount = 0
        }
    }
    
    func clearCacheFiles() {
        guard !isClearing else { return }
        isClearing = true
        
        guard let sharedContainer = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupID) else {
            message = "无法访问共享容器"
            isClearing = false
            return
        }
        
        DispatchQueue.global(qos: .userInitiated).async {
            var deletedCount = 0
            
            do {
                let files = try FileManager.default.contentsOfDirectory(at: sharedContainer, includingPropertiesForKeys: nil)
                let xlsxFiles = files.filter { $0.pathExtension.lowercased() == "xlsx" || $0.pathExtension.lowercased() == "xls" }
                
                for file in xlsxFiles {
                    try FileManager.default.removeItem(at: file)
                    deletedCount += 1
                    print("已删除文件: \(file.lastPathComponent)")
                }
                
                // 清除UserDefaults中的文件路径记录
                let userDefaults = UserDefaults(suiteName: appGroupID)
                userDefaults?.removeObject(forKey: "sharedXLSXFilePath")
                userDefaults?.synchronize()
                
                DispatchQueue.main.async {
                    self.message = "成功清理 \(deletedCount) 个文件"
                    self.fileCount = 0
                    self.isClearing = false
                }
                
            } catch {
                DispatchQueue.main.async {
                    self.message = "清理失败: \(error.localizedDescription)"
                    self.isClearing = false
                }
            }
        }
    }
}
