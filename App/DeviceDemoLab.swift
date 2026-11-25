import SwiftUI
import UIKit

private struct DemoProfile: Codable, Equatable {
    var model = "Original"
    var intelligence = false
    var siri = false
    var alwaysOn = false
    var actionButton = false
    var cameraControl = false
}

struct DeviceDemoLab: View {
    let vi: Bool
    @AppStorage("demo.applied") private var appliedData = Data()
    @AppStorage("demo.backup") private var backupData = Data()
    @State private var draft = DemoProfile()
    @State private var notice = ""
    @State private var confirm = false
    @State private var restore = false

    private let models = ["Original", "iPhone 14 Pro", "iPhone 14 Pro Max", "iPhone 15 Pro", "iPhone 15 Pro Max", "iPhone 16 Pro", "iPhone 16 Pro Max", "iPhone 17 Pro", "iPhone 17 Pro Max", "iPhone 18 Pro", "iPhone 18 Pro Max", "Dynamic Duo"]
    private func tr(_ a: String, _ b: String) -> String { vi ? a : b }
    private var applied: DemoProfile { (try? JSONDecoder().decode(DemoProfile.self, from: appliedData)) ?? DemoProfile() }
    private func modelName(_ model: String) -> String { model == "Original" ? tr("Mặc định", "Original") : model }
    private func encode(_ p: DemoProfile) -> Data { (try? JSONEncoder().encode(p)) ?? Data() }
    private func status(_ flag: Bool) -> String { flag ? tr("Bật", "On") : tr("Tắt", "Off") }
    private var pending: Bool { draft != applied }
    private var changes: [(String, String, String)] {
        let old = applied
        var result: [(String, String, String)] = []
        if old.model != draft.model { result.append((tr("Mẫu máy", "Model"), modelName(old.model), modelName(draft.model))) }
        for (label, a, b) in [("Apple Intelligence", old.intelligence, draft.intelligence), ("Siri AI", old.siri, draft.siri), ("Always-On Display", old.alwaysOn, draft.alwaysOn), ("Action Button", old.actionButton, draft.actionButton), ("Camera Control", old.cameraControl, draft.cameraControl)] {
            if a != b { result.append((label, status(a), status(b))) }
        }
        return result
    }
    var body: some View {
        Form {
            Section {
                Label(tr("CHẾ ĐỘ MÔ PHỎNG", "SIMULATION MODE"), systemImage: "info.circle.fill")
                    .font(.headline).foregroundStyle(.orange)
                Text(tr("Các lựa chọn chỉ thay đổi hồ sơ thử nghiệm trong ứng dụng, không đổi model, không mở khóa AI và không ghi tệp hệ thống.", "Selections change only an in-app demo profile. No device spoofing, AI unlocking or system-file writes.")).font(.footnote)
                LabeledContent(tr("iOS thực tế", "Actual iOS"), value: UIDevice.current.systemVersion)
                LabeledContent(tr("Hồ sơ demo đã lưu", "Saved demo profile"), value: modelName(applied.model))
            }
            Section(tr("Kiểu Dynamic Island", "Island layout")) {
                ZStack {
                    RoundedRectangle(cornerRadius: 22)
                        .fill(LinearGradient(colors: [.indigo, .black], startPoint: .topLeading, endPoint: .bottomTrailing))
                    if draft.model == "Dynamic Duo" {
                        HStack(spacing: 6) {
                            Capsule().fill(.black).frame(width: 92, height: 29)
                            Circle().fill(.black).frame(width: 29, height: 29)
                        }
                    } else {
                        Capsule().fill(.black).frame(width: draft.model.contains("18") ? 78 : 118, height: 29)
                    }
                }.frame(height: 125).animation(.easeInOut(duration: 0.2), value: draft.model)
                Picker(tr("Mẫu máy mô phỏng", "Simulated model"), selection: $draft.model) {
                    ForEach(models, id: \.self) { Text(modelName($0)).tag($0) }
                }
                Text(tr("Kích thước chỉ là minh họa, không phải thông số phần cứng.", "Illustrative dimensions, not hardware specifications.")).font(.caption)
            }
            Section(tr("Tính năng mô phỏng", "Simulated capabilities")) {
                Toggle("Apple Intelligence", isOn: $draft.intelligence)
                Toggle("Siri AI", isOn: $draft.siri)
                Toggle("Always-On Display", isOn: $draft.alwaysOn)
                Toggle("Action Button", isOn: $draft.actionButton)
                Toggle("Camera Control", isOn: $draft.cameraControl)
            }
            Section(tr("Xem lại trước khi lưu", "Review before saving")) {
                if changes.isEmpty { Text(tr("Không có thay đổi.", "No changes.")).foregroundStyle(.secondary) }
                ForEach(changes, id: \.0) { item in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(item.0).font(.subheadline.weight(.semibold))
                        Text(item.1 + " → " + item.2).font(.caption).foregroundStyle(.secondary)
                    }
                }
                Button(tr("Lưu hồ sơ demo", "Save demo profile")) { confirm = true }.disabled(!pending)
                Button(tr("Bỏ thay đổi chưa lưu", "Discard pending changes")) { draft = applied }.disabled(!pending)
                Button(tr("Khôi phục bản demo trước", "Restore previous demo"), role: .destructive) { restore = true }.disabled(backupData.isEmpty)
                Button(tr("Đặt lại demo", "Reset demo"), role: .destructive) { draft = DemoProfile(); confirm = true }
                if !notice.isEmpty { Text(notice).font(.footnote).foregroundStyle(.secondary) }
            }
        }.navigationTitle("Demo Lab")
            .onAppear { draft = applied }
            .confirmationDialog(tr("Lưu cấu hình mô phỏng?", "Save simulated configuration?"), isPresented: $confirm, titleVisibility: .visible) {
                Button(tr("Lưu vào app", "Save locally")) {
                    backupData = encode(applied)
                    appliedData = encode(draft)
                    notice = tr("Đã lưu hồ sơ demo. Hệ thống iOS không thay đổi.", "Demo profile saved. iOS is unchanged.")
                }
                Button(tr("Hủy", "Cancel"), role: .cancel) {}
            }
            .confirmationDialog(tr("Khôi phục hồ sơ demo?", "Restore demo profile?"), isPresented: $restore, titleVisibility: .visible) {
                Button(tr("Khôi phục", "Restore")) {
                    if let previous = try? JSONDecoder().decode(DemoProfile.self, from: backupData) {
                        let current = encode(applied)
                        appliedData = encode(previous)
                        backupData = current
                        draft = previous
                        notice = tr("Đã khôi phục hồ sơ demo.", "Demo profile restored.")
                    }
                }
                Button(tr("Hủy", "Cancel"), role: .cancel) {}
            }
    }
}
