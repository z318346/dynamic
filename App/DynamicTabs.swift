import SwiftUI
import UIKit

struct DynamicTabs: View {
    @StateObject private var controller = SessionController()
    @AppStorage("language") private var language = "system"
    @AppStorage("appearance") private var appearance = "system"
    @Environment(\.scenePhase) private var phase
    private var vi: Bool { language == "vi" || (language == "system" && Locale.preferredLanguages.first?.hasPrefix("vi") == true) }
    private func tr(_ a: String, _ b: String) -> String { vi ? a : b }
    var body: some View {
        TabView {
            HomeView(controller: controller)
                .tabItem { Label(tr("Thiết bị", "Device"), systemImage: "iphone") }
            NavigationStack { AdvancedTools(vi: vi) }
                .tabItem { Label(tr("Tùy chỉnh", "Customize"), systemImage: "slider.horizontal.3") }
            NavigationStack { LocalPlistEditor(vi: vi) }
                .tabItem { Label(tr("Sao lưu", "Backups"), systemImage: "archivebox") }
            NavigationStack { AppPreferences(controller: controller, vi: vi) }
                .tabItem { Label(tr("Cài đặt", "Settings"), systemImage: "gearshape") }
        }
        .preferredColorScheme(appearance == "dark" ? .dark : appearance == "light" ? .light : nil)
        .onAppear { controller.refresh() }
        .onChange(of: phase) { _, value in if value == .active { controller.refresh() } }
    }
}

private struct AppPreferences: View {
    @ObservedObject var controller: SessionController
    let vi: Bool
    @AppStorage("language") private var language = "system"
    @AppStorage("appearance") private var appearance = "system"
    @AppStorage("settingsBackupLanguage") private var backupLanguage = "system"
    @AppStorage("settingsBackupAppearance") private var backupAppearance = "system"
    @AppStorage("settingsHasBackup") private var hasBackup = false
    @State private var draftLanguage = "system"
    @State private var draftAppearance = "system"
    @State private var notice = ""
    @State private var confirmRestore = false
    private func tr(_ a: String, _ b: String) -> String { vi ? a : b }
    private var pending: Bool { draftLanguage != language || draftAppearance != appearance }
    private func resetDraft() { draftLanguage = language; draftAppearance = appearance }
    private func apply() {
        backupLanguage = language; backupAppearance = appearance; hasBackup = true
        language = draftLanguage; appearance = draftAppearance
        notice = tr("Đã lưu cài đặt trong dynamic.", "Saved dynamic app preferences.")
    }
    var body: some View {
        Form {
            Section(tr("Cài đặt ứng dụng", "App preferences")) {
                Picker(tr("Ngôn ngữ", "Language"), selection: $draftLanguage) {
                    Text(tr("Hệ thống", "System")).tag("system")
                    Text("Tiếng Việt").tag("vi")
                    Text("English").tag("en")
                }
                Picker(tr("Giao diện", "Appearance"), selection: $draftAppearance) {
                    Text(tr("Hệ thống", "System")).tag("system")
                    Text(tr("Sáng", "Light")).tag("light")
                    Text(tr("Tối", "Dark")).tag("dark")
                }
                Label(pending ? tr("Có thay đổi chưa lưu", "Pending changes") : tr("Đã đồng bộ cài đặt", "Preferences up to date"), systemImage: pending ? "circle.dotted" : "checkmark.circle")
                    .foregroundStyle(pending ? Color.orange : Color.secondary)
                Button { apply() } label: {
                    Label(tr("Áp dụng thay đổi", "Apply changes"), systemImage: "checkmark.circle.fill")
                }.disabled(!pending)
                Button { resetDraft(); notice = "" } label: {
                    Label(tr("Hủy thay đổi", "Discard changes"), systemImage: "arrow.uturn.backward")
                }.disabled(!pending)
                Button(tr("Khôi phục cài đặt trước", "Restore previous preferences")) { confirmRestore = true }
                    .disabled(!hasBackup)
                if !notice.isEmpty { Text(notice).font(.footnote).foregroundStyle(.secondary) }
            }
            Section(tr("Phiên Dynamic Island", "Dynamic Island session")) {
                LabeledContent(tr("Trạng thái phiên", "Session status"), value: controller.active ? tr("Đang hoạt động", "Active") : tr("Chưa bật", "Inactive"))
                Button {
                    Task { await controller.toggle(vi: vi, renew: true) }
                } label: {
                    Label(controller.active ? tr("Khởi động lại Live Activity", "Restart Live Activity") : tr("Bắt đầu Live Activity", "Start Live Activity"), systemImage: "arrow.clockwise")
                }.disabled(controller.busy || !controller.allowed)
                if let error = controller.error { Text(error).font(.footnote).foregroundStyle(.red) }
                Text(tr("Chỉ khởi động lại Live Activity của dynamic, không Respring hệ thống. iOS quyết định cách hiển thị.", "Restarts only dynamic's Live Activity, not SpringBoard. iOS controls presentation.")).font(.footnote)
            }
            Section(tr("Thông tin", "About")) {
                NavigationLink { DeviceCompatibilityView(vi: vi) } label: { Label(tr("Thiết bị tương thích", "Compatible devices"), systemImage: "checkmark.shield") }
                LabeledContent(tr("Phiên bản", "Version"), value: Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.4")
                Link(tr("Bản phát hành", "Releases"), destination: URL(string: "https://github.com/cuaviet/dynamic/releases")!)
            }
        }
        .navigationTitle(tr("Cài đặt", "Settings"))
        .onAppear { resetDraft(); controller.refresh() }
        .confirmationDialog(tr("Khôi phục cài đặt đã lưu?", "Restore saved preferences?"), isPresented: $confirmRestore, titleVisibility: .visible) {
            Button(tr("Khôi phục", "Restore")) {
                let oldLanguage = language
                let oldAppearance = appearance
                language = backupLanguage; appearance = backupAppearance
                backupLanguage = oldLanguage; backupAppearance = oldAppearance
                resetDraft()
                notice = tr("Đã khôi phục cài đặt ứng dụng.", "App preferences restored.")
            }
            Button(tr("Hủy", "Cancel"), role: .cancel) {}
        }
    }
}
