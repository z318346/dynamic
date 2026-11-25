import SwiftUI
import UIKit
import UniformTypeIdentifiers
import PassKit
#if canImport(FoundationModels)
import FoundationModels
#endif

struct AdvancedTools: View {
    let vi: Bool
    func tr(_ a: String, _ b: String) -> String { vi ? a : b }
    var body: some View {
        List {
            Section("Demo Lab") {
                NavigationLink { DeviceDemoLab(vi: vi) } label: {
                    Label(tr("Thử cấu hình iPhone (mô phỏng)", "Try iPhone profile (simulation)"), systemImage: "slider.horizontal.3")
                }
                Text(tr("Chỉ lưu cấu hình thử nghiệm trong app. Không can thiệp iOS.", "Stores simulated settings in the app only. No system modifications.")).font(.caption).foregroundStyle(.secondary)
            }
            Section(tr("Thiết bị thực tế", "Current device")) {
                LabeledContent("iOS", value: UIDevice.current.systemVersion)
                LabeledContent(tr("Mã phần cứng", "Hardware identifier"), value: hardwareID)
                NavigationLink { LayoutLab(vi: vi) } label: { Label(tr("Bố cục Dynamic Island", "Island layouts"), systemImage: "capsule") }
                Text(tr("Chọn mẫu để xem trước; không đổi nhận dạng hệ thống.", "Select a preview; system identity is unchanged.")).font(.caption).foregroundStyle(.secondary)
            }
            Section(tr("Trí tuệ nhân tạo", "Intelligence")) {
                #if canImport(FoundationModels)
                if #available(iOS 26, *) {
                    NavigationLink { LocalIntelligence(vi: vi) } label: { Label("Apple Intelligence", systemImage: "sparkles") }
                } else {
                    Text(tr("AI trong ứng dụng yêu cầu iOS 26 trở lên.", "In-app AI requires iOS 26 or later."))
                }
                #endif
                Link(destination: URL(string: "https://support.apple.com/en-vn/127893")!) {
                    Label("Siri AI", systemImage: "waveform")
                }
                Text(tr("Không thay đổi hoặc mở khóa Siri hệ thống.", "Does not modify or unlock system Siri.")).font(.caption).foregroundStyle(.secondary)
            }
            Section(tr("Cá nhân hóa", "Personalization")) {
                NavigationLink { ArtworkStudio(vi: vi, card: false) } label: { Label(tr("Tạo hình nền", "Wallpaper studio"), systemImage: "photo") }
                NavigationLink { ArtworkStudio(vi: vi, card: true) } label: { Label(tr("Thiết kế nền thẻ", "Card artwork"), systemImage: "creditcard") }
                NavigationLink { WalletImporter(vi: vi) } label: { Label(tr("Thêm thẻ Wallet đã ký", "Import signed Wallet pass"), systemImage: "wallet.bifold") }
            }
            Section(tr("Quản lý cấu hình", "Configuration tools")) {
                NavigationLink { LocalPlistEditor(vi: vi) } label: {
                    Label(tr("Trình sửa plist cục bộ", "Local plist editor"), systemImage: "doc.text")
                }
                Text(tr("Nhập, kiểm tra, sao lưu và xuất tài liệu bạn chọn. Không sửa cấu hình đang chạy của iOS.", "Import, validate, back up and export selected documents. Does not modify live iOS settings.")).font(.caption).foregroundStyle(.secondary)
            }
            Section(tr("Tương thích và an toàn", "Compatibility and safety")) {
                Text(tr("Không ghi tệp hệ thống. Không giả mạo model máy. Thay đổi hệ thống không có API công khai.", "No system-file writes or device spoofing. System changes have no public API.")).font(.footnote)
                Link("EnsWilde – GitHub", destination: URL(string: "https://github.com/nguyenls3005-cell/EnsWilde")!)
            }
        }.navigationTitle(tr("Nâng cao", "Advanced"))
    }
    private var hardwareID: String {
        var info = utsname()
        uname(&info)
        return Mirror(reflecting: info.machine).children.compactMap { child -> String? in
            guard let value = child.value as? Int8, value != 0 else { return nil }
            return String(UnicodeScalar(UInt8(bitPattern: value)))
        }.joined()
    }
}

