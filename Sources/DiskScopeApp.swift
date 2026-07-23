import AppKit
import Combine
import Darwin
import SwiftUI

@main
struct DiskScopeApp: App {
    @StateObject private var model = AnalyzerModel()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(model)
                .environment(\.locale, model.language.locale)
                .frame(minWidth: 980, minHeight: 680)
        }
        .windowStyle(.hiddenTitleBar)
        .commands {
            CommandGroup(replacing: .newItem) {
                Button("Ordner auswählen …") {
                    model.chooseFolder()
                }
                .keyboardShortcut("o")
            }
        }
    }
}

enum AppLanguage: String, CaseIterable, Identifiable, Sendable {
    case german = "de"
    case english = "en"
    case spanish = "es"

    var id: String { rawValue }
    var locale: Locale { Locale(identifier: rawValue) }

    var title: String {
        switch self {
        case .german: return "Deutsch"
        case .english: return "English"
        case .spanish: return "Español"
        }
    }
}

enum L10n {
    static func string(_ key: String, language: AppLanguage) -> String {
        guard
            let path = Bundle.main.path(forResource: language.rawValue, ofType: "lproj"),
            let bundle = Bundle(path: path)
        else {
            return key
        }
        return bundle.localizedString(forKey: key, value: key, table: nil)
    }

    static func format(
        _ key: String,
        language: AppLanguage,
        _ arguments: CVarArg...
    ) -> String {
        String(
            format: string(key, language: language),
            locale: language.locale,
            arguments: arguments
        )
    }
}

enum Screen: String, CaseIterable, Identifiable {
    case folders = "Ordnerstruktur"
    case overview = "Mac-Übersicht"
    case applications = "Apps"
    case largest = "Größte Dateien"
    case duplicates = "Duplikate"
    case cleanup = "Aufräumen"

    var id: String { rawValue }

    static let analysisTabs: [Screen] = [
        .folders,
        .largest,
        .duplicates,
        .cleanup
    ]

    var isAnalysisTab: Bool {
        Self.analysisTabs.contains(self)
    }

    var icon: String {
        switch self {
        case .folders: return "folder.fill"
        case .overview: return "chart.bar.xaxis"
        case .applications: return "square.grid.2x2.fill"
        case .largest: return "list.number"
        case .duplicates: return "rectangle.on.rectangle.angled"
        case .cleanup: return "sparkles"
        }
    }
}

struct ContentView: View {
    @EnvironmentObject private var model: AnalyzerModel
    @State private var screen: Screen = .overview

    var body: some View {
        HSplitView {
            SidebarView(screen: $screen)
                .frame(minWidth: 210, idealWidth: 235, maxWidth: 280)

            VStack(spacing: 0) {
                HeaderView(screen: screen)
                Divider()

                if screen.isAnalysisTab {
                    AnalysisTabBar(screen: $screen)
                    Divider()
                }

                Group {
                    if screen == .overview {
                        OverviewView()
                    } else if screen == .applications {
                        ApplicationsView()
                    } else if model.result == nil && !model.isScanning {
                        WelcomeView()
                    } else {
                        switch screen {
                        case .folders:
                            FolderBrowserView()
                                .id(model.result?.rootURL.standardizedFileURL.path)
                        case .overview: EmptyView()
                        case .applications: EmptyView()
                        case .largest: LargestFilesView()
                        case .duplicates: DuplicatesView()
                        case .cleanup: CleanupView()
                        }
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .background(Color(nsColor: .windowBackgroundColor))
        }
        .alert("In den Papierkorb bewegen?", isPresented: $model.showTrashConfirmation) {
            Button("Abbrechen", role: .cancel) {}
            Button("Verschieben", role: .destructive) {
                model.confirmTrash()
            }
        } message: {
            if model.pendingTrashItems.count == 1, let item = model.pendingTrashItems.first {
                Text(
                    L10n.format(
                        "trash.confirm.single",
                        language: model.language,
                        item.name,
                        ByteText.string(item.logicalBytes)
                    )
                )
            } else if !model.pendingTrashItems.isEmpty {
                Text(
                    L10n.format(
                        "trash.confirm.multiple",
                        language: model.language,
                        model.pendingTrashItems.count,
                        ByteText.string(model.pendingTrashItems.reduce(0) { $0 + $1.logicalBytes })
                    )
                )
            }
        }
        .alert("Hinweis", isPresented: $model.showMessage) {
            Button("OK") {}
        } message: {
            Text(model.message)
        }
        .sheet(isPresented: $model.showAccessGuide) {
            AccessGuideView()
                .environmentObject(model)
        }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            model.refreshAccessStatus()
        }
    }
}

struct AnalysisTabBar: View {
    @Binding var screen: Screen

    var body: some View {
        HStack {
            Picker("Ansicht", selection: $screen) {
                ForEach(Screen.analysisTabs) { tab in
                    Label {
                        Text(LocalizedStringKey(tab.rawValue))
                    } icon: {
                        Image(systemName: tab.icon)
                    }
                    .tag(tab)
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .frame(maxWidth: 680)

            Spacer()
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 10)
        .background(.bar)
    }
}

struct SidebarView: View {
    @EnvironmentObject private var model: AnalyzerModel
    @Binding var screen: Screen

    var body: some View {
        VStack(spacing: 0) {
            List {
                Section("Übersicht") {
                    Button {
                        screen = .overview
                    } label: {
                        SidebarRow(
                            title: Screen.overview.rawValue,
                            icon: Screen.overview.icon,
                            selected: screen == .overview
                        )
                    }
                    .buttonStyle(.plain)
                }

                Section("Speicher") {
                    ForEach(model.storageLocations) { location in
                        locationButton(location)
                    }
                }

                Section("Ordner") {
                    Button {
                        screen = .applications
                    } label: {
                        SidebarRow(
                            title: Screen.applications.rawValue,
                            icon: Screen.applications.icon,
                            selected: screen == .applications
                        )
                    }
                    .buttonStyle(.plain)

                    ForEach(model.folderLocations) { location in
                        locationButton(location)
                    }

                    Button {
                        model.chooseFolder()
                        screen = .folders
                    } label: {
                        SidebarRow(
                            title: "Ordner auswählen …",
                            icon: "folder.badge.plus",
                            selected: false
                        )
                    }
                    .buttonStyle(.plain)
                }

                if !model.externalLocations.isEmpty {
                    Section("Externe Laufwerke") {
                        ForEach(model.externalLocations) { location in
                            locationButton(location)
                        }
                    }
                }
            }
            .listStyle(.sidebar)

            Divider()

            VStack(alignment: .leading, spacing: 6) {
                Label("Nur lokale Analyse", systemImage: "lock.shield")
                    .font(.caption.weight(.semibold))
                Text("Keine Daten verlassen diesen Mac.")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                if !model.hasFullDiskAccess {
                    Button("Zugriff einrichten …") {
                        model.showAccessGuide = true
                    }
                    .font(.caption)
                    .buttonStyle(.link)
                }

                Divider()

                HStack {
                    Link("Entwickelt von DADAKAEV", destination: URL(string: "https://dadakaev.com")!)
                        .font(.caption2)

                    Spacer()

                    Menu {
                        ForEach(AppLanguage.allCases) { language in
                            Button {
                                model.language = language
                            } label: {
                                if model.language == language {
                                    Label(language.title, systemImage: "checkmark")
                                } else {
                                    Text(language.title)
                                }
                            }
                        }
                    } label: {
                        Image(systemName: "globe")
                    }
                    .menuStyle(.borderlessButton)
                    .help("Sprache")
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.bar)
        }
    }

    private func locationButton(_ location: ScanLocation) -> some View {
        Button {
            model.selectLocation(location.url)
            screen = .folders
        } label: {
            SidebarRow(
                title: location.name,
                icon: location.icon,
                selected: screen.isAnalysisTab && model.isSelected(location.url),
                showsProgress: model.isScanningLocation(location.url),
                showsCachedResult: model.hasCachedResult(for: location.url)
            )
        }
        .buttonStyle(.plain)
    }
}

struct FolderBrowserView: View {
    @EnvironmentObject private var model: AnalyzerModel
    @State private var currentURL: URL?
    @State private var selectedIDs: Set<String> = []
    @State private var searchText = ""

    private var rootURL: URL? {
        model.result?.rootURL.standardizedFileURL
    }

    private var activeURL: URL? {
        currentURL ?? rootURL
    }

    private var allItems: [StorageItem] {
        guard let activeURL else { return [] }
        return model.items(in: activeURL)
    }

    private var visibleItems: [StorageItem] {
        guard !searchText.isEmpty else { return allItems }
        return allItems.filter {
            $0.name.localizedCaseInsensitiveContains(searchText)
        }
    }

    private var selectedItems: [StorageItem] {
        allItems.filter { selectedIDs.contains($0.id) }
    }

    private var selectedBytes: Int64 {
        selectedItems.reduce(0) { $0 + $1.logicalBytes }
    }

    var body: some View {
        VStack(spacing: 0) {
            if model.isScanning {
                ScanBanner()
                    .padding()
            }

            browserToolbar
            Divider()

            if visibleItems.isEmpty {
                EmptyStateView(
                    L10n.string(
                        searchText.isEmpty ? "Ordner ist leer" : "Keine Treffer",
                        language: model.language
                    ),
                    systemImage: searchText.isEmpty ? "folder" : "magnifyingglass",
                    description: L10n.string(
                        searchText.isEmpty
                            ? "In diesem Ordner wurden keine lesbaren Elemente gefunden."
                            : "Passe den Suchbegriff an.",
                        language: model.language
                    )
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVStack(spacing: 0) {
                        HStack(spacing: 12) {
                            Color.clear.frame(width: 22)
                            Text("Name")
                            Spacer()
                            Text("Geändert")
                                .frame(width: 120, alignment: .leading)
                            Text("Größe")
                                .frame(width: 110, alignment: .trailing)
                        }
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 9)

                        Divider()

                        ForEach(visibleItems) { item in
                            FolderBrowserRow(
                                item: item,
                                isSelected: selectedIDs.contains(item.id),
                                isTrashable: model.canTrash(item),
                                toggleSelection: { toggle(item) },
                                open: { open(item) }
                            )
                            Divider()
                                .padding(.leading, 50)
                        }
                    }
                }
            }

            Divider()
            selectionBar
        }
        .onAppear {
            currentURL = rootURL
        }
    }

    private var browserToolbar: some View {
        HStack(spacing: 10) {
            Button {
                goUp()
            } label: {
                Image(systemName: "chevron.left")
            }
            .disabled(activeURL == nil || activeURL == rootURL)
            .help("Eine Ebene zurück")

            if let rootURL, let activeURL {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 5) {
                        ForEach(Array(breadcrumbs(from: rootURL, to: activeURL).enumerated()), id: \.offset) { index, crumb in
                            if index > 0 {
                                Image(systemName: "chevron.right")
                                    .font(.caption2)
                                    .foregroundStyle(.tertiary)
                            }
                            Button(crumb.name) {
                                navigate(to: crumb.url)
                            }
                            .buttonStyle(.plain)
                            .font(.subheadline.weight(crumb.url == activeURL ? .semibold : .regular))
                        }
                    }
                }
            }

            Spacer()

            TextField("In diesem Ordner suchen", text: $searchText)
                .textFieldStyle(.roundedBorder)
                .frame(width: 220)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 11)
        .background(.bar)
    }

    private var selectionBar: some View {
        HStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 2) {
                Text(
                    L10n.format(
                        "selection.count",
                        language: model.language,
                        selectedItems.count
                    )
                )
                    .font(.headline)
                Text(ByteText.string(selectedBytes))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Button("Auswahl aufheben") {
                selectedIDs.removeAll()
            }
            .disabled(selectedIDs.isEmpty)

            Button(role: .destructive) {
                model.requestTrash(selectedItems)
            } label: {
                Label("In den Papierkorb …", systemImage: "trash")
            }
            .buttonStyle(.borderedProminent)
            .tint(.red)
            .disabled(selectedItems.isEmpty)
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 12)
        .background(.bar)
    }

    private func toggle(_ item: StorageItem) {
        guard model.canTrash(item) else { return }
        if selectedIDs.contains(item.id) {
            selectedIDs.remove(item.id)
        } else {
            selectedIDs.insert(item.id)
        }
    }

    private func open(_ item: StorageItem) {
        if item.isDirectory {
            navigate(to: item.url)
        } else {
            model.reveal(item)
        }
    }

    private func navigate(to url: URL) {
        currentURL = url.standardizedFileURL
        selectedIDs.removeAll()
        searchText = ""
    }

    private func goUp() {
        guard let rootURL, let activeURL, activeURL != rootURL else { return }
        let parent = activeURL.deletingLastPathComponent().standardizedFileURL
        navigate(to: parent.path.count < rootURL.path.count ? rootURL : parent)
    }

    private func breadcrumbs(from root: URL, to current: URL) -> [(name: String, url: URL)] {
        var result: [(String, URL)] = [(model.displayName(for: root), root)]
        guard current != root else { return result }

        let rootPath = root.path == "/" ? "" : root.path
        let suffix = String(current.path.dropFirst(rootPath.count))
        var working = root
        for component in suffix.split(separator: "/") {
            working.appendPathComponent(String(component), isDirectory: true)
            result.append((String(component), working.standardizedFileURL))
        }
        return result
    }
}

struct FolderBrowserRow: View {
    @EnvironmentObject private var model: AnalyzerModel
    let item: StorageItem
    let isSelected: Bool
    let isTrashable: Bool
    let toggleSelection: () -> Void
    let open: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Button(action: toggleSelection) {
                Image(systemName: isTrashable ? (isSelected ? "checkmark.square.fill" : "square") : "lock.fill")
                    .foregroundStyle(isTrashable ? (isSelected ? Color.accentColor : Color.secondary) : Color.secondary.opacity(0.55))
                    .frame(width: 22)
            }
            .buttonStyle(.plain)
            .disabled(!isTrashable)
            .help(
                L10n.string(
                    isTrashable ? "Zum Löschen markieren" : "Dieser Systembereich ist geschützt",
                    language: model.language
                )
            )

