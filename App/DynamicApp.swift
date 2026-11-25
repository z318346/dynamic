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
                        if state == .ended || state == .dismissed {
                            self?.refresh()
                            return
                        }
                    }
                }
            }
        }
    }

    func toggle(vi: Bool) async {
        guard !busy else { return }
        refresh()
        busy = true
        defer { busy = false; refresh() }
        if active {
            for item in Activity<IslandAttributes>.activities {
                await item.end(nil, dismissalPolicy: .immediate)
            }
        } else {
            guard allowed, UIDevice.current.userInterfaceIdiom == .phone else {
                error = vi ? "Live Activities không khả dụng." : "Live Activities unavailable."
                return
            }
            let now = Date()
            let end = now.addingTimeInterval(8 * 3600)
            do {
                _ = try Activity.request(attributes: IslandAttributes(sessionID: UUID().uuidString),
                    content: ActivityContent(state: .init(startedAt: now, endsAt: end, vietnamese: vi), staleDate: end),
                    pushType: nil)
            } catch { self.error = error.localizedDescription }
        }
    }
}

struct HomeView: View {
    @StateObject private var controller = SessionController()
    @AppStorage("language") private var language = "system"
    @AppStorage("appearance") private var appearance = "system"
    @AppStorage("presentation") private var presentation = "compact"
    @State private var settings = false
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.openURL) private var openURL
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    var vi: Bool { language == "vi" || (language == "system" && Locale.preferredLanguages.first?.hasPrefix("vi") == true) }
    var dark: Bool { colorScheme == .dark }
    var accent: Color { Color(red: 0.29, green: 0.48, blue: 0.95) }
    var scheme: ColorScheme? { appearance == "dark" ? .dark : appearance == "light" ? .light : nil }
    func tr(_ a: String, _ b: String) -> String { vi ? a : b }

    var body: some View {
        ScrollView {
            VStack(spacing: 22) {
                header
                hero
                controlPanel
                HStack(spacing: 10) {
                    miniInfo("battery.100percent", tr("Tiết kiệm pin", "Low impact"))
                    Spacer()
                    miniInfo("lock.shield", tr("Riêng tư", "Private"))
                    Spacer()
                    miniInfo("wifi.slash", tr("Ngoại tuyến", "Offline"))
                }.padding(.horizontal, 8)
                Text(tr("iOS quyết định kích thước và thời gian hiển thị thực tế. Phiên trống có thể bị ẩn.", "iOS controls actual size and duration. Blank activities may be hidden."))
                    .font(.caption2).foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                Text("dynamic  /  1.2").font(.system(size: 10, weight: .medium, design: .monospaced))
                    .foregroundStyle(.tertiary)
            }.frame(maxWidth: 460).padding(22).frame(maxWidth: .infinity)
        }
        .scrollIndicators(.hidden)
        .background {
            ZStack(alignment: .topTrailing) {
                (dark ? Color(red: 0.035, green: 0.043, blue: 0.065) : Color(red: 0.95, green: 0.96, blue: 0.985))
                Circle().fill(accent.opacity(dark ? 0.22 : 0.13)).frame(width: 280, height: 280).blur(radius: 95).offset(x: 90, y: -90)
            }.ignoresSafeArea()
        }
        .preferredColorScheme(scheme)
        .sheet(isPresented: $settings) { settingsSheet.preferredColorScheme(scheme) }
        .task {
            controller.refresh()
            for await _ in ActivityAuthorizationInfo().activityEnablementUpdates { controller.refresh() }
        }
        .onChange(of: scenePhase) { _, phase in if phase == .active { controller.refresh() } }
        .alert("dynamic", isPresented: Binding(get: { controller.error != nil }, set: { if !$0 { controller.error = nil } })) {
            Button("OK") { controller.error = nil }
        } message: { Text(controller.error ?? "") }
    }

    private var header: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 7) {
                    Capsule().fill(accent).frame(width: 14, height: 5)
                    Text("ISLAND CONTROL").font(.system(size: 10, weight: .semibold, design: .monospaced)).tracking(2)
                }.foregroundStyle(.secondary)
                Text("dynamic.").font(.system(size: 43, weight: .heavy, design: .default)).tracking(-3)
                    .accessibilityAddTraits(.isHeader)
            }
            Spacer()
            Button { settings = true } label: {
                Image(systemName: "gearshape").font(.system(size: 20, weight: .medium))
                    .frame(width: 50, height: 50)
                    .modifier(GlassSurface(circular: true))
            }.buttonStyle(.plain).accessibilityLabel(tr("Cài đặt", "Settings"))
        }
    }

    private var hero: some View {
        VStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 30).fill(
                    LinearGradient(colors: [Color(red: 0.14, green: 0.20, blue: 0.36),
                                            Color(red: 0.055, green: 0.07, blue: 0.13), .black],
                                   startPoint: .topLeading, endPoint: .bottomTrailing))
                GeometryReader { geo in
                    Circle().fill(accent.opacity(0.45)).frame(width: geo.size.width * 0.65)
                        .blur(radius: 55).position(x: geo.size.width * 0.84, y: geo.size.height * 0.9)
                    Ellipse().stroke(.white.opacity(0.12), lineWidth: 1)
                        .frame(width: geo.size.width * 1.2, height: geo.size.height * 0.65)
                        .rotationEffect(.degrees(-28)).position(x: geo.size.width * 0.7, y: geo.size.height * 0.8)
                }.clipped()
                VStack(spacing: 0) {
                    HStack {
                        Text("9:41").font(.system(size: 12, weight: .semibold))
                        Spacer()
                        Image(systemName: "cellularbars")
                        Image(systemName: "wifi")
                        Image(systemName: "battery.100percent")
                    }.font(.system(size: 11)).foregroundStyle(.white.opacity(0.85))
                    Spacer(minLength: 16)
                    ZStack {
                        if presentation == "expanded" {
                            RoundedRectangle(cornerRadius: 27).fill(.black).frame(maxWidth: 222).frame(height: 76)
                        } else if presentation == "minimal" {
                            HStack(spacing: 6) {
                                Capsule().fill(.black).frame(width: 77, height: 27)
                                Circle().fill(.black).frame(width: 27, height: 27)
                            }
                        } else {
                            Capsule().fill(.black).frame(width: 100, height: 27)
                        }
                    }.frame(height: 76).shadow(color: .black.opacity(0.28), radius: 9, y: 4)
                    .animation(reduceMotion ? nil : .spring(response: 0.4, dampingFraction: 0.8), value: presentation)
                    .accessibilityHidden(true)
                    Spacer(minLength: 12)
                    Text(tr("Không nội dung. Chỉ Dynamic Island.", "Nothing inside. Just the island."))
                        .font(.system(size: 12, weight: .medium)).foregroundStyle(.white.opacity(0.75))
                        .multilineTextAlignment(.center)
                }.padding(20)
            }.frame(height: 196).clipShape(RoundedRectangle(cornerRadius: 30))
                .overlay(RoundedRectangle(cornerRadius: 30).strokeBorder(.white.opacity(0.12), lineWidth: 1))
            Picker(tr("Xem trước", "Preview"), selection: $presentation) {
                Text(tr("Thu gọn", "Compact")).tag("compact")
                Text(tr("Tối giản", "Minimal")).tag("minimal")
                Text(tr("Mở rộng", "Expanded")).tag("expanded")
            }.pickerStyle(.segmented)
            Text(tr("Bản xem trước minh họa", "Illustrative preview")).font(.caption2).foregroundStyle(.secondary)
        }
    }

    private var controlPanel: some View {
        VStack(spacing: 16) {
            HStack {
                HStack(spacing: 7) {
                    Circle().fill(controller.active ? Color.green : Color.gray).frame(width: 7, height: 7)
                    Text(controller.active ? tr("ĐANG HOẠT ĐỘNG", "SESSION ACTIVE") : tr("SẴN SÀNG", "STANDBY"))
                        .font(.system(size: 10, weight: .semibold, design: .monospaced)).tracking(0.8)
                }
                Spacer()
                Text("LIVE ACTIVITY").font(.system(size: 10, weight: .medium, design: .monospaced))
                    .foregroundStyle(.secondary)
            }
            Button {
                Task { await controller.toggle(vi: vi) }
            } label: {
                ZStack {
                    Circle().strokeBorder(accent.opacity(controller.active ? 0.32 : 0.12), lineWidth: 1).frame(width: 110, height: 110)
                    Circle().strokeBorder(accent.opacity(0.12), lineWidth: 1).frame(width: 120, height: 120)
                    if controller.active {
                        Circle().fill(accent.opacity(0.28)).frame(width: 90, height: 90).blur(radius: 17)
                    }
                    ZStack {
                        if controller.busy { ProgressView().tint(controller.active ? .white : accent) }
                        else { Image(systemName: "power").font(.system(size: 32, weight: .medium)) }
                    }
                    .foregroundStyle(controller.active ? Color.white : accent)
                    .frame(width: 92, height: 92)
                    .modifier(GlassSurface(circular: true, tint: controller.active ? accent : nil))
                }
            }.buttonStyle(.plain)
                .disabled(controller.busy || (!controller.active && !controller.allowed))
                .accessibilityLabel(controller.active ? tr("Tắt dynamic", "Stop dynamic") : tr("Bật dynamic", "Start dynamic"))
            Text(controller.active ? tr("Chạm để tắt", "Tap to stop") : tr("Chạm để kích hoạt", "Tap to start"))
                .font(.title3.weight(.semibold))
            if let state = controller.activity?.content.state {
                HStack(spacing: 5) {
                    Image(systemName: "clock")
                    Text(timerInterval: state.startedAt...max(state.startedAt, state.endsAt), countsDown: true).monospacedDigit()
                }.font(.footnote).foregroundStyle(.secondary)
            } else {
                Text(tr("Tối đa 8 giờ mỗi phiên", "Up to 8 hours per session")).font(.footnote).foregroundStyle(.secondary)
            }
            if !controller.allowed {
                Button(tr("Bật Live Activities trong cài đặt", "Enable Live Activities in Settings")) {
                    if let url = URL(string: UIApplication.openSettingsURLString) { openURL(url) }
                }.font(.footnote)
            }
        }.padding(20)
            .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 30))
            .overlay(RoundedRectangle(cornerRadius: 30).strokeBorder(.primary.opacity(0.07), lineWidth: 1))
            .animation(reduceMotion ? nil : .easeInOut(duration: 0.25), value: controller.active)
    }

    private func miniInfo(_ icon: String, _ title: String) -> some View {
        VStack(spacing: 6) {
            Image(systemName: icon).font(.system(size: 18, weight: .light))
            Text(title).font(.caption2).multilineTextAlignment(.center)
        }.foregroundStyle(.secondary).frame(maxWidth: .infinity)
    }

    private var settingsSheet: some View {
        NavigationStack {
            Form {
                Section(tr("Cá nhân hóa", "Personalization")) {
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
                }
                Section(tr("Thông tin", "About")) {
                    LabeledContent(tr("Phiên bản", "Version"), value: "1.2")
                    LabeledContent(tr("Chế độ", "Mode"), value: "Blank Island")
                    Text(tr("Không tài khoản, không máy chủ. Dynamic Island chỉ xuất hiện trên phần cứng tương thích. Không thể thu nhỏ vùng camera hoặc ép iOS duy trì hiển thị.", "No account or server. Dynamic Island requires compatible hardware. The physical cutout cannot shrink and iOS cannot be forced to keep it visible."))
                        .font(.footnote).foregroundStyle(.secondary)
                }
            }.navigationTitle(tr("Cài đặt", "Settings"))
                .navigationBarTitleDisplayMode(.inline)
                .toolbar { ToolbarItem(placement: .confirmationAction) { Button(tr("Xong", "Done")) { settings = false } } }
        }
    }
}

private struct GlassSurface: ViewModifier {
    var circular = false
    var tint: Color? = nil
    func body(content: Content) -> some View {
        if #available(iOS 26.0, *) {
            if circular {
                content.glassEffect(.regular.tint(tint).interactive(), in: Circle())
            } else {
                content.glassEffect(.regular.tint(tint).interactive(), in: Capsule())
            }
        } else {
            content.background {
                if let tint { Circle().fill(tint) }
                else { Circle().fill(.regularMaterial) }
            }.overlay(Circle().strokeBorder(.primary.opacity(0.09), lineWidth: 1))
        }
    }
}
