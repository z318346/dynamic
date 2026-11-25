import ActivityKit
import SwiftUI
import UIKit

@main
struct DynamicApp: App {
    var body: some Scene {
        WindowGroup { HomeView() }
    }
}

@MainActor
final class SessionController: ObservableObject {
    @Published private(set) var activity: Activity<IslandAttributes>?
    @Published private(set) var allowed = ActivityAuthorizationInfo().areActivitiesEnabled
    @Published private(set) var busy = false
    @Published var error: String?
    private var observation: Task<Void, Never>?
    private var observedID: String?
    var active: Bool { activity != nil }

    func refresh() {
        allowed = ActivityAuthorizationInfo().areActivitiesEnabled
        activity = Activity<IslandAttributes>.activities.filter {
            $0.activityState == .active || $0.activityState == .stale
        }.sorted { $0.content.state.startedAt > $1.content.state.startedAt }.first
        if observedID != activity?.id {
            observation?.cancel()
            observedID = activity?.id
            if let current = activity {
                observation = Task { [weak self] in
                    for await state in current.activityStateUpdates {
                        guard !Task.isCancelled else { return }
                        if state == .stale { self?.objectWillChange.send() }
                        if state == .ended || state == .dismissed {
                            self?.refresh()
                            return
                        }
                    }
                }
            }
        }
    }

    var needsRenewal: Bool {
        guard let item = activity else { return false }
        return item.activityState == .stale || item.content.state.endsAt <= Date()
    }

    private func endSessions() async {
        for item in Activity<IslandAttributes>.activities {
            await item.end(nil, dismissalPolicy: .immediate)
        }
    }

    private func startSession(vi: Bool) throws {
        let now = Date()
        let end = now.addingTimeInterval(8 * 3600)
        _ = try Activity.request(attributes: IslandAttributes(sessionID: UUID().uuidString),
            content: ActivityContent(state: .init(startedAt: now, endsAt: end, vietnamese: vi), staleDate: end),
            pushType: nil)
    }

    func toggle(vi: Bool, renew: Bool = false) async {
        guard !busy else { return }
        refresh()
        busy = true
        error = nil
        defer { busy = false; refresh() }
        if active && !renew {
            await endSessions()
            return
        }
        guard allowed, UIDevice.current.userInterfaceIdiom == .phone else {
            error = vi ? "Live Activities không khả dụng. Kiểm tra quyền trong Cài đặt." : "Live Activities unavailable. Check permission in Settings."
            return
        }
        if renew { await endSessions() }
        do { try startSession(vi: vi) }
        catch { self.error = error.localizedDescription }
    }
}

