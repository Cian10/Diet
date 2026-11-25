import SwiftUI
import DietCore
#if os(iOS)
import PhotosUI
import UIKit
#elseif os(macOS)
import AppKit
import UniformTypeIdentifiers
#endif

@MainActor
public final class PhotoLoggingViewModel: ObservableObject {
    @Published public var originalData: Data?
    @Published public var consumedAt = Date()
    @Published public var mealType: MealType = .other
    @Published public var draft: MealEntry?
    @Published public var isAnalyzing = false
    @Published public var errorMessage: String?

    public let photoService: PhotoLoggingService
    public let foodService: FoodLoggingService

    public init(photoService: PhotoLoggingService, foodService: FoodLoggingService) {
        self.photoService = photoService
        self.foodService = foodService
    }

    public func importImage(using loader: () throws -> Data) {
        do {
            let data = try loader()
            originalData = data
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    public func analyze() async {
        guard let originalData else { errorMessage = FoodLoggingError.missingImage.localizedDescription; return }
        isAnalyzing = true
        defer { isAnalyzing = false }
        do {
            let entry = try draft ?? photoService.createDraft(consumedAt: consumedAt, mealType: mealType)
            draft = entry
            errorMessage = nil
            _ = try await photoService.analyze(
                originalData: originalData,
                consumedAt: consumedAt,
                mealType: mealType,
                existingEntry: entry
            )
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    public func retry() async {
        guard let draft else { return }
        isAnalyzing = true
        defer { isAnalyzing = false }
        do {
            _ = try await photoService.retry(draft)
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

public struct PhotoLoggingView: View {
    @StateObject private var viewModel: PhotoLoggingViewModel
    #if os(iOS)
    @State private var selection: PhotosPickerItem?
    @State private var showCamera = false
    #elseif os(macOS)
    @State private var isFileImporterPresented = false
    #endif
    @State private var isConfirming = false
    public var onConfirmed: () -> Void

    public init(photoService: PhotoLoggingService, foodService: FoodLoggingService, onConfirmed: @escaping () -> Void = {}) {
        _viewModel = StateObject(wrappedValue: PhotoLoggingViewModel(photoService: photoService, foodService: foodService))
        self.onConfirmed = onConfirmed
    }

    public var body: some View {
        Form {
            Section("选择图片") {
                #if os(iOS)
                PhotosPicker(selection: $selection, matching: .images) {
                    Label("从相册选择", systemImage: "photo.on.rectangle")
                }
                if UIImagePickerController.isSourceTypeAvailable(.camera) {
                    Button { showCamera = true } label: {
                        Label("拍摄食物", systemImage: "camera")
                    }
                }
                #elseif os(macOS)
                Button {
                    isFileImporterPresented = true
                } label: {
                    Label("从文件选择图片", systemImage: "folder")
                }
                .disabled(viewModel.isAnalyzing)

                Button {
                    pasteImageFromClipboard()
                } label: {
                    Label("粘贴剪贴板图片", systemImage: "doc.on.clipboard")
                }
                .keyboardShortcut("v", modifiers: .command)
                .help("复制截图或 Finder 图片文件后，也可按 Command-V")
                .disabled(viewModel.isAnalyzing)
                #endif

                if let data = viewModel.originalData {
                    DietImage(data: data)
                        .frame(maxHeight: 280)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
            }
            #if os(iOS)
            .onChange(of: selection) { _, newValue in
                Task {
                    do {
                        viewModel.originalData = try await newValue?.loadTransferable(type: Data.self)
                        viewModel.errorMessage = nil
                    } catch {
                        viewModel.errorMessage = error.localizedDescription
                    }
                }
            }
            #endif

            Section("用餐信息") {
                DatePicker("用餐时间", selection: $viewModel.consumedAt)
                MealTypePicker(selection: $viewModel.mealType)
            }
            Section {
                Button(viewModel.isAnalyzing ? "正在识别…" : "上传并识别") {
                    Task {
                        await viewModel.analyze()
                        if viewModel.draft?.status == .draft { isConfirming = true }
                    }
                }
                .disabled(viewModel.isAnalyzing || viewModel.originalData == nil)
                if viewModel.draft?.status == .failed {
                    Button("使用本地原图重试") {
                        Task {
                            await viewModel.retry()
                            if viewModel.draft?.status == .draft { isConfirming = true }
                        }
                    }
                }
                Button("不识别，手动记录") {
                    do {
                        viewModel.draft = try viewModel.photoService.createDraft(
                            consumedAt: viewModel.consumedAt,
                            mealType: viewModel.mealType
                        )
                        isConfirming = true
                    } catch {
                        viewModel.errorMessage = error.localizedDescription
                    }
                }
            } footer: {
                Text("只有点击“上传并识别”后，图片才会发送给你配置的模型供应商。原图保留在本机，识别结果必须确认后才计入摄入。")
            }
            if let error = viewModel.errorMessage {
                Section("需要处理") {
                    Text(error).foregroundStyle(.red)
                    if viewModel.draft != nil {
                        Button("手动补全识别结果") { isConfirming = true }
                    }
                }
            }
        }
        .navigationTitle("图片记录")
        .navigationDestination(isPresented: $isConfirming) {
            if let draft = viewModel.draft {
                MealConfirmationView(entry: draft, service: viewModel.foodService) {
                    viewModel.draft = nil
                    viewModel.originalData = nil
                    onConfirmed()
                }
            }
        }
        #if os(iOS)
        .sheet(isPresented: $showCamera) {
            CameraPicker { data in
                if let data { viewModel.originalData = data }
                showCamera = false
            }
            .ignoresSafeArea()
        }
        #elseif os(macOS)
        .fileImporter(
            isPresented: $isFileImporterPresented,
            allowedContentTypes: [.image],
            allowsMultipleSelection: false
        ) { result in
            importImageFile(result)
        }
        #endif
    }

    #if os(macOS)
    private func pasteImageFromClipboard() {
        viewModel.importImage {
            try DesktopImageImporter.imageDataFromClipboard()
        }
    }

    private func importImageFile(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            guard let url = urls.first else { return }
            viewModel.importImage {
                try DesktopImageImporter.imageData(fromFile: url)
            }
        case .failure(let error):
            let nsError = error as NSError
            if nsError.domain == NSCocoaErrorDomain && nsError.code == NSUserCancelledError { return }
            viewModel.errorMessage = error.localizedDescription
        }
    }
    #endif
}

private struct DietImage: View {
    let data: Data
    var body: some View {
        #if os(iOS)
        if let image = UIImage(data: data) {
            Image(uiImage: image).resizable().scaledToFit()
        }
        #elseif os(macOS)
        if let image = NSImage(data: data) {
            Image(nsImage: image).resizable().scaledToFit()
        }
        #endif
    }
}

#if os(iOS)
private struct CameraPicker: UIViewControllerRepresentable {
    let completion: (Data?) -> Void

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let controller = UIImagePickerController()
        controller.sourceType = .camera
        controller.delegate = context.coordinator
        return controller
    }

    func updateUIViewController(_ controller: UIImagePickerController, context: Context) {}
    func makeCoordinator() -> Coordinator { Coordinator(completion: completion) }

    final class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let completion: (Data?) -> Void
        init(completion: @escaping (Data?) -> Void) { self.completion = completion }

        func imagePickerController(
            _ picker: UIImagePickerController,
            didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]
        ) {
            let image = info[.originalImage] as? UIImage
            completion(image?.jpegData(compressionQuality: 1))
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) { completion(nil) }
    }
}
#endif