            Button(action: open) {
                HStack(spacing: 10) {
                    Image(systemName: item.isDirectory ? "folder.fill" : item.symbol)
                        .foregroundStyle(item.isDirectory ? .blue : .secondary)
                        .frame(width: 22)
                    Text(item.name)
                        .lineLimit(1)
                    if item.isDirectory {
                        Image(systemName: "chevron.right")
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }
                    Spacer()
                    Text(item.modified == .distantPast ? "–" : item.modified.formatted(date: .abbreviated, time: .omitted))
                        .foregroundStyle(.secondary)
                        .frame(width: 120, alignment: .leading)
                    Text(ByteText.string(item.logicalBytes))
                        .monospacedDigit()
                        .foregroundStyle(item.logicalBytes > 1_000_000_000 ? .orange : .secondary)
                        .frame(width: 110, alignment: .trailing)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(isSelected ? Color.accentColor.opacity(0.09) : Color.clear)
        .contextMenu {
            Button("Öffnen", action: open)
            Button("Im Finder zeigen") {
                NSWorkspace.shared.activateFileViewerSelecting([item.url])
            }
            Divider()
            Button(role: .destructive, action: toggleSelection) {
                Text(
                    L10n.string(
                        isSelected ? "Markierung entfernen" : "Zum Löschen markieren",
                        language: model.language
                    )
                )
            }
                .disabled(!isTrashable)
        }
    }
}

struct ApplicationsView: View {
    @EnvironmentObject private var model: AnalyzerModel
    @State private var searchText = ""

    private var allApplications: [StorageItem] {
        model.installedApplications
    }

    private var applications: [StorageItem] {
        guard !searchText.isEmpty else { return allApplications }
        return allApplications.filter {
            $0.name.localizedCaseInsensitiveContains(searchText)
        }
    }

    private var totalBytes: Int64 {
        allApplications.reduce(0) { $0 + $1.logicalBytes }
    }

    var body: some View {
        VStack(spacing: 0) {
            if model.isScanning {
                ScanBanner()
                    .padding()
            }

            HStack(spacing: 14) {
                ZStack {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.indigo.opacity(0.12))
                    Image(systemName: "square.grid.2x2.fill")
                        .font(.title2)
                        .foregroundStyle(.indigo)
                }
                .frame(width: 46, height: 46)

                VStack(alignment: .leading, spacing: 3) {
                    Text("Installierte Apps")
                        .font(.title3.bold())
                    if model.isScanningApplications {
                        Text(
                            L10n.format(
                                "apps.scan.progress",
                                language: model.language,
                                model.applicationScanCount,
                                ByteText.string(model.applicationScanBytes)
                            )
                        )
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    } else {
                        Text(
                            L10n.format(
                                "apps.summary",
                                language: model.language,
                                allApplications.count,
                                ByteText.string(totalBytes)
                            )
                        )
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                Spacer()

                Button {
                    model.loadApplications(force: true)
                } label: {
                    Image(systemName: "arrow.clockwise")
                }
                .disabled(model.isScanningApplications)
                .help("App-Größen neu berechnen")

                TextField("Apps suchen", text: $searchText)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 220)
            }
            .padding(16)
            .background(.bar)

            Divider()

            if model.isScanningApplications && applications.isEmpty {
                VStack(spacing: 14) {
                    ProgressView()
                        .controlSize(.large)
                    Text("Programme-Ordner werden analysiert …")
                        .font(.headline)
                    Text("Die Größe jedes App-Pakets wird direkt berechnet.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if applications.isEmpty {
                EmptyStateView(
                    "Keine Apps gefunden",
                    systemImage: "square.grid.2x2",
                    description: "In den Programme-Ordnern wurden keine lesbaren App-Pakete gefunden."
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVStack(spacing: 0) {
                        HStack {
                            Text("App")
                            Spacer()
                            Text("Speicherort")
                                .frame(width: 120, alignment: .leading)
                            Text("Größe")
                                .frame(width: 110, alignment: .trailing)
                            Color.clear.frame(width: 68)
                        }
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 18)
                        .padding(.vertical, 9)

                        Divider()

                        ForEach(applications) { app in
                            HStack(spacing: 12) {
                                Image(nsImage: NSWorkspace.shared.icon(forFile: app.url.path))
                                    .resizable()
                                    .scaledToFit()
                                    .frame(width: 34, height: 34)

                                VStack(alignment: .leading, spacing: 2) {
                                    Text(app.name.replacingOccurrences(of: ".app", with: ""))
                                        .font(.body.weight(.medium))
                                    Text(app.url.path)
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                        .lineLimit(1)
                                        .truncationMode(.middle)
                                }

                                Spacer()

                                Text(LocalizedStringKey(appLocation(app.url)))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .frame(width: 120, alignment: .leading)

                                Text(ByteText.string(app.logicalBytes))
                                    .monospacedDigit()
                                    .fontWeight(app.logicalBytes > 1_000_000_000 ? .semibold : .regular)
                                    .foregroundStyle(app.logicalBytes > 1_000_000_000 ? .orange : .secondary)
                                    .frame(width: 110, alignment: .trailing)

                                Button {
                                    model.reveal(app)
                                } label: {
                                    Image(systemName: "folder")
                                }
                                .buttonStyle(.borderless)
                                .frame(width: 30)
                                .help("Im Finder zeigen")

                                Button(role: .destructive) {
                                    model.requestTrash(app)
                                } label: {
                                    Image(systemName: model.canTrash(app) ? "trash" : "lock.fill")
                                }
                                .buttonStyle(.borderless)
                                .frame(width: 30)
                                .disabled(!model.canTrash(app))
                                .help(
                                    L10n.string(
                                        model.canTrash(app)
                                            ? "App in den Papierkorb verschieben"
                                            : "Diese System-App ist geschützt",
                                        language: model.language
                                    )
                                )
                            }
                            .padding(.horizontal, 18)
                            .padding(.vertical, 9)

                            Divider()
                                .padding(.leading, 64)
                        }
                    }
                }
            }

            Divider()

            HStack(spacing: 9) {
                Image(systemName: "info.circle")
                    .foregroundStyle(.blue)
                Text("Angezeigt wird die Größe des Programmpakets. Caches, Dokumente und App-Daten erscheinen zusätzlich an ihrem tatsächlichen Speicherort in der Ordnerstruktur.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
            }
            .padding(12)
            .background(.bar)
        }
        .onAppear {
            model.loadApplications()
        }
    }

    private func appLocation(_ url: URL) -> String {
        let path = url.standardizedFileURL.path
        if path.hasPrefix("/System/Applications/") { return "macOS" }
        if path.hasPrefix("/Applications/") { return "Programme" }
        return "Benutzer"
    }
}

struct AccessGuideView: View {
    @EnvironmentObject private var model: AnalyzerModel

    var body: some View {
        VStack(spacing: 22) {
            ZStack {
                Circle()
                    .fill(Color.blue.opacity(0.11))
                    .frame(width: 100, height: 100)
                Image(systemName: "externaldrive.fill.badge.checkmark")
                    .font(.system(size: 43))
                    .foregroundStyle(.blue)
            }

            VStack(spacing: 8) {
                Text("Einmaliger Festplattenzugriff")
                    .font(.title.bold())
                Text("Damit DiskScope Macintosh HD vollständig analysieren kann, erlaube der App einmal den Festplattenvollzugriff.")
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 490)
            }

            VStack(alignment: .leading, spacing: 13) {
                AccessStep(number: 1, text: "Öffne „Datenschutz & Sicherheit“.")
                AccessStep(number: 2, text: "Klicke auf „+“ und wähle „Programme > DiskScope“.")
                AccessStep(number: 3, text: "Aktiviere DiskScope und öffne die App anschließend einmal neu.")
            }
            .padding()
            .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 12))

            Text("macOS verlangt diese Freigabe aus Sicherheitsgründen. DiskScope überträgt keine Dateinamen oder Inhalte und löscht nichts automatisch.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 500)

            HStack {
                Button("Später") {
                    complete()
                }
                Spacer()
                Button {
                    openFullDiskAccessSettings()
                } label: {
                    Label("Systemeinstellungen öffnen", systemImage: "gear")
                }
                .buttonStyle(.borderedProminent)

                Button("Fertig") {
                    complete()
                }
            }
        }
        .padding(30)
        .frame(width: 620)
    }

