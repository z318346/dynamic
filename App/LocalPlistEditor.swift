import SwiftUI
import UniformTypeIdentifiers
import Foundation

struct LocalPlistEditor: View {
    let vi: Bool
    @State private var importing = false
    @State private var original = Data()
    @State private var sourceName = ""
    @State private var draft = ""
    @State private var note = ""
    @State private var output: URL?
    @State private var backups: [URL] = []
    @State private var confirmRestore = false
    @State private var restoreURL: URL?
    @State private var isError = false

    private func tr(_ a: String, _ b: String) -> String { vi ? a : b }

    var body: some View {
        Form {
            Section(tr("Tài liệu", "Document")) {
                Button { importing = true } label: { Label(tr("Mở tệp plist", "Open plist"), systemImage: "folder") }
                if !sourceName.isEmpty {
                    LabeledContent(tr("Tên tệp", "Filename"), value: sourceName)
                    Text(tr("Chỉ sửa bản sao của tệp người dùng chọn. Tệp gốc không bị ghi đè.", "Edits a copy of the selected file. The original is never overwritten.")).font(.caption)
                }
            }
            if !original.isEmpty {
                Section(tr("Nội dung XML", "XML contents")) {
                    TextEditor(text: $draft)
                        .font(.system(.caption, design: .monospaced))
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                        .frame(minHeight: 230)
                    Button(tr("Kiểm tra định dạng", "Validate format")) { validate() }
                    Button(tr("Lưu bản sao và sao lưu", "Save copy and backup")) { save() }
                    Button(tr("Hoàn tác chỉnh sửa", "Discard edits"), role: .destructive) { reset() }
                    if let output {
                        ShareLink(item: output) { Label(tr("Xuất tệp đã sửa", "Export edited file"), systemImage: "square.and.arrow.up") }
                    }
                }
            }
            Section(tr("Bản sao lưu cục bộ", "Local backups")) {
                if backups.isEmpty { Text(tr("Chưa có bản sao lưu.", "No backups yet.")).foregroundStyle(.secondary) }
                ForEach(backups, id: \.self) { url in
                    VStack(alignment: .leading, spacing: 8) {
                        Text(url.lastPathComponent).font(.caption).lineLimit(2)
                        HStack {
                            ShareLink(item: url) { Label(tr("Xuất", "Export"), systemImage: "square.and.arrow.up") }
                            Spacer()
                            Button(tr("Mở bản sao", "Open copy")) { restoreURL = url; confirmRestore = true }.buttonStyle(.borderless)
                        }
                    }
                }
            }
            if !note.isEmpty {
                Section {
                    Text(note).foregroundStyle(isError ? Color.red : Color.secondary).font(.footnote)
                }
            }
        }
        .navigationTitle(tr("Trình sửa plist", "Plist editor"))
        .onAppear { refreshBackups() }
        .onChange(of: draft) { _, _ in output = nil }
        .fileImporter(isPresented: $importing, allowedContentTypes: [UTType(filenameExtension: "plist") ?? .data]) { result in
            do {
                let url = try result.get()
                let scoped = url.startAccessingSecurityScopedResource()
                defer { if scoped { url.stopAccessingSecurityScopedResource() } }
                let size = try url.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? 0
                guard size <= 4_000_000 else { throw EditorError.tooLarge }
                let data = try Data(contentsOf: url)
                try load(data, name: url.lastPathComponent)
            } catch { report(error.localizedDescription, error: true) }
        }
        .confirmationDialog(tr("Mở bản sao và bỏ chỉnh sửa chưa lưu?", "Open backup and discard unsaved edits?"), isPresented: $confirmRestore, titleVisibility: .visible) {
            Button(tr("Mở bản sao cục bộ", "Open local backup")) {
                if let url = restoreURL {
                    do { try load(Data(contentsOf: url), name: url.lastPathComponent) }
                    catch { report(error.localizedDescription, error: true) }
                }
            }
            Button(tr("Hủy", "Cancel"), role: .cancel) {}
        }
    }

    private enum EditorError: LocalizedError {
        case tooLarge, invalidXML
        var errorDescription: String? {
            switch self {
            case .tooLarge: return "File exceeds the 4 MB editor limit."
            case .invalidXML: return "Invalid property list XML."
            }
        }
    }

    private func canonical(_ data: Data) throws -> String {
        guard data.count <= 4_000_000 else { throw EditorError.tooLarge }
        let object = try PropertyListSerialization.propertyList(from: data, options: [], format: nil)
        let xml = try PropertyListSerialization.data(fromPropertyList: object, format: .xml, options: 0)
        guard let text = String(data: xml, encoding: .utf8), xml.count <= 4_000_000 else { throw EditorError.tooLarge }
        return text
    }
    private func load(_ data: Data, name: String) throws {
        let xml = try canonical(data)
        original = data
        sourceName = name
        draft = xml
        output = nil
        report(tr("Đã mở bản sao cục bộ.", "Local copy opened."))
    }
    private func validatedData() throws -> Data {
        let bytes = Data(draft.utf8)
        return Data(try canonical(bytes).utf8)
    }
    private func validate() {
        do { _ = try validatedData(); report(tr("Định dạng plist hợp lệ. Không xác nhận tính hợp lệ đối với hệ thống iOS.", "Valid plist format. This does not verify suitability for iOS system use.")) }
        catch { report(error.localizedDescription, error: true) }
    }
    private func directory() throws -> URL {
        let base = try FileManager.default.url(for: .documentDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
        let dir = base.appendingPathComponent("LocalPlistBackups", isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }
    private func refreshBackups() {
        do {
            let dir = try directory()
            backups = try FileManager.default.contentsOfDirectory(at: dir, includingPropertiesForKeys: nil)
                .filter { $0.pathExtension == "plist" }.sorted { $0.lastPathComponent > $1.lastPathComponent }
        } catch { report(error.localizedDescription, error: true) }
    }
    private func save() {
        do {
            let bytes = try validatedData()
            let dir = try directory()
            let stamp = String(Int(Date().timeIntervalSince1970)) + "-" + UUID().uuidString.prefix(8)
            let backup = dir.appendingPathComponent("backup-\(stamp).plist")
            try original.write(to: backup, options: [.atomic, .completeFileProtection])
            let out = FileManager.default.temporaryDirectory.appendingPathComponent("dynamic-edited-\(stamp).plist")
            try bytes.write(to: out, options: [.atomic, .completeFileProtection])
            output = out
            refreshBackups()
            report(tr("Đã sao lưu tệp gốc và tạo bản xuất mới.", "Original backed up; edited export created."))
        } catch { report(error.localizedDescription, error: true) }
    }
    private func reset() {
        do { draft = try canonical(original); output = nil; report(tr("Đã hoàn tác.", "Edits discarded.")) }
        catch { report(error.localizedDescription, error: true) }
    }
    private func report(_ text: String, error: Bool = false) { note = text; isError = error }
}