private struct LayoutLab: View {
    let vi: Bool
    @AppStorage("previewProfile") private var profile = "iPhone 14 Pro"
    let models = ["iPhone 14 Pro", "iPhone 14 Pro Max", "iPhone 15 Pro", "iPhone 15 Pro Max", "iPhone 16 Pro", "iPhone 16 Pro Max", "iPhone 17 Pro", "iPhone 17 Pro Max", "iPhone 18 Pro", "iPhone Duo"]
    private var compactWidth: CGFloat { profile.contains("18") ? 78 : profile.contains("16") || profile.contains("17") ? 105 : 120 }
    var body: some View {
        Form {
            Section(vi ? "Minh họa bố cục" : "Illustrative layout") {
                ZStack {
                    RoundedRectangle(cornerRadius: 24).fill(LinearGradient(colors: [.indigo, .black], startPoint: .topLeading, endPoint: .bottomTrailing))
                    if profile == "iPhone Duo" {
                        HStack(spacing: 6) { Capsule().fill(.black).frame(width: 94, height: 29); Circle().fill(.black).frame(width: 29, height: 29) }
                    } else {
                        Capsule().fill(.black).frame(width: compactWidth, height: 29)
                    }
                }.frame(height: 145).animation(.easeInOut(duration: 0.25), value: profile)
                Picker(vi ? "Mẫu máy xem trước" : "Preview model", selection: $profile) {
                    ForEach(models, id: \.self) { Text($0).tag($0) }
                }
                Text(vi ? "Kích thước minh họa, không phải thông số Apple. Không đổi model máy hoặc kích thước Dynamic Island thật." : "Illustrative sizes, not Apple specifications. Actual device identity and island size are unchanged.").font(.caption)
            }
        }.navigationTitle("Dynamic Island")
    }
}