    private func complete() {
        UserDefaults.standard.set(true, forKey: "DiskScopeAccessGuideCompleted")
        model.showAccessGuide = false
    }

    private func openFullDiskAccessSettings() {
        guard let url = URL(
            string: "x-apple.systempreferences:com.apple.preference.security?Privacy_AllFiles"
        ) else { return }
        NSWorkspace.shared.open(url)
    }
}

struct AccessStep: View {
    let number: Int
    let text: String

    var body: some View {
        HStack(spacing: 12) {
            Text(String(number))
                .font(.caption.bold())
                .foregroundStyle(.white)
                .frame(width: 25, height: 25)
                .background(Color.blue, in: Circle())
            Text(LocalizedStringKey(text))
        }
    }
}

struct SidebarRow: View {
    let title: String
    let icon: String
    let selected: Bool
    var showsProgress = false
    var showsCachedResult = false

    var body: some View {
        HStack(spacing: 9) {
            Image(systemName: icon)
                .frame(width: 18)
            Text(LocalizedStringKey(title))
            Spacer(minLength: 6)
            if showsProgress {
                ProgressView()
                    .controlSize(.small)
                    .tint(selected ? .white : .accentColor)
                    .accessibilityLabel(Text("Analyse läuft"))
            } else if showsCachedResult {
                Image(systemName: "checkmark.circle.fill")
                    .font(.caption)
                    .foregroundStyle(selected ? Color.white : Color.green)
                    .accessibilityLabel(Text("Analyse gespeichert"))
            }
        }
        .font(.body.weight(selected ? .semibold : .regular))
        .foregroundStyle(selected ? Color.white : Color.primary)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 9)
        .padding(.vertical, 7)
        .background(
            selected ? Color.accentColor : Color.clear,
            in: RoundedRectangle(cornerRadius: 7)
        )
        .contentShape(Rectangle())
    }
}

struct EmptyStateView: View {
    let title: String
    let systemImage: String
    let description: String

    init(_ title: String, systemImage: String, description: String) {
        self.title = title
        self.systemImage = systemImage
        self.description = description
    }

    var body: some View {
        VStack(spacing: 14) {
            Image(systemName: systemImage)
                .font(.system(size: 42, weight: .medium))
                .foregroundStyle(.secondary)

            Text(LocalizedStringKey(title))
                .font(.title2.bold())
                .multilineTextAlignment(.center)

            Text(LocalizedStringKey(description))
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 520)
        }
        .padding(28)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct HeaderView: View {
    @EnvironmentObject private var model: AnalyzerModel
    let screen: Screen

    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 11)
                    .fill(
                        LinearGradient(
                            colors: [Color.blue.opacity(0.95), Color.indigo],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                Image(systemName: "internaldrive.fill")
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(.white)
            }
            .frame(width: 44, height: 44)

            VStack(alignment: .leading, spacing: 3) {
                Text("DiskScope")
                    .font(.title2.bold())
                Text(LocalizedStringKey(headerSubtitle))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }

            Spacer()

            if model.isScanning {
                VStack(alignment: .trailing, spacing: 3) {
                    Text(
                        L10n.format(
                            "files.count",
                            language: model.language,
                            model.progress.files
                        )
                    )
                        .font(.caption.weight(.semibold))
                    Text(ByteText.string(model.progress.logicalBytes))
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                ProgressView()
                    .controlSize(.small)
                Button("Stoppen") {
                    model.cancelScan()
                }
            } else if screen.isAnalysisTab {
                Button {
                    model.chooseFolder()
                } label: {
                    Label("Ordner wählen", systemImage: "folder")
                }

                Button {
                    model.startScan()
                } label: {
                    Label("Analysieren", systemImage: "play.fill")
                }
                .buttonStyle(.borderedProminent)
                .disabled(model.selectedURL == nil)
            }
        }
        .padding(.horizontal, 22)
        .padding(.vertical, 15)
        .background(.ultraThinMaterial)
    }

    private var headerSubtitle: String {
        switch screen {
        case .overview:
            return "Macintosh HD"
        case .applications:
            return "Programme-Ordner"
        default:
            return model.selectedURL.map(model.displayName) ?? "Noch kein Speicherort ausgewählt"
        }
    }
}

struct WelcomeView: View {
    @EnvironmentObject private var model: AnalyzerModel

    var body: some View {
        VStack(spacing: 24) {
            ZStack {
                Circle()
                    .fill(Color.blue.opacity(0.09))
                    .frame(width: 140, height: 140)
                ZStack(alignment: .bottomTrailing) {
                    Image(systemName: "externaldrive.fill")
                        .font(.system(size: 54, weight: .light))
                        .foregroundStyle(.blue)
                    Image(systemName: "magnifyingglass.circle.fill")
                        .font(.system(size: 27, weight: .semibold))
                        .symbolRenderingMode(.palette)
                        .foregroundStyle(.white, .indigo)
                        .offset(x: 8, y: 6)
                }
            }

            VStack(spacing: 8) {
                Text("Bereit für die Analyse")
                    .font(.largeTitle.bold())
                Text("Wähle links einen vorgegebenen Speicherort oder nutze die freie Ordnerauswahl. DiskScope liest nur Dateigrößen und Metadaten.")
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 600)
            }

            Button {
                model.startScan()
            } label: {
                Label(
                    "\(model.selectedURL.map(model.displayName) ?? "Speicherort") analysieren",
                    systemImage: "play.fill"
                )
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .disabled(model.selectedURL == nil)

            Button("Anderen Ordner auswählen …") {
                model.chooseFolder()
            }
            .buttonStyle(.link)

            HStack(spacing: 26) {
                Feature(icon: "chart.pie", text: "Speicherübersicht")
                Feature(icon: "doc.text.magnifyingglass", text: "Größte Dateien")
                Feature(icon: "trash.slash", text: "Keine automatische Löschung")
            }
            .padding(.top, 6)
        }
        .padding(40)
    }
}

struct Feature: View {
    let icon: String
    let text: String

    var body: some View {
        Label {
            Text(LocalizedStringKey(text))
        } icon: {
            Image(systemName: icon)
        }
            .font(.caption)
            .foregroundStyle(.secondary)
    }
}

struct OverviewView: View {
    @EnvironmentObject private var model: AnalyzerModel

    private var rootResult: ScanResult? {
        guard model.result?.rootURL.standardizedFileURL.path == "/" else { return nil }
        return model.result
    }

    private var volume: VolumeInfo {
        rootResult?.volume ?? model.systemVolumeInfo()
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Mac-Übersicht")
                        .font(.largeTitle.bold())
                    Text("Gesamter Zustand des internen Mac-Speichers")
                        .foregroundStyle(.secondary)
                }

                if model.isScanning,
                   model.selectedURL?.standardizedFileURL.path == "/" {
                    ScanBanner()
                }

