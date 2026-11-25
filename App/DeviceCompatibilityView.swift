import SwiftUI
import UIKit
import ActivityKit
#if canImport(FoundationModels)
import FoundationModels
#endif

private struct SupportedPhone: Identifiable {
    let id: String
    let name: String
    let island: Bool
    let intelligence: Bool
}

struct DeviceCompatibilityView: View {
    let vi: Bool
    @State private var enabled = ActivityAuthorizationInfo().areActivitiesEnabled
    @State private var aiReady: Bool? = nil
    @Environment(\.scenePhase) private var phase
    private func tr(_ a: String, _ b: String) -> String { vi ? a : b }

    // Reference: iosref.com/hardware-strings and support.apple.com/108044, /121115, /148588.
    private static let phones: [SupportedPhone] = [
        .init(id: "iPhone19,4", name: "iPhone Duo", island: true, intelligence: true),
        .init(id: "iPhone19,2", name: "iPhone 18 Pro", island: true, intelligence: true),
        .init(id: "iPhone19,3", name: "iPhone 18 Pro Max", island: true, intelligence: true),
        .init(id: "iPhone19,7", name: "iPhone 18 Pro Max", island: true, intelligence: true),
        .init(id: "iPhone18,1", name: "iPhone 17 Pro", island: true, intelligence: true),
        .init(id: "iPhone18,2", name: "iPhone 17 Pro Max", island: true, intelligence: true),
        .init(id: "iPhone18,3", name: "iPhone 17", island: true, intelligence: true),
        .init(id: "iPhone18,4", name: "iPhone Air", island: true, intelligence: true),
        .init(id: "iPhone18,5", name: "iPhone 17e", island: false, intelligence: true),
        .init(id: "iPhone17,1", name: "iPhone 16 Pro", island: true, intelligence: true),
        .init(id: "iPhone17,2", name: "iPhone 16 Pro Max", island: true, intelligence: true),
        .init(id: "iPhone17,3", name: "iPhone 16", island: true, intelligence: true),
        .init(id: "iPhone17,4", name: "iPhone 16 Plus", island: true, intelligence: true),
        .init(id: "iPhone17,5", name: "iPhone 16e", island: false, intelligence: true),
        .init(id: "iPhone16,1", name: "iPhone 15 Pro", island: true, intelligence: true),
        .init(id: "iPhone16,2", name: "iPhone 15 Pro Max", island: true, intelligence: true),
        .init(id: "iPhone15,4", name: "iPhone 15", island: true, intelligence: false),
        .init(id: "iPhone15,5", name: "iPhone 15 Plus", island: true, intelligence: false),
        .init(id: "iPhone15,2", name: "iPhone 14 Pro", island: true, intelligence: false),
        .init(id: "iPhone15,3", name: "iPhone 14 Pro Max", island: true, intelligence: false),
        .init(id: "iPhone14,7", name: "iPhone 14", island: false, intelligence: false),
        .init(id: "iPhone14,8", name: "iPhone 14 Plus", island: false, intelligence: false),
        .init(id: "iPhone14,2", name: "iPhone 13 Pro", island: false, intelligence: false),
        .init(id: "iPhone14,3", name: "iPhone 13 Pro Max", island: false, intelligence: false),
        .init(id: "iPhone14,4", name: "iPhone 13 mini", island: false, intelligence: false),
        .init(id: "iPhone14,5", name: "iPhone 13", island: false, intelligence: false),
        .init(id: "iPhone13,1", name: "iPhone 12 mini", island: false, intelligence: false),
        .init(id: "iPhone13,2", name: "iPhone 12", island: false, intelligence: false),
        .init(id: "iPhone13,3", name: "iPhone 12 Pro", island: false, intelligence: false),
        .init(id: "iPhone13,4", name: "iPhone 12 Pro Max", island: false, intelligence: false),
        .init(id: "iPhone12,1", name: "iPhone 11", island: false, intelligence: false),
        .init(id: "iPhone12,3", name: "iPhone 11 Pro", island: false, intelligence: false),
        .init(id: "iPhone12,5", name: "iPhone 11 Pro Max", island: false, intelligence: false),
        .init(id: "iPhone12,8", name: "iPhone SE (2)", island: false, intelligence: false),
        .init(id: "iPhone14,6", name: "iPhone SE (3)", island: false, intelligence: false),
        .init(id: "iPhone11,2", name: "iPhone XS", island: false, intelligence: false),
        .init(id: "iPhone11,4", name: "iPhone XS Max", island: false, intelligence: false),
        .init(id: "iPhone11,6", name: "iPhone XS Max", island: false, intelligence: false),
        .init(id: "iPhone11,8", name: "iPhone XR", island: false, intelligence: false)
    ]
    private var identifier: String {
        #if targetEnvironment(simulator)
        return ProcessInfo.processInfo.environment["SIMULATOR_MODEL_IDENTIFIER"] ?? "Simulator"
        #else
        var info = utsname()
        uname(&info)
        return Mirror(reflecting: info.machine).children.compactMap { child -> String? in
            guard let value = child.value as? Int8, value != 0 else { return nil }
            return String(UnicodeScalar(UInt8(bitPattern: value)))
        }.joined()
        #endif
    }
    private var current: SupportedPhone? { Self.phones.first { $0.id == identifier } }
    private var uniquePhones: [SupportedPhone] {
        var seen = Set<String>()
        return Self.phones.filter { seen.insert($0.name).inserted }
    }
    private func badge(_ supported: Bool?) -> some View {
        let icon = supported == true ? "checkmark.circle.fill" : supported == false ? "minus.circle" : "questionmark.circle"
        let color: Color = supported == true ? .green : .secondary
        return Image(systemName: icon).foregroundStyle(color)
            .accessibilityLabel(supported == true ? tr("Có", "Yes") : supported == false ? tr("Không", "No") : tr("Chưa xác định", "Unknown"))
    }
    private func status(_ value: Bool?) -> String {
        value == true ? tr("Có hỗ trợ", "Supported") : value == false ? tr("Không hỗ trợ", "Not supported") : tr("Chưa xác định", "Unknown")
    }
    private func refresh() {
        enabled = ActivityAuthorizationInfo().areActivitiesEnabled
        #if canImport(FoundationModels)
        if #available(iOS 26, *) { aiReady = SystemLanguageModel.default.isAvailable } else { aiReady = nil }
        #endif
    }
    var body: some View {
        List {
            Section(tr("Thiết bị của bạn", "Your device")) {
                LabeledContent(tr("Model", "Model"), value: current?.name ?? tr("Chưa nhận diện", "Unrecognized"))
                LabeledContent(tr("Mã phần cứng", "Hardware ID"), value: identifier)
                LabeledContent("iOS", value: UIDevice.current.systemVersion)
                LabeledContent("Dynamic Island", value: status(current?.island))
                LabeledContent("Live Activities", value: enabled ? tr("Được phép", "Enabled") : tr("Chưa được phép", "Disabled"))
                LabeledContent("Apple Intelligence", value: status(current?.intelligence))
                LabeledContent(tr("AI trong dynamic", "AI in dynamic"), value: aiReady == true ? tr("Sẵn sàng", "Ready") : aiReady == false ? tr("Chưa sẵn sàng", "Unavailable") : tr("Cần iOS 26+", "Requires iOS 26+"))
                #if targetEnvironment(simulator)
                Text(tr("Đang chạy trình mô phỏng, không xác nhận được phần cứng thật.", "Simulator: physical hardware is not verified.")).font(.caption)
                #endif
                Button(tr("Kiểm tra lại", "Refresh")) { refresh() }
                if current?.island == false {
                    Text(tr("Máy không có Dynamic Island; Live Activities có thể xuất hiện trên màn hình khóa, không tạo được Dynamic Island toàn hệ thống.", "No Dynamic Island hardware. Live Activities may appear on the Lock Screen instead.")).font(.footnote)
                }
            }
            Section(tr("Danh sách tương thích", "Compatibility list")) {
                HStack {
                    Text(tr("Dòng máy", "Model"))
                    Spacer()
                    Text("DI").frame(width: 36)
                    Text("AI").frame(width: 36)
                }.font(.caption.weight(.semibold)).foregroundStyle(.secondary)
                ForEach(uniquePhones) { phone in
                    HStack {
                        Text(phone.name).font(.subheadline)
                        Spacer()
                        badge(phone.island).frame(width: 36)
                        badge(phone.intelligence).frame(width: 36)
                    }
                }
            } footer: {
                Text(tr("DI = Dynamic Island; AI = phần cứng hỗ trợ Apple Intelligence. AI còn phụ thuộc iOS, ngôn ngữ, khu vực và thiết lập. App yêu cầu iOS 17+. Danh sách không bảo đảm widget trống sẽ luôn hiển thị.", "DI = Dynamic Island; AI = Apple Intelligence hardware eligibility. AI also depends on OS, language, region and settings. App requires iOS 17+. Blank widget visibility is not guaranteed."))
            }
            Section(tr("Nguồn tham khảo", "References")) {
                Link(tr("Danh sách iPhone – Apple", "Identify iPhone – Apple"), destination: URL(string: "https://support.apple.com/108044")!)
                Link("Apple Intelligence", destination: URL(string: "https://support.apple.com/121115")!)
                Link("iPhone Duo", destination: URL(string: "https://support.apple.com/148588")!)
                Link("iOS Ref", destination: URL(string: "https://iosref.com/hardware-strings")!)
            }
        }
        .navigationTitle(tr("Thiết bị tương thích", "Compatibility"))
        .onAppear { refresh() }
        .onChange(of: phase) { _, value in if value == .active { refresh() } }
        .task {
            for await _ in ActivityAuthorizationInfo().activityEnablementUpdates { refresh() }
        }
    }
}