#if canImport(FoundationModels)
@available(iOS 26, *)
private struct LocalIntelligence: View {
    let vi: Bool
    @State private var prompt = ""
    @State private var answer = ""
    @State private var busy = false
    @State private var ready = false
    @Environment(\.scenePhase) private var phase
    var body: some View {
        Form {
            Section("Apple Intelligence") {
                Label(ready ? (vi ? "Model đã sẵn sàng" : "Model available") : (vi ? "Model chưa khả dụng" : "Model unavailable"), systemImage: ready ? "checkmark.circle" : "info.circle")
                Text(vi ? "Sử dụng model Apple trên thiết bị nếu đủ điều kiện. Đây không phải Siri hệ thống." : "Uses Apple's on-device model when available. This is not system Siri.").font(.caption)
                Button(vi ? "Kiểm tra lại" : "Check again") { ready = SystemLanguageModel.default.isAvailable }
            }
            Section(vi ? "Thử AI" : "Try AI") {
                TextField(vi ? "Nhập câu hỏi" : "Enter prompt", text: $prompt, axis: .vertical).lineLimit(2...5)
                Button(vi ? "Gửi" : "Ask") {
                    let input = prompt
                    busy = true
                    answer = ""
                    Task {
                        defer { busy = false }
                        do {
                            let session = LanguageModelSession()
                            answer = try await session.respond(to: input).content
                        } catch { answer = error.localizedDescription }
                    }
                }.disabled(!ready || busy || prompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                if busy { ProgressView() }
                if !answer.isEmpty { Text(answer).textSelection(.enabled) }
            }
        }.navigationTitle("AI").onAppear { ready = SystemLanguageModel.default.isAvailable }
            .onChange(of: phase) { _, p in if p == .active { ready = SystemLanguageModel.default.isAvailable } }
    }
}
#endif

private struct ArtworkStudio: View {
    let vi: Bool
    let card: Bool
    @State private var palette = "Ocean"
    @State private var title = "dynamic"
    @State private var file: URL?
    @State private var failure = false
    var colors: [Color] {
        switch palette {
        case "Rose": return [.pink, .purple, .black]
        case "Mono": return [.gray, .black]
        case "Aurora": return [.mint, .teal, .indigo]
        default: return [.cyan, .blue, .indigo, .black]
        }
    }
    private var artwork: some View {
        ZStack {
            LinearGradient(colors: colors, startPoint: .topLeading, endPoint: .bottomTrailing)
            Circle().fill(.white.opacity(0.2)).frame(width: 250).blur(radius: 48).offset(x: -90, y: -100)
            if card { Text(title).font(.system(size: 32, weight: .bold)).foregroundStyle(.white).padding(20) }
        }.clipped()
    }
    var body: some View {
        Form {
            Section {
                artwork.aspectRatio(card ? 1.586 : 9.0/19.5, contentMode: .fit).clipShape(RoundedRectangle(cornerRadius: 24))
                Picker(vi ? "Màu nền" : "Palette", selection: $palette) {
                    ForEach(["Ocean", "Rose", "Mono", "Aurora"], id: \.self) { Text($0) }
                }
                if card { TextField(vi ? "Tên trên ảnh" : "Artwork title", text: $title) }
                Button(vi ? "Tạo ảnh PNG" : "Create PNG") { export() }
                if let file { ShareLink(item: file) { Label(vi ? "Chia sẻ / lưu ảnh" : "Share / save image", systemImage: "square.and.arrow.up") } }
                if failure { Text(vi ? "Không thể xuất ảnh." : "Export failed.").foregroundStyle(.red) }
                Text(card ? (vi ? "Chỉ tạo ảnh thiết kế, không thay đổi thẻ Wallet." : "Artwork only; does not modify Wallet cards.") : (vi ? "Lưu ảnh rồi chọn làm hình nền trong Cài đặt iOS." : "Save the image, then set it as wallpaper in iOS Settings.")).font(.caption)
            }
        }.navigationTitle(card ? (vi ? "Nền thẻ" : "Card artwork") : (vi ? "Hình nền" : "Wallpaper"))
        .onChange(of: palette) { _, _ in file = nil }
        .onChange(of: title) { _, _ in file = nil }
    }
    @MainActor private func export() {
        let renderer = ImageRenderer(content: artwork.frame(width: card ? 640 : 450, height: card ? 404 : 975))
        renderer.scale = 3
        guard let data = renderer.uiImage?.pngData() else { failure = true; return }
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(card ? "dynamic-card.png" : "dynamic-wallpaper.png")
        do { try data.write(to: url, options: .atomic); file = url; failure = false }
        catch { failure = true }
    }
}

private struct WalletImporter: View {
    let vi: Bool
    @State private var picking = false
    @State private var pass: PKPass?
    @State private var show = false
    @State private var message = ""
    var body: some View {
        Form {
            Text(vi ? "Chọn tệp .pkpass đã được đơn vị phát hành ký. iOS sẽ kiểm tra và hỏi bạn trước khi thêm vào Wallet." : "Choose an issuer-signed .pkpass. iOS validates it and asks before adding it to Wallet.")
            Button(vi ? "Chọn tệp .pkpass" : "Choose .pkpass") { picking = true }
                .disabled(!PKAddPassesViewController.canAddPasses())
            if !message.isEmpty { Text(message).font(.caption) }
        }.navigationTitle("Wallet")
        .fileImporter(isPresented: $picking, allowedContentTypes: [UTType(filenameExtension: "pkpass") ?? .data]) { result in
            do {
                let url = try result.get()
                let accessed = url.startAccessingSecurityScopedResource()
                defer { if accessed { url.stopAccessingSecurityScopedResource() } }
                pass = try PKPass(data: Data(contentsOf: url))
                show = true
            } catch { message = error.localizedDescription }
        }
        .sheet(isPresented: $show) {
            if let pass { PassSheet(pass: pass) }
        }
    }
}
private struct PassSheet: UIViewControllerRepresentable {
    let pass: PKPass
    func makeUIViewController(context: Context) -> UIViewController {
        PKAddPassesViewController(pass: pass) ?? UIViewController()
    }
    func updateUIViewController(_ uiViewController: UIViewController, context: Context) {}
}