                LazyVGrid(columns: [GridItem(.adaptive(minimum: 190), spacing: 14)], spacing: 14) {
                    MetricCard(
                        title: "Kapazität",
                        value: ByteText.string(volume.totalBytes),
                        detail: "Gesamter interner Speicher",
                        icon: "internaldrive"
                    )
                    MetricCard(
                        title: "Belegt",
                        value: ByteText.string(max(volume.totalBytes - volume.availableBytes, 0)),
                        detail: "Aktuell verwendeter Speicher",
                        icon: "chart.pie.fill"
                    )
                    MetricCard(
                        title: "Verfügbar",
                        value: ByteText.string(volume.availableBytes),
                        detail: "Noch frei auf Macintosh HD",
                        icon: "checkmark.circle"
                    )
                    if let result = rootResult {
                        MetricCard(
                            title: "Dateien",
                            value: result.fileCount.formatted(),
                            detail: "\(result.directoryCount.formatted()) Ordner",
                            icon: "doc.fill"
                        )
                    }
                }

                VolumeCard(volume: volume)

                if let result = rootResult {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Text("Größte Bereiche")
                                .font(.title3.bold())
                            Spacer()
                            Text("Doppelklick zum Analysieren")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }

                        VStack(spacing: 7) {
                            ForEach(Array(result.topLevel.prefix(14))) { item in
                                StorageBar(
                                    item: item,
                                    maximum: max(result.topLevel.first?.logicalBytes ?? 1, 1)
                                )
                                .contentShape(Rectangle())
                                .onTapGesture(count: 2) {
                                    if item.isDirectory {
                                        model.scan(item.url)
                                    } else {
                                        model.reveal(item)
                                    }
                                }
                            }
                        }
                    }
                    .cardStyle()
                } else if !model.isScanning {
                    HStack(spacing: 14) {
                        Image(systemName: "externaldrive.badge.magnifyingglass")
                            .font(.title2)
                            .foregroundStyle(.blue)
                        VStack(alignment: .leading, spacing: 3) {
                            Text("Ordnerverteilung noch nicht berechnet")
                                .font(.headline)
                            Text("Die Laufwerkswerte sind bereits aktuell. Eine vollständige Analyse ergänzt die größten Bereiche und Dateianzahl.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Button {
                            model.scan(URL(fileURLWithPath: "/", isDirectory: true))
                        } label: {
                            Label("Macintosh HD vollständig analysieren", systemImage: "play.fill")
                        }
                        .buttonStyle(.borderedProminent)
                    }
                    .cardStyle()
                }

                HStack(alignment: .top, spacing: 10) {
                    Image(systemName: "info.circle.fill")
                        .foregroundStyle(.blue)
                    Text("Bei APFS-Klonen, komprimierten Dateien oder gemeinsam genutzten Blöcken kann die Summe pro Ordner größer als die physische SSD sein. Die Laufwerksbelegung ist dann die verlässlichere Obergrenze.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, 4)
            }
            .padding(22)
        }
    }
}

struct ScanBanner: View {
    @EnvironmentObject private var model: AnalyzerModel

    var body: some View {
        HStack(spacing: 12) {
            ProgressView()
            VStack(alignment: .leading, spacing: 2) {
                Text("Analyse läuft …")
                    .font(.headline)
                Text(
                    L10n.format(
                        "scan.progress",
                        language: model.language,
                        model.progress.files,
                        ByteText.string(model.progress.logicalBytes)
                    )
                )
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding()
        .background(Color.blue.opacity(0.08), in: RoundedRectangle(cornerRadius: 12))
    }
}

struct MetricCard: View {
    let title: String
    let value: String
    let detail: String
    let icon: String

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: icon)
                    .foregroundStyle(.blue)
                Spacer()
            }
            Text(value)
                .font(.system(size: 24, weight: .bold, design: .rounded))
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            VStack(alignment: .leading, spacing: 2) {
                Text(LocalizedStringKey(title))
                    .font(.subheadline.weight(.semibold))
                Text(LocalizedStringKey(detail))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardStyle()
    }
}

struct VolumeCard: View {
    @EnvironmentObject private var model: AnalyzerModel
    let volume: VolumeInfo

    var usedFraction: Double {
        guard volume.totalBytes > 0 else { return 0 }
        return min(max(Double(volume.totalBytes - volume.availableBytes) / Double(volume.totalBytes), 0), 1)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("Laufwerk", systemImage: "internaldrive.fill")
                    .font(.headline)
                Spacer()
                Text(
                    L10n.format(
                        "volume.free",
                        language: model.language,
                        ByteText.string(volume.availableBytes)
                    )
                )
                    .font(.subheadline.weight(.semibold))
            }

            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.secondary.opacity(0.14))
                    Capsule()
                        .fill(
                            LinearGradient(
                                colors: usedFraction > 0.9 ? [.orange, .red] : [.blue, .indigo],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: proxy.size.width * usedFraction)
                }
            }
            .frame(height: 10)

            HStack {
                Text(volume.name)
                Spacer()
                Text(
                    L10n.format(
                        "volume.used",
                        language: model.language,
                        ByteText.string(volume.totalBytes - volume.availableBytes),
                        ByteText.string(volume.totalBytes)
                    )
                )
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        .cardStyle()
    }
}

struct StorageBar: View {
    @EnvironmentObject private var model: AnalyzerModel
    let item: StorageItem
    let maximum: Int64

    var fraction: Double {
        min(max(Double(item.logicalBytes) / Double(maximum), 0.015), 1)
    }

    var body: some View {
        VStack(spacing: 5) {
            HStack(spacing: 9) {
                Image(systemName: item.isDirectory ? "folder.fill" : item.symbol)
                    .foregroundStyle(item.isDirectory ? .blue : .secondary)
                    .frame(width: 18)
                Text(item.name)
                    .lineLimit(1)
                Spacer()
                Text(ByteText.string(item.logicalBytes))
                    .font(.system(.body, design: .monospaced))
                    .foregroundStyle(.secondary)
            }
            GeometryReader { proxy in
                Capsule()
                    .fill(Color.blue.opacity(0.2))
                    .overlay(alignment: .leading) {
                        Capsule()
                            .fill(Color.blue)
                            .frame(width: proxy.size.width * fraction)
                    }
            }
            .frame(height: 5)
        }
        .padding(.vertical, 5)
        .contextMenu {
            Button("Im Finder zeigen") { model.reveal(item) }
            if item.isDirectory {
                Button("Diesen Ordner analysieren") { model.scan(item.url) }
            }
            Divider()
            Button("In den Papierkorb …", role: .destructive) {
                model.requestTrash(item)
            }
            .disabled(!model.canTrash(item))
        }
    }
}

struct LargestFilesView: View {
    @EnvironmentObject private var model: AnalyzerModel
    @State private var selectedID: StorageItem.ID?

    var selectedItem: StorageItem? {
        model.result?.largestFiles.first { $0.id == selectedID }
    }

    var body: some View {
        VStack(spacing: 0) {
            if model.isScanning {
                ScanBanner()
                    .padding()
            }

            if let files = model.result?.largestFiles {
                Table(files, selection: $selectedID) {
                    TableColumn("Name") { item in
                        HStack {
                            Image(systemName: item.symbol)
                                .foregroundStyle(.secondary)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(item.name)
                                Text(item.url.deletingLastPathComponent().path)
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)
                            }
                        }
                    }
                    .width(min: 300, ideal: 470)

                    TableColumn("Größe") { item in
                        Text(ByteText.string(item.logicalBytes))
                            .monospacedDigit()
                    }
                    .width(105)

                    TableColumn("Auf SSD") { item in
                        Text(ByteText.string(item.allocatedBytes))
                            .monospacedDigit()
                            .foregroundStyle(.secondary)
                    }
                    .width(105)

                    TableColumn("Geändert") { item in
                        Text(item.modified, format: .dateTime.day().month().year())
                            .foregroundStyle(.secondary)
                    }
                    .width(105)
                }

                HStack {
                    Text(
                        L10n.format(
                            "largest_files.count",
                            language: model.language,
                            files.count
                        )
                    )
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Button("Im Finder zeigen") {
                        if let selectedItem { model.reveal(selectedItem) }
                    }
                    .disabled(selectedItem == nil)
                    Button("In den Papierkorb …", role: .destructive) {
                        if let selectedItem { model.requestTrash(selectedItem) }
                    }
                    .disabled(selectedItem.map { !model.canTrash($0) } ?? true)
                }
                .padding(12)
                .background(.bar)
            }
        }
    }
}

struct CleanupView: View {
    @EnvironmentObject private var model: AnalyzerModel
    @State private var selectedID: StorageItem.ID?

    var selectedItem: StorageItem? {
        model.result?.cleanupCandidates.first { $0.id == selectedID }
    }

    var body: some View {
        VStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: "sparkles")
                        .font(.title2)
                        .foregroundStyle(.blue)
                    VStack(alignment: .leading) {
                        Text("Mögliche Aufräumkandidaten")
                            .font(.title3.bold())
                        Text("Nur Hinweise – DiskScope löscht niemals automatisch.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    if let candidates = model.result?.cleanupCandidates {
                        Text(ByteText.string(candidates.reduce(0) { $0 + $1.logicalBytes }))
                            .font(.title3.bold())
                    }
                }
            }
            .padding(18)

            Divider()

            if let candidates = model.result?.cleanupCandidates, !candidates.isEmpty {
                Table(candidates, selection: $selectedID) {
                    TableColumn("Kandidat") { item in
                        HStack {
                            Image(systemName: item.cleanupKind?.symbol ?? "doc")
                                .foregroundStyle(item.cleanupKind?.color ?? .secondary)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(item.name)
                                Text(item.url.path)
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)
                            }
                        }
                    }
                    .width(min: 360, ideal: 560)

                    TableColumn("Kategorie") { item in
                        Text(LocalizedStringKey(item.cleanupKind?.title ?? "Prüfen"))
                    }
                    .width(115)

                    TableColumn("Größe") { item in
                        Text(ByteText.string(item.logicalBytes))
                            .monospacedDigit()
                    }
                    .width(110)
                }

                HStack {
                    Label("System- und aktive App-Daten werden bewusst nicht automatisch vorgeschlagen.", systemImage: "shield")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Button("Im Finder zeigen") {
                        if let selectedItem { model.reveal(selectedItem) }
                    }
                    .disabled(selectedItem == nil)
                    Button("In den Papierkorb …", role: .destructive) {
                        if let selectedItem { model.requestTrash(selectedItem) }
                    }
                    .disabled(selectedItem.map { !model.canTrash($0) } ?? true)
                }
                .padding(12)
                .background(.bar)
            } else {
                EmptyStateView(
                    "Keine eindeutigen Kandidaten",
                    systemImage: "checkmark.circle",
                    description: "In diesem Scan wurden keine großen Cache-, Protokoll- oder temporären Dateien erkannt."
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }
}