struct HomeView: View {
    @StateObject private var controller = SessionController()
    @AppStorage("language") private var language = "system"
    @AppStorage("appearance") private var appearance = "system"
    @State private var presentation = "compact"
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.openURL) private var openURL
    var vi: Bool { language == "vi" || (language == "system" && Locale.preferredLanguages.first?.hasPrefix("vi") == true) }
    func tr(_ viText: String, _ enText: String) -> String { vi ? viText : enText }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    Text("dynamic").font(.system(size: 48, weight: .bold)).tracking(-2)
                    Text(tr("Tối giản. Không nội dung.", "Minimal. No content.")).foregroundStyle(.secondary)
                    VStack(spacing: 16) {
                        ZStack(alignment: .top) {
                            RoundedRectangle(cornerRadius: 28).fill(LinearGradient(colors: [.indigo.opacity(0.8), .black], startPoint: .topLeading, endPoint: .bottomTrailing))
                            Group {
                                if presentation == "expanded" {
                                    RoundedRectangle(cornerRadius: 28).fill(.black).frame(width: 230, height: 88)
                                } else if presentation == "minimal" {
                                    HStack(spacing: 5) {
                                        Capsule().fill(.black).frame(width: 88, height: 30)
                                        Circle().fill(.black).frame(width: 30, height: 30)
                                    }
                                } else {
                                    Capsule().fill(.black).frame(width: 110, height: 30)
                                }
                            }.padding(.top, 12)
                        }.frame(height: 145)
                        .animation(.easeInOut(duration: 0.22), value: presentation)
                        Picker(tr("Xem trước", "Preview"), selection: $presentation) {
                            Text(tr("Thu gọn", "Compact")).tag("compact")
                            Text(tr("Tối giản", "Minimal")).tag("minimal")
                            Text(tr("Mở rộng", "Expanded")).tag("expanded")
                        }.pickerStyle(.segmented)
                        Text(tr("Minh họa; iOS quyết định kích thước thật.", "Illustration; iOS controls actual size.")).font(.caption).foregroundStyle(.secondary)
                    }
                    VStack(alignment: .leading, spacing: 14) {
                        Label(controller.active ? tr("Phiên đang hoạt động", "Session active") : tr("Chưa bật", "Inactive"),
                              systemImage: controller.active ? "circle.fill" : "circle")
                        if let state = controller.activity?.content.state {
                            Text(timerInterval: state.startedAt...max(state.startedAt, state.endsAt), countsDown: true).monospacedDigit()
                        }
                        Button {
                            Task { await controller.toggle(vi: vi) }
                        } label: {
                            Label(controller.active ? tr("Tắt dynamic", "Stop dynamic") : tr("Bật dynamic", "Start dynamic"), systemImage: "power")
                                .font(.headline).frame(maxWidth: .infinity).padding(.vertical, 16)
                                .foregroundStyle(.white)
                        }.buttonStyle(.plain)
                        .modifier(PowerStyle(active: controller.active))
                        .disabled(controller.busy || (!controller.active && !controller.allowed))
                        if controller.active {
                            Button {
                                Task { await controller.toggle(vi: vi, renew: true) }
                            } label: {
                                Label(tr("Khởi động lại phiên", "Restart session"), systemImage: "arrow.clockwise")
                                    .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(.bordered)
                            .disabled(controller.busy || !controller.allowed)
                            if controller.needsRenewal {
                                Text(tr("Phiên đã hết hạn hoặc cần làm mới. Bạn có thể khởi động lại.", "Session expired or stale. You can restart it."))
                                    .font(.caption).foregroundStyle(.orange)
                            }
                        }
                        if !controller.allowed {
                            Button(tr("Mở cài đặt iOS", "Open iOS settings")) {
                                if let url = URL(string: UIApplication.openSettingsURLString) { openURL(url) }
                            }
                        }
                        Text(tr("Tối đa 8 giờ mỗi phiên. iOS có thể ẩn phiên trống hoặc kết thúc sớm. Không thể thu nhỏ vùng camera.", "Up to 8 hours per session. iOS may hide blank activities or end them early. The physical cutout cannot shrink."))
                            .font(.footnote).foregroundStyle(.secondary)
                    }.padding(18).background(.thinMaterial, in: RoundedRectangle(cornerRadius: 24))
                    NavigationLink {
                        AdvancedTools(vi: vi)
                    } label: {
                        HStack {
                            Label(tr("Công cụ nâng cao", "Advanced tools"), systemImage: "slider.horizontal.3")
                            Spacer()
                            Image(systemName: "chevron.right").font(.caption)
                        }.padding(15).background(.thinMaterial, in: RoundedRectangle(cornerRadius: 18))
                    }.buttonStyle(.plain)
                    NavigationLink {
                        DeviceCompatibilityView(vi: vi)
                    } label: {
                        HStack {
                            Label(tr("Thiết bị tương thích", "Compatible devices"), systemImage: "checkmark.shield")
                            Spacer()
                            Image(systemName: "chevron.right").font(.caption)
                        }.padding(15).background(.thinMaterial, in: RoundedRectangle(cornerRadius: 18))
                    }.buttonStyle(.plain)
                    Picker(tr("Ngôn ngữ", "Language"), selection: $language) {
                        Text(tr("Hệ thống", "System")).tag("system")
                        Text("Tiếng Việt").tag("vi")
                        Text("English").tag("en")
                    }
                    Picker(tr("Giao diện", "Appearance"), selection: $appearance) {
                        Text(tr("Hệ thống", "System")).tag("system")
                        Text(tr("Sáng", "Light")).tag("light")
                        Text(tr("Tối", "Dark")).tag("dark")
                    }
                    Text(tr("Không tài khoản. Không máy chủ. Live Activities chỉ hiển thị Dynamic Island trên iPhone có phần cứng tương thích.", "No account. No server. Dynamic Island requires compatible iPhone hardware."))
                        .font(.caption).foregroundStyle(.secondary)
                    Button {
                        guard let url = URL(string: "https://www.tiktok.com/@z618346") else { return }
                        UIApplication.shared.open(url, options: [.universalLinksOnly: true]) { opened in
                            if !opened {
                                Task { @MainActor in
                                    UIApplication.shared.open(url)
                                }
                            }
                        }
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: "music.note")
                                .font(.system(size: 20, weight: .bold))
                                .foregroundStyle(.white)
                                .frame(width: 44, height: 44)
                                .background(.black, in: RoundedRectangle(cornerRadius: 13))
                            VStack(alignment: .leading, spacing: 3) {
                                Text(tr("TikTok của mình", "My TikTok"))
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(.primary)
                                Text("@z618346")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Image(systemName: "arrow.up.right")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(.secondary)
                        }
                        .padding(12)
                        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 19))
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityHint(tr("Mở hồ sơ TikTok", "Opens TikTok profile"))
                    Text(tr("Phiên bản", "Version") + " " + (Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.3.2"))
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity)
                }.padding(22)
            }.navigationBarTitleDisplayMode(.inline)
        }
        .preferredColorScheme(appearance == "dark" ? .dark : appearance == "light" ? .light : nil)
        .task {
            controller.refresh()
            for await _ in ActivityAuthorizationInfo().activityEnablementUpdates {
                controller.refresh()
            }
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { controller.refresh() }
        }
        .alert("dynamic", isPresented: Binding(get: { controller.error != nil }, set: { if !$0 { controller.error = nil } })) {
            Button("OK") { controller.error = nil }
        } message: { Text(controller.error ?? "") }
    }
}

private struct PowerStyle: ViewModifier {
    let active: Bool
    func body(content: Content) -> some View {
        if #available(iOS 26.0, *) {
            content.glassEffect(.regular.tint(active ? .red : .blue).interactive(), in: Capsule())
        } else {
            content.background(active ? Color.red : Color.blue, in: Capsule())
        }
    }
}