struct DuplicatesView: View {
    @EnvironmentObject private var model: AnalyzerModel

    var groups: [DuplicateGroup] {
        model.result?.duplicateGroups ?? []
    }

    var reclaimableBytes: Int64 {
        groups.reduce(0) { $0 + $1.reclaimableBytes }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                HStack(spacing: 14) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.purple.opacity(0.12))
                        Image(systemName: "rectangle.on.rectangle.angled")
                            .font(.title2)
                            .foregroundStyle(.purple)
                    }
                    .frame(width: 48, height: 48)

                    VStack(alignment: .leading, spacing: 3) {
                        Text("Mögliche Duplikate")
                            .font(.title3.bold())
                        Text("Gleiche Namen werden immer angezeigt; gleiche exakte Größe erhöht die Trefferqualität.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    VStack(alignment: .trailing, spacing: 2) {
                        Text(ByteText.string(reclaimableBytes))
                            .font(.title2.bold())
                        Text("möglicherweise freigebbar")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
                .cardStyle()

                if groups.isEmpty {
                    EmptyStateView(
                        "Keine möglichen Duplikate",
                        systemImage: "checkmark.circle",
                        description: "Es wurden keine Dateien ab 1 MB mit gleichem Namen gefunden."
                    )
                    .frame(maxWidth: .infinity)
                    .padding(.top, 70)
                } else {
                    LazyVStack(spacing: 10) {
                        ForEach(groups.prefix(250)) { group in
                            DuplicateGroupCard(group: group)
                        }
                    }
                }

                HStack(alignment: .top, spacing: 9) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(.orange)
                    Text("Name und Größe sind ein schneller Vorabvergleich, aber kein vollständiger Inhaltsnachweis. Prüfe die Dateien vor dem Löschen im Finder.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, 4)
            }
            .padding(22)
        }
    }
}

struct DuplicateGroupCard: View {
    @EnvironmentObject private var model: AnalyzerModel
    let group: DuplicateGroup

    var body: some View {
        VStack(alignment: .leading, spacing: 11) {
            HStack {
                Image(systemName: group.items.first?.symbol ?? "doc.on.doc")
                    .foregroundStyle(.purple)
                Text(group.name)
                    .font(.headline)
                    .lineLimit(1)
                Spacer()
                Text(group.sizeSummary(language: model.language))
                    .font(.system(.subheadline, design: .monospaced))
                    .foregroundStyle(.secondary)
            }

            Label {
                Text(
                    L10n.string(
                        group.hasExactSizeMatch
                            ? "duplicate.status.exact_size"
                            : "duplicate.status.different_sizes",
                        language: model.language
                    )
                )
            } icon: {
                Image(
                    systemName: group.hasExactSizeMatch
                        ? "checkmark.seal.fill"
                        : "exclamationmark.circle"
                )
            }
            .font(.caption.weight(.medium))
            .foregroundStyle(group.hasExactSizeMatch ? .green : .orange)

            ForEach(group.items.prefix(8)) { item in
                HStack(spacing: 9) {
                    Image(systemName: "folder")
                        .foregroundStyle(.secondary)
                    Text(item.url.deletingLastPathComponent().path)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                    Spacer()
                    Text(ByteText.string(item.logicalBytes))
                        .font(.caption2.monospacedDigit())
                        .foregroundStyle(.secondary)
                    Button {
                        model.reveal(item)
                    } label: {
                        Image(systemName: "arrow.right.circle")
                    }
                    .buttonStyle(.borderless)
                    .help("Im Finder zeigen")

                    Button(role: .destructive) {
                        model.requestTrash(item)
                    } label: {
                        Image(systemName: "trash")
                    }
                    .buttonStyle(.borderless)
                    .disabled(!model.canTrash(item))
                    .help("In den Papierkorb verschieben")
                }
            }

            if group.items.count > 8 {
                Text(
                    L10n.format(
                        "duplicate.more_paths",
                        language: model.language,
                        group.items.count - 8
                    )
                )
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .cardStyle()
    }
}

extension View {
    func cardStyle() -> some View {
        self
            .padding(16)
            .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 14))
            .overlay {
                RoundedRectangle(cornerRadius: 14)
                    .stroke(Color.secondary.opacity(0.12), lineWidth: 1)
            }
    }
}

struct ScanProgress: Sendable {
    var files: Int = 0
    var logicalBytes: Int64 = 0
}

struct ScanResult: Sendable {
    let rootURL: URL
    let logicalBytes: Int64
    let allocatedBytes: Int64
    let fileCount: Int
    let directoryCount: Int
    let errorCount: Int
    let topLevel: [StorageItem]
    let largestFiles: [StorageItem]
    let duplicateGroups: [DuplicateGroup]
    let cleanupCandidates: [StorageItem]
    let folderSummaries: [String: FolderSummary]
    let volume: VolumeInfo
}

struct FolderSummary: Sendable {
    var logicalBytes: Int64 = 0
    var allocatedBytes: Int64 = 0
    var modified: Date = .distantPast

    mutating func add(logical: Int64, allocated: Int64, modified date: Date) {
        logicalBytes += logical
        allocatedBytes += allocated
        modified = max(modified, date)
    }

    mutating func add(_ child: FolderSummary) {
        logicalBytes += child.logicalBytes
        allocatedBytes += child.allocatedBytes
        modified = max(modified, child.modified)
    }
}

struct VolumeInfo: Sendable {
    let name: String
    let totalBytes: Int64
    let availableBytes: Int64
}

struct ScanLocation: Identifiable, Hashable, Sendable {
    let name: String
    let url: URL
    let icon: String

    var id: String { url.standardizedFileURL.path }
}

struct DuplicateGroup: Identifiable, Hashable, Sendable {
    let name: String
    let items: [StorageItem]

    var id: String { name.lowercased() }

    var sizeGroups: [Int64: [StorageItem]] {
        Dictionary(grouping: items, by: \.logicalBytes)
    }

    var hasExactSizeMatch: Bool {
        sizeGroups.values.contains { $0.count > 1 }
    }

    var reclaimableBytes: Int64 {
        sizeGroups.reduce(0) { total, entry in
            let (bytes, matches) = entry
            return total + bytes * Int64(max(matches.count - 1, 0))
        }
    }

    func sizeSummary(language: AppLanguage) -> String {
        if sizeGroups.count == 1, let bytes = items.first?.logicalBytes {
            return "\(items.count) × \(ByteText.string(bytes))"
        }
        return L10n.format(
            "duplicate.summary.different_sizes",
            language: language,
            items.count
        )
    }
}

enum CleanupKind: String, Sendable {
    case cache
    case temporary
    case log
    case download
    case model

    var title: String {
        switch self {
        case .cache: return "Cache"
        case .temporary: return "Temporär"
        case .log: return "Protokoll"
        case .download: return "Download"
        case .model: return "KI-Modell"
        }
    }

    var symbol: String {
        switch self {
        case .cache: return "shippingbox"
        case .temporary: return "clock.arrow.circlepath"
        case .log: return "doc.text"
        case .download: return "arrow.down.circle"
        case .model: return "brain"
        }
    }

    var color: Color {
        switch self {
        case .cache: return .blue
        case .temporary: return .orange
        case .log: return .gray
        case .download: return .green
        case .model: return .purple
        }
    }
}

struct StorageItem: Identifiable, Hashable, Sendable {
    let id: String
    let url: URL
    let name: String
    let logicalBytes: Int64
    let allocatedBytes: Int64
    let modified: Date
    let isDirectory: Bool
    let cleanupKind: CleanupKind?

    var symbol: String {
        let ext = url.pathExtension.lowercased()
        if ["jpg", "jpeg", "png", "gif", "heic", "webp"].contains(ext) { return "photo" }
        if ["mov", "mp4", "mkv", "avi"].contains(ext) { return "film" }
        if ["mp3", "wav", "opus", "m4a", "aac"].contains(ext) { return "waveform" }
        if ["zip", "gz", "tar", "7z", "dmg", "pkg"].contains(ext) { return "archivebox" }
        if ["pdf"].contains(ext) { return "doc.richtext" }
        return "doc"
    }
}

struct Bucket {
    var url: URL
    var logicalBytes: Int64 = 0
    var allocatedBytes: Int64 = 0
    var modified: Date = .distantPast
    var isDirectory: Bool = true
}

enum ByteText {
    static let formatter: ByteCountFormatter = {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        formatter.allowedUnits = [.useKB, .useMB, .useGB, .useTB]
        formatter.includesUnit = true
        formatter.isAdaptive = true
        return formatter
    }()

    static func string(_ bytes: Int64) -> String {
        formatter.string(fromByteCount: bytes)
    }
}

final class CancellationFlag: @unchecked Sendable {
    private let lock = NSLock()
    private var cancelled = false

    func cancel() {
        lock.lock()
        cancelled = true
        lock.unlock()
    }

    var isCancelled: Bool {
        lock.lock()
        defer { lock.unlock() }
        return cancelled
    }
}

enum ScannerError: LocalizedError {
    case cannotEnumerate

    var errorDescription: String? {
        "Der ausgewählte Ordner konnte nicht gelesen werden."
    }
}

enum DirectoryScanner {
    static func cleanupKindForDisplay(_ url: URL) -> CleanupKind? {
        cleanupKind(for: url)
    }

    static func scan(
        root: URL,
        cancellation: CancellationFlag,
        progress: @escaping @Sendable (ScanProgress) async -> Void
    ) async throws -> ScanResult {
        let manager = FileManager.default
        var logical: Int64 = 0
        var allocated: Int64 = 0
        var files = 0
        var directories = 0
        var errors = 0
        var buckets: [String: Bucket] = [:]
        var largest: [StorageItem] = []
        var cleanup: [StorageItem] = []
        var duplicateFirst: [String: StorageItem] = [:]
        var duplicateMatches: [String: [StorageItem]] = [:]
        let rootPath = root.standardizedFileURL.path
        let prefix = rootPath.hasSuffix("/") ? rootPath : rootPath + "/"
        var directoryStack = [root.standardizedFileURL]
        var folderSummaries: [String: FolderSummary] = [rootPath: FolderSummary()]

        while let directory = directoryStack.popLast() {
            if cancellation.isCancelled { break }
            let directoryPath = directory.standardizedFileURL.path
            if folderSummaries[directoryPath] == nil {
                folderSummaries[directoryPath] = FolderSummary()
            }

            guard let directoryHandle = Darwin.opendir(directory.path) else {
                errors += 1
                continue
            }

            while let entry = Darwin.readdir(directoryHandle) {
                if cancellation.isCancelled { break }

                let name = withUnsafePointer(to: &entry.pointee.d_name) { namePointer in
                    namePointer.withMemoryRebound(
                        to: CChar.self,
                        capacity: Int(entry.pointee.d_namlen) + 1
                    ) {
                        String(cString: $0)
                    }
                }
                if name == "." || name == ".." { continue }

                let directoryPath = directory.path
                let path = directoryPath == "/" ? "/" + name : directoryPath + "/" + name
                let url = URL(fileURLWithPath: path)

                var metadata = stat()
                let status = url.withUnsafeFileSystemRepresentation { pathPointer -> Int32 in
                    guard let pathPointer else { return -1 }
                    return Darwin.lstat(pathPointer, &metadata)
                }
                guard status == 0 else {
                    errors += 1
                    continue
                }

                let fileType = metadata.st_mode & mode_t(S_IFMT)
                if fileType == mode_t(S_IFLNK) { continue }
                if fileType == mode_t(S_IFDIR) {
                    directories += 1
                    if folderSummaries[path] == nil {
                        folderSummaries[path] = FolderSummary()
                    }
                    if !shouldSkipDescendants(root: root, directory: url) {
                        directoryStack.append(url)
                    }
                    continue
                }
                guard fileType == mode_t(S_IFREG) else { continue }

                let logicalSize = Int64(metadata.st_size)
                let allocatedSize = Int64(metadata.st_blocks) * 512
                let modified = Date(timeIntervalSince1970: TimeInterval(metadata.st_mtimespec.tv_sec))

                files += 1
                logical += logicalSize
                allocated += allocatedSize
                var directSummary = folderSummaries[directoryPath] ?? FolderSummary()
                directSummary.add(logical: logicalSize, allocated: allocatedSize, modified: modified)
                folderSummaries[directoryPath] = directSummary

                let relative = path.hasPrefix(prefix) ? String(path.dropFirst(prefix.count)) : name
                let first = relative.split(separator: "/", maxSplits: 1).first.map(String.init) ?? name
                let bucketURL = root.appendingPathComponent(first)
                var bucket = buckets[first] ?? Bucket(url: bucketURL)
                bucket.logicalBytes += logicalSize
                bucket.allocatedBytes += allocatedSize
                bucket.modified = max(bucket.modified, modified)
                if relative == first {
                    bucket.isDirectory = false
                }
                buckets[first] = bucket

                let kind = cleanupKind(for: url)
                let item = StorageItem(
                    id: path,
                    url: url,
                    name: name,
                    logicalBytes: logicalSize,
                    allocatedBytes: allocatedSize,
                    modified: modified,
                    isDirectory: false,
                    cleanupKind: kind
                )
                insert(item, into: &largest, limit: 250)

                if logicalSize >= 25 * 1024 * 1024, kind != nil, !isProtectedCleanupPath(url) {
                    insert(item, into: &cleanup, limit: 250)
                }

                if logicalSize >= 1 * 1024 * 1024 {
                    let duplicateKey = name.lowercased()
                    if var matches = duplicateMatches[duplicateKey] {
                        matches.append(item)
                        duplicateMatches[duplicateKey] = matches
                    } else if let first = duplicateFirst.removeValue(forKey: duplicateKey) {
                        duplicateMatches[duplicateKey] = [first, item]
                    } else {
                        duplicateFirst[duplicateKey] = item
                    }
                }

                if files % 5_000 == 0 {
                    await progress(ScanProgress(files: files, logicalBytes: logical))
                }
            }

            Darwin.closedir(directoryHandle)
        }

        await progress(ScanProgress(files: files, logicalBytes: logical))

        let pathsByDepth = folderSummaries.keys.sorted {
            $0.split(separator: "/").count > $1.split(separator: "/").count
        }
        for path in pathsByDepth where path != rootPath {
            let parentPath = URL(fileURLWithPath: path, isDirectory: true)
                .deletingLastPathComponent()
                .standardizedFileURL
                .path
            let parentIsInsideRoot = parentPath == rootPath
                || (rootPath == "/" ? parentPath.hasPrefix("/") : parentPath.hasPrefix(prefix))
            guard parentIsInsideRoot, let child = folderSummaries[path] else { continue }
            var parent = folderSummaries[parentPath] ?? FolderSummary()
            parent.add(child)
            folderSummaries[parentPath] = parent
        }

        let topLevel = buckets.values.map { bucket in
            var isDirectory: ObjCBool = false
            let exists = manager.fileExists(atPath: bucket.url.path, isDirectory: &isDirectory)
            return StorageItem(
                id: bucket.url.path,
                url: bucket.url,
                name: bucket.url.lastPathComponent,
                logicalBytes: bucket.logicalBytes,
                allocatedBytes: bucket.allocatedBytes,
                modified: bucket.modified,
                isDirectory: bucket.isDirectory || (exists && isDirectory.boolValue),
                cleanupKind: cleanupKind(for: bucket.url)
            )
        }
        .sorted { $0.logicalBytes > $1.logicalBytes }

        let volumeValues = try? root.resourceValues(forKeys: [
            .volumeNameKey,
            .volumeTotalCapacityKey,
            .volumeAvailableCapacityForImportantUsageKey
        ])
        let volume = VolumeInfo(
            name: volumeValues?.volumeName ?? "Macintosh HD",
            totalBytes: Int64(volumeValues?.volumeTotalCapacity ?? 0),
            availableBytes: volumeValues?.volumeAvailableCapacityForImportantUsage ?? 0
        )
        let duplicates = duplicateMatches.map { key, items in
            DuplicateGroup(
                name: items.first?.name ?? key,
                items: items.sorted {
                    $0.url.path.localizedStandardCompare($1.url.path) == .orderedAscending
                }
            )
        }
        .sorted { $0.reclaimableBytes > $1.reclaimableBytes }

        return ScanResult(
            rootURL: root,
            logicalBytes: logical,
            allocatedBytes: allocated,
            fileCount: files,
            directoryCount: directories,
            errorCount: errors,
            topLevel: topLevel,
            largestFiles: largest.sorted { $0.logicalBytes > $1.logicalBytes },
            duplicateGroups: duplicates,
            cleanupCandidates: cleanup.sorted { $0.logicalBytes > $1.logicalBytes },
            folderSummaries: folderSummaries,
            volume: volume
        )
    }

    private static func insert(_ item: StorageItem, into list: inout [StorageItem], limit: Int) {
        if list.count < limit {
            list.append(item)
        } else if let smallestIndex = list.indices.min(by: { list[$0].logicalBytes < list[$1].logicalBytes }),
                  item.logicalBytes > list[smallestIndex].logicalBytes {
            list[smallestIndex] = item
        }
    }

    private static func cleanupKind(for url: URL) -> CleanupKind? {
        let path = url.path.lowercased()
        if path.contains("/library/caches/") || path.contains("/.cache/") { return .cache }
        if path.contains("/private/tmp/") || path.contains("/var/tmp/") { return .temporary }
        if path.contains("/optguideondevicemodel/") { return .model }
        if path.contains("/downloads/") { return .download }
        if ["log", "trace"].contains(url.pathExtension.lowercased()) { return .log }
        return nil
    }

    private static func isProtectedCleanupPath(_ url: URL) -> Bool {
        let path = url.path.lowercased()
        return path.hasPrefix("/system/")
            || path.hasPrefix("/library/updates/")
            || path.contains("/library/caches/com.apple.")
    }

    private static func shouldSkipDescendants(root: URL, directory: URL) -> Bool {
        guard root.standardizedFileURL.path == "/" else { return false }
        let path = directory.standardizedFileURL.path
        return path == "/dev"
            || path == "/Network"
            || path == "/Volumes"
            || path == "/System/Volumes"
    }
}

enum ApplicationScanner {
    static func scan(
        cancellation: CancellationFlag,
        progress: @escaping @Sendable (Int, Int64) async -> Void
    ) async -> [StorageItem] {
        let manager = FileManager.default
        let roots = [
            URL(fileURLWithPath: "/Applications", isDirectory: true),
            URL(fileURLWithPath: "/System/Applications", isDirectory: true),
            manager.homeDirectoryForCurrentUser.appendingPathComponent("Applications", isDirectory: true)
        ].filter { manager.fileExists(atPath: $0.path) }

        var searchStack = roots
        var applications: [StorageItem] = []
        var totalBytes: Int64 = 0

        while let directory = searchStack.popLast() {
            if cancellation.isCancelled { break }
            guard let directoryHandle = Darwin.opendir(directory.path) else { continue }

            while let entry = Darwin.readdir(directoryHandle) {
                if cancellation.isCancelled { break }

                let name = withUnsafePointer(to: &entry.pointee.d_name) { namePointer in
                    namePointer.withMemoryRebound(
                        to: CChar.self,
                        capacity: Int(entry.pointee.d_namlen) + 1
                    ) {
                        String(cString: $0)
                    }
                }
                if name == "." || name == ".." { continue }

                let url = directory.appendingPathComponent(name, isDirectory: true)
                var metadata = stat()
                let status = url.withUnsafeFileSystemRepresentation { pathPointer -> Int32 in
                    guard let pathPointer else { return -1 }
                    return Darwin.lstat(pathPointer, &metadata)
                }
                guard status == 0 else { continue }

                let fileType = metadata.st_mode & mode_t(S_IFMT)
                guard fileType == mode_t(S_IFDIR) else { continue }

                if url.pathExtension.lowercased() == "app" {
                    guard let summary = measureBundle(url, cancellation: cancellation) else { continue }
                    let modified = Date(timeIntervalSince1970: TimeInterval(metadata.st_mtimespec.tv_sec))
                    applications.append(
                        StorageItem(
                            id: url.standardizedFileURL.path,
                            url: url,
                            name: name,
                            logicalBytes: summary.logical,
                            allocatedBytes: summary.allocated,
                            modified: modified,
                            isDirectory: true,
                            cleanupKind: nil
                        )
                    )
                    totalBytes += summary.logical
                    await progress(applications.count, totalBytes)
                } else {
                    searchStack.append(url)
                }
            }

            Darwin.closedir(directoryHandle)
        }

        return applications.sorted {
            if $0.logicalBytes != $1.logicalBytes {
                return $0.logicalBytes > $1.logicalBytes
            }
            return $0.name.localizedStandardCompare($1.name) == .orderedAscending
        }
    }

    private static func measureBundle(
        _ root: URL,
        cancellation: CancellationFlag
    ) -> (logical: Int64, allocated: Int64)? {
        var stack = [root]
        var logical: Int64 = 0
        var allocated: Int64 = 0
        var openedRoot = false

        while let directory = stack.popLast() {
            if cancellation.isCancelled { return nil }
            guard let directoryHandle = Darwin.opendir(directory.path) else {
                if directory == root { return nil }
                continue
            }
            if directory == root { openedRoot = true }

            while let entry = Darwin.readdir(directoryHandle) {
                if cancellation.isCancelled {
                    Darwin.closedir(directoryHandle)
                    return nil
                }

                let name = withUnsafePointer(to: &entry.pointee.d_name) { namePointer in
                    namePointer.withMemoryRebound(
                        to: CChar.self,
                        capacity: Int(entry.pointee.d_namlen) + 1
                    ) {
                        String(cString: $0)
                    }
                }
                if name == "." || name == ".." { continue }

                let url = directory.appendingPathComponent(name)
                var metadata = stat()
                let status = url.withUnsafeFileSystemRepresentation { pathPointer -> Int32 in
                    guard let pathPointer else { return -1 }
                    return Darwin.lstat(pathPointer, &metadata)
                }
                guard status == 0 else { continue }

                let fileType = metadata.st_mode & mode_t(S_IFMT)
                if fileType == mode_t(S_IFLNK) { continue }
                if fileType == mode_t(S_IFDIR) {
                    stack.append(url)
                } else if fileType == mode_t(S_IFREG) {
                    logical += Int64(metadata.st_size)
                    allocated += Int64(metadata.st_blocks) * 512
                }
            }

            Darwin.closedir(directoryHandle)
        }

        return openedRoot ? (logical, allocated) : nil
    }
}

@MainActor
final class AnalyzerModel: ObservableObject {
    @Published var language: AppLanguage {
        didSet {
            UserDefaults.standard.set(language.rawValue, forKey: "DiskScopeLanguage")
        }
    }
    @Published var selectedURL: URL?
    @Published var result: ScanResult?
    @Published var progress = ScanProgress()
    @Published var isScanning = false
    @Published private(set) var activeScanURL: URL?
    @Published var showTrashConfirmation = false
    @Published var pendingTrashItems: [StorageItem] = []
    @Published var showMessage = false
    @Published var message = ""
    @Published var showAccessGuide = false
    @Published private(set) var hasFullDiskAccess = false
    @Published private(set) var storageLocations: [ScanLocation] = []
    @Published private(set) var folderLocations: [ScanLocation] = []
    @Published private(set) var externalLocations: [ScanLocation] = []
    @Published private(set) var installedApplications: [StorageItem] = []
    @Published private(set) var isScanningApplications = false
    @Published private(set) var applicationScanCount = 0
    @Published private(set) var applicationScanBytes: Int64 = 0
    @Published private(set) var cachedResultPaths: Set<String> = []

    private var cancellation: CancellationFlag?
    private var scanTask: Task<Void, Never>?
    private var scanActivity: NSObjectProtocol?
    private var activeScanID: UUID?
    private var applicationCancellation: CancellationFlag?
    private var applicationScanTask: Task<Void, Never>?
    private var resultCache: [String: ScanResult] = [:]
    private var resultCacheOrder: [String] = []
    private let maximumCachedResults = 5

    init() {
        language = AppLanguage(
            rawValue: UserDefaults.standard.string(forKey: "DiskScopeLanguage") ?? ""
        ) ?? .german
        selectedURL = URL(fileURLWithPath: "/", isDirectory: true)
        refreshLocations()
        hasFullDiskAccess = Self.detectFullDiskAccess()
        showAccessGuide = !hasFullDiskAccess
            && !UserDefaults.standard.bool(forKey: "DiskScopeAccessGuideCompleted")
    }

    func refreshAccessStatus() {
        let granted = Self.detectFullDiskAccess()
        hasFullDiskAccess = granted
        if granted {
            showAccessGuide = false
        }
    }

    func chooseFolder() {
        let panel = NSOpenPanel()
        panel.title = L10n.string("Ordner analysieren", language: language)
        panel.prompt = L10n.string("Auswählen", language: language)
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        panel.canCreateDirectories = false

        if panel.runModal() == .OK, let url = panel.url {
            selectLocation(url)
        }
    }

    func selectLocation(_ url: URL) {
        let standardizedURL = url.standardizedFileURL
        if selectedURL?.standardizedFileURL == standardizedURL {
            if result == nil, let cached = cachedResult(for: standardizedURL) {
                showCachedResult(cached)
            }
            return
        }

        cancelScan()
        selectedURL = standardizedURL
        if let cached = cachedResult(for: standardizedURL) {
            showCachedResult(cached)
        } else {
            result = nil
            progress = ScanProgress()
        }
    }

    func scan(_ url: URL) {
        selectedURL = url
        startScan()
    }

    func startScan() {
        guard let url = selectedURL else { return }
        cancelScan()

        let flag = CancellationFlag()
        let scanID = UUID()
        cancellation = flag
        activeScanID = scanID
        activeScanURL = url.standardizedFileURL
        progress = ScanProgress()
        isScanning = true
        result = cachedResult(for: url)
        scanActivity = ProcessInfo.processInfo.beginActivity(
            options: [.userInitiated, .idleSystemSleepDisabled],
            reason: "DiskScope analysiert einen Speicherort"
        )

        scanTask = Task {
            do {
                let scanResult = try await Task.detached(priority: .userInitiated) {
                    try await DirectoryScanner.scan(root: url, cancellation: flag) { update in
                        await MainActor.run {
                            self.progress = update
                        }
                    }
                }.value

                if !flag.isCancelled, activeScanID == scanID {
                    cache(scanResult)
                    result = scanResult
                }
            } catch {
                if activeScanID != scanID || flag.isCancelled || error is CancellationError {
                    return
                } else if error is ScannerError {
                    present(L10n.string("scan.error.cannot_read", language: language))
                } else {
                    present(error.localizedDescription)
                }
            }
            if activeScanID == scanID {
                isScanning = false
                activeScanURL = nil
                activeScanID = nil
                scanTask = nil
                endScanActivity()
            }
        }
    }

    func cancelScan() {
        activeScanID = nil
        activeScanURL = nil
        cancellation?.cancel()
        scanTask?.cancel()
        scanTask = nil
        isScanning = false
        endScanActivity()
    }

    func isScanningLocation(_ url: URL) -> Bool {
        isScanning
            && activeScanURL?.standardizedFileURL == url.standardizedFileURL
    }

    func hasCachedResult(for url: URL) -> Bool {
        cachedResultPaths.contains(cacheKey(for: url))
    }

    private func cacheKey(for url: URL) -> String {
        url.standardizedFileURL.path
    }

    private func cachedResult(for url: URL) -> ScanResult? {
        let key = cacheKey(for: url)
        guard let cached = resultCache[key] else { return nil }
        resultCacheOrder.removeAll { $0 == key }
        resultCacheOrder.append(key)
        return cached
    }

    private func cache(_ scanResult: ScanResult) {
        let key = cacheKey(for: scanResult.rootURL)
        resultCache[key] = scanResult
        resultCacheOrder.removeAll { $0 == key }
        resultCacheOrder.append(key)

        while resultCacheOrder.count > maximumCachedResults {
            let oldestKey = resultCacheOrder.removeFirst()
            resultCache.removeValue(forKey: oldestKey)
        }
        cachedResultPaths = Set(resultCache.keys)
    }

    private func showCachedResult(_ cached: ScanResult) {
        result = cached
        progress = ScanProgress(
            files: cached.fileCount,
            logicalBytes: cached.logicalBytes
        )
    }

    private func invalidateCachedResults() {
        resultCache.removeAll()
        resultCacheOrder.removeAll()
        cachedResultPaths.removeAll()
    }

    private func endScanActivity() {
        if let scanActivity {
            ProcessInfo.processInfo.endActivity(scanActivity)
            self.scanActivity = nil
        }
    }

    func loadApplications(force: Bool = false) {
        if isScanningApplications { return }
        if !force, !installedApplications.isEmpty { return }

        applicationCancellation?.cancel()
        applicationScanTask?.cancel()

        let flag = CancellationFlag()
        applicationCancellation = flag
        applicationScanCount = 0
        applicationScanBytes = 0
        isScanningApplications = true
        if force {
            installedApplications = []
        }

        applicationScanTask = Task {
            let applications = await Task.detached(priority: .userInitiated) {
                await ApplicationScanner.scan(cancellation: flag) { count, bytes in
                    await MainActor.run {
                        self.applicationScanCount = count
                        self.applicationScanBytes = bytes
                    }
                }
            }.value

            if !flag.isCancelled {
                installedApplications = applications
            }
            isScanningApplications = false
        }
    }

    func reveal(_ item: StorageItem) {
        NSWorkspace.shared.activateFileViewerSelecting([item.url])
    }

    func isSelected(_ url: URL) -> Bool {
        selectedURL?.standardizedFileURL.path == url.standardizedFileURL.path
    }

    func displayName(for url: URL) -> String {
        if url.standardizedFileURL.path == "/" { return "Macintosh HD" }
        return url.lastPathComponent.isEmpty ? url.path : url.lastPathComponent
    }

    func systemVolumeInfo() -> VolumeInfo {
        let root = URL(fileURLWithPath: "/", isDirectory: true)
        let values = try? root.resourceValues(forKeys: [
            .volumeNameKey,
            .volumeTotalCapacityKey,
            .volumeAvailableCapacityForImportantUsageKey
        ])
        return VolumeInfo(
            name: values?.volumeName ?? "Macintosh HD",
            totalBytes: Int64(values?.volumeTotalCapacity ?? 0),
            availableBytes: values?.volumeAvailableCapacityForImportantUsage ?? 0
        )
    }

    func items(in directory: URL) -> [StorageItem] {
        guard let result else { return [] }
        let manager = FileManager.default
        let urls: [URL]
        do {
            urls = try manager.contentsOfDirectory(
                at: directory,
                includingPropertiesForKeys: nil,
                options: []
            )
        } catch {
            return []
        }

        return urls.compactMap { url -> StorageItem? in
            var metadata = stat()
            let status = url.withUnsafeFileSystemRepresentation { pathPointer -> Int32 in
                guard let pathPointer else { return -1 }
                return Darwin.lstat(pathPointer, &metadata)
            }
            guard status == 0 else { return nil }

            let fileType = metadata.st_mode & mode_t(S_IFMT)
            if fileType == mode_t(S_IFLNK) { return nil }

            let path = url.standardizedFileURL.path
            let modified = Date(timeIntervalSince1970: TimeInterval(metadata.st_mtimespec.tv_sec))

            if fileType == mode_t(S_IFDIR) {
                let summary = result.folderSummaries[path] ?? FolderSummary(modified: modified)
                return StorageItem(
                    id: path,
                    url: url,
                    name: url.lastPathComponent,
                    logicalBytes: summary.logicalBytes,
                    allocatedBytes: summary.allocatedBytes,
                    modified: max(summary.modified, modified),
                    isDirectory: true,
                    cleanupKind: DirectoryScanner.cleanupKindForDisplay(url)
                )
            }

            guard fileType == mode_t(S_IFREG) else { return nil }
            return StorageItem(
                id: path,
                url: url,
                name: url.lastPathComponent,
                logicalBytes: Int64(metadata.st_size),
                allocatedBytes: Int64(metadata.st_blocks) * 512,
                modified: modified,
                isDirectory: false,
                cleanupKind: DirectoryScanner.cleanupKindForDisplay(url)
            )
        }
        .sorted {
            if $0.isDirectory != $1.isDirectory { return $0.isDirectory }
            if $0.logicalBytes != $1.logicalBytes { return $0.logicalBytes > $1.logicalBytes }
            return $0.name.localizedStandardCompare($1.name) == .orderedAscending
        }
    }

    func canTrash(_ item: StorageItem) -> Bool {
        guard item.url != selectedURL else { return false }
        let path = item.url.standardizedFileURL.path
        let lowercasedPath = path.lowercased()

        if isTrashableApplication(item) {
            return FileManager.default.fileExists(atPath: path)
        }

        let protectedTrees = [
            "/applications",
            "/bin",
            "/library",
            "/private",
            "/sbin",
            "/system",
            "/usr"
        ]
        if lowercasedPath == "/"
            || lowercasedPath == "/users"
            || protectedTrees.contains(where: {
                lowercasedPath == $0 || lowercasedPath.hasPrefix($0 + "/")
            }) {
            return false
        }
        let homeLibrary = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library", isDirectory: true)
            .standardizedFileURL
            .path
            .lowercased()
        if lowercasedPath == homeLibrary {
            return false
        }
        return FileManager.default.fileExists(atPath: path)
    }

    private func isTrashableApplication(_ item: StorageItem) -> Bool {
        guard item.isDirectory, item.url.pathExtension.lowercased() == "app" else {
            return false
        }

        let path = item.url.standardizedFileURL.path
        let homeApplications = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Applications", isDirectory: true)
            .standardizedFileURL
            .path

        let allowedRoot: String
        if path.hasPrefix("/Applications/") {
            allowedRoot = "/Applications"
        } else if path.hasPrefix(homeApplications + "/") {
            allowedRoot = homeApplications
        } else {
            return false
        }

        let relativePath = String(path.dropFirst(allowedRoot.count + 1))
        let parentComponents = relativePath.split(separator: "/").dropLast()
        return !parentComponents.contains {
            $0.lowercased().hasSuffix(".app")
        }
    }

    func requestTrash(_ item: StorageItem) {
        requestTrash([item])
    }

    func requestTrash(_ items: [StorageItem]) {
        let trashable = items.filter(canTrash)
        guard !trashable.isEmpty else {
            present(L10n.string("trash.error.protected", language: language))
            return
        }
        pendingTrashItems = Array(
            Dictionary(uniqueKeysWithValues: trashable.map { ($0.id, $0) }).values
        )
        showTrashConfirmation = true
    }

    func confirmTrash() {
        let items = pendingTrashItems
        guard !items.isEmpty else { return }
        pendingTrashItems = []
        let containsApplication = items.contains(where: isTrashableApplication)

        var moved = 0
        var failures: [String] = []
        for item in items {
            do {
                var destination: NSURL?
                try FileManager.default.trashItem(at: item.url, resultingItemURL: &destination)
                moved += 1
            } catch {
                failures.append("\(item.name): \(error.localizedDescription)")
            }
        }

        if failures.isEmpty {
            present(
                L10n.format(
                    moved == 1 ? "trash.success.single" : "trash.success.multiple",
                    language: language,
                    moved
                )
            )
        } else {
            present(
                L10n.format(
                    "trash.result.partial",
                    language: language,
                    moved,
                    failures.count,
                    failures.prefix(3).joined(separator: "\n")
                )
            )
        }
        invalidateCachedResults()
        if containsApplication {
            loadApplications(force: true)
        } else {
            startScan()
        }
    }

    private func present(_ text: String) {
        message = text
        showMessage = true
    }

    private static func detectFullDiskAccess() -> Bool {
        let home = FileManager.default.homeDirectoryForCurrentUser
        let protectedLocations = [
            home.appendingPathComponent("Library/Safari", isDirectory: true),
            home.appendingPathComponent("Library/Mail", isDirectory: true),
            home.appendingPathComponent("Library/Messages", isDirectory: true)
        ]

        for location in protectedLocations
        where FileManager.default.fileExists(atPath: location.path) {
            if let handle = Darwin.opendir(location.path) {
                Darwin.closedir(handle)
                return true
            }
        }
        return false
    }

    private func refreshLocations() {
        let manager = FileManager.default
        let home = manager.homeDirectoryForCurrentUser

        storageLocations = [
            ScanLocation(
                name: "Macintosh HD",
                url: URL(fileURLWithPath: "/", isDirectory: true),
                icon: "internaldrive.fill"
            ),
            ScanLocation(
                name: NSUserName(),
                url: home,
                icon: "house.fill"
            )
        ]

        let standardFolders: [(String, String, String)] = [
            ("Schreibtisch", "Desktop", "desktopcomputer"),
            ("Downloads", "Downloads", "arrow.down.circle.fill"),
            ("Dokumente", "Documents", "doc.fill"),
            ("Bilder", "Pictures", "photo.fill"),
            ("Filme", "Movies", "film.fill"),
            ("Musik", "Music", "music.note")
        ]
        folderLocations = standardFolders.compactMap { name, component, icon in
            let url = home.appendingPathComponent(component, isDirectory: true)
            guard manager.fileExists(atPath: url.path) else { return nil }
            return ScanLocation(name: name, url: url, icon: icon)
        }

        let volumeKeys: [URLResourceKey] = [.volumeNameKey, .volumeIsLocalKey]
        let volumes = manager.mountedVolumeURLs(
            includingResourceValuesForKeys: volumeKeys,
            options: [.skipHiddenVolumes]
        ) ?? []
        externalLocations = volumes.compactMap { url in
            let path = url.standardizedFileURL.path
            guard path != "/", !path.hasPrefix("/System/Volumes/") else { return nil }
            let values = try? url.resourceValues(forKeys: Set(volumeKeys))
            return ScanLocation(
                name: values?.volumeName ?? url.lastPathComponent,
                url: url,
                icon: values?.volumeIsLocal == false ? "network" : "externaldrive.fill"
            )
        }
    }
}
