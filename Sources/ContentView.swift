import SwiftUI

extension NSAppearance {
    var isDark: Bool { bestMatch(from: [.darkAqua, .aqua]) == .darkAqua }
}

/// Values track `HTMLTemplate.swift`.
enum ReaderTheme {
    static var activePalette: ReaderThemePalette {
        ThemePreferences.shared.palette(systemIsDark: NSApp.effectiveAppearance.isDark)
    }

    /// Matches the page `--bg`, so chrome reads as one surface with the document.
    static var pageBackground: NSColor { activePalette.background.nsColor }
    static var pill: Color { activePalette.surface.color }
    /// Matches the code-block copy button's confirmed state.
    static var copyConfirm: Color { activePalette.green.color }
    static var hairline: Color { activePalette.text.color.opacity(0.08) }

    static let headerTopPadding: CGFloat = 6
    static let headerPillHeight: CGFloat = 34
    static var headerCenterFromTop: CGFloat { headerTopPadding + headerPillHeight / 2 }
    static var headerStripHeight: CGFloat { headerTopPadding * 2 + headerPillHeight }
    /// Clears the traffic lights.
    static let headerLeadingClearance: CGFloat = 76
    static let headerEdgePadding: CGFloat = 12

}

extension View {
    func floatingSurface(_ shape: some InsettableShape, fill: some ShapeStyle) -> some View {
        background(fill, in: shape)
            .overlay(shape.strokeBorder(ReaderTheme.hairline))
            .shadow(color: .black.opacity(0.12), radius: 8, y: 2)
    }
}

final class FindState: ObservableObject {
    @Published var isVisible = false
    @Published var searchText = ""
    @Published var totalMatches = 0
    @Published var currentMatch = 0  // 1-indexed; 0 means no active match
    @Published var focusRequest = 0
}

/// Availability and visibility reported by the table-of-contents script in the
/// WebView. Keeping this as host state lets the native header button stay in sync
/// when the page reloads after an external edit.
final class TableOfContentsState: ObservableObject {
    @Published var isAvailable = false
    @Published var isVisible = false
}

struct ContentView: View {
    @StateObject private var watcher: DocumentWatcher
    @ObservedObject private var themePreferences = ThemePreferences.shared
    @ObservedObject private var typographyPreferences = TypographyPreferences.shared
    @Environment(\.colorScheme) private var colorScheme
    let baseURL: URL?
    let fileURL: URL?
    @StateObject private var findState = FindState()
    @StateObject private var tableOfContentsState = TableOfContentsState()
    @State private var window: NSWindow?
    @State private var pillText: String?
    @State private var pillDismissWork: DispatchWorkItem?

    init(document: MarkdownDocument, baseURL: URL?, fileURL: URL? = nil) {
        // Appearance source of truth is `NSAppearance`; WebKit's media query is unreliable here.
        let isDark = NSApp.effectiveAppearance.isDark
        let provider: (Bool) -> ReaderThemePalette = { systemIsDark in
            ThemePreferences.shared.palette(systemIsDark: systemIsDark)
        }
        let typographyProvider: () -> ReaderTypography = {
            TypographyPreferences.shared.typography
        }
        _watcher = StateObject(wrappedValue: DocumentWatcher(
            initialText: document.text,
            fileURL: fileURL,
            initialPalette: provider(isDark),
            themeProvider: provider,
            initialTypography: typographyProvider(),
            typographyProvider: typographyProvider
        ))
        self.baseURL = baseURL
        self.fileURL = fileURL
    }

    var body: some View {
        ZStack(alignment: .top) {
            // The pills float in the title-bar row; the container extends behind it.
            ZStack(alignment: .top) {
                WebView(baseURL: baseURL, findState: findState,
                        tableOfContentsState: tableOfContentsState, watcher: watcher)
                    .frame(minWidth: 500, minHeight: 400)
                WindowDragArea()
                    .frame(height: ReaderTheme.headerStripHeight)
                    .frame(maxWidth: .infinity, alignment: .top)
                HStack(spacing: 0) {
                    titlePill
                    Spacer(minLength: ReaderTheme.headerEdgePadding)
                    if let pillText {
                        StatusPill(text: pillText)
                            .padding(.trailing, 8)
                            .transition(.opacity)
                    }
                    actionPill
                }
                .padding(.top, ReaderTheme.headerTopPadding)
                .padding(.leading, ReaderTheme.headerLeadingClearance)
                .padding(.trailing, ReaderTheme.headerEdgePadding)
            }
                .ignoresSafeArea(.container, edges: .top)
                .background(WindowAccessor { window in
                    self.window = window
                    WindowCascader.shared.cascade(window)
                    configureWindowChrome(window)
                })

            if findState.isVisible {
                FindBar(state: findState)
                    .padding(.top, 8)
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .font(typographyPreferences.typography.ui.swiftUIFont)
        .onReceive(NotificationCenter.default.publisher(for: .findInDocument)) { _ in
            // `isKeyWindow`, not `NSApp.keyWindow`: SwiftUI re-wraps windows.
            guard window?.isKeyWindow == true else { return }
            showFindBar()
        }
        .onReceive(NotificationCenter.default.publisher(for: .showInFinder)) { _ in
            guard window?.isKeyWindow == true else { return }
            revealInFinder()
        }
        .onReceive(NotificationCenter.default.publisher(for: .copyFilePath)) { _ in
            guard window?.isKeyWindow == true else { return }
            copyFilePath()
        }
        .onChange(of: watcher.html) { _ in
            if watcher.lastChangeSource == .disk {
                showPill("Updated")
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .readerThemeDidChange)) { _ in
            window?.backgroundColor = ReaderTheme.pageBackground
        }
        .onChange(of: colorScheme) { _ in
            window?.backgroundColor = ReaderTheme.pageBackground
        }
    }

    /// Non-interactive so clicks reach the drag strip.
    private var titlePill: some View {
        Text(fileURL?.lastPathComponent ?? "Untitled")
            .font(typographyPreferences.typography.ui.swiftUIFont)
            .lineLimit(1)
            .truncationMode(.middle)
            .padding(.horizontal, 14)
            .frame(height: ReaderTheme.headerPillHeight)
            .floatingSurface(Capsule(), fill: ReaderTheme.pill)
            .allowsHitTesting(false)
    }

    /// Not `.toolbar`: it brings a system capsule, an opaque header band, and broken tooltips.
    private var actionPill: some View {
        HStack(spacing: 2) {
            CopyButton(text: { watcher.text },
                       html: { ClipboardExport.htmlFragment(fromRenderedBody: watcher.bodyHTML) }) {
                UsageMetrics.record(.copyFile)
                showPill("Full contents copied to clipboard")
            }
            PillIconButton(icon: "magnifyingglass", label: "Find in Document",
                           action: showFindBar)
            PillIconButton(
                icon: "list.bullet.indent",
                label: tableOfContentsState.isVisible
                    ? "Hide Table of Contents" : "Show Table of Contents",
                tint: tableOfContentsState.isVisible ? .accentColor : nil,
                disabled: !tableOfContentsState.isAvailable
            ) {
                NotificationCenter.default.post(name: .toggleTableOfContents, object: nil)
            }
            PillMenu(icon: "folder", label: "File Location", disabled: fileURL == nil) {
                Button("Show in Finder", action: revealInFinder)
                Button("Copy Path", action: copyFilePath)
            }
        }
        .padding(4)
        .floatingSurface(Capsule(), fill: ReaderTheme.pill)
    }

    private func revealInFinder() {
        guard let fileURL else { return }
        UsageMetrics.record(.showInFinder)
        NSWorkspace.shared.activateFileViewerSelecting([fileURL])
    }

    private func copyFilePath() {
        guard let fileURL else { return }
        UsageMetrics.record(.copyPath)
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(fileURL.path, forType: .string)
        showPill("Path copied to clipboard")
    }

    private func showFindBar() {
        UsageMetrics.record(.findInDocument)
        withAnimation(.easeOut(duration: 0.15)) {
            findState.isVisible = true
        }
        findState.focusRequest += 1
    }

    private func showPill(_ text: String) {
        withAnimation(.easeOut(duration: 0.2)) {
            pillText = text
        }
        pillDismissWork?.cancel()
        let work = DispatchWorkItem {
            withAnimation(.easeIn(duration: 0.4)) {
                pillText = nil
            }
        }
        pillDismissWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5, execute: work)
    }

    /// No `NSToolbar`: on Tahoe even an empty one paints an opaque header over the pills.
    private func configureWindowChrome(_ window: NSWindow) {
        if !window.styleMask.contains(.fullSizeContentView) {
            window.styleMask.insert(.fullSizeContentView)
        }
        window.toolbar = nil
        window.titlebarAppearsTransparent = true
        window.titlebarSeparatorStyle = .none
        window.titleVisibility = .hidden
        window.backgroundColor = ReaderTheme.pageBackground
        TrafficLightAligner.attach(to: window, centerFromTop: ReaderTheme.headerCenterFromTop)
    }
}

/// AppKit resets the button positions on every titlebar layout, hence the re-apply.
final class TrafficLightAligner {
    private static var associatedKey: UInt8 = 0

    static func attach(to window: NSWindow, centerFromTop: CGFloat) {
        guard objc_getAssociatedObject(window, &associatedKey) == nil else { return }
        let aligner = TrafficLightAligner(window: window, centerFromTop: centerFromTop)
        objc_setAssociatedObject(window, &associatedKey, aligner, .OBJC_ASSOCIATION_RETAIN)
    }

    private weak var window: NSWindow?
    private let centerFromTop: CGFloat
    private var observers: [Any] = []

    private init(window: NSWindow, centerFromTop: CGFloat) {
        self.window = window
        self.centerFromTop = centerFromTop
        realign()
        let events: [Notification.Name] = [
            NSWindow.didResizeNotification,
            NSWindow.didBecomeKeyNotification,
            NSWindow.didResignKeyNotification,
        ]
        for name in events {
            observers.append(NotificationCenter.default.addObserver(
                forName: name, object: window, queue: .main
            ) { [weak self] _ in
                self?.realign()
            })
        }
    }

    deinit {
        observers.forEach { NotificationCenter.default.removeObserver($0) }
    }

    private func realign() {
        applyOffset()
        // Again after AppKit's own layout pass settles.
        DispatchQueue.main.async { [weak self] in
            self?.applyOffset()
        }
    }

    private func applyOffset() {
        guard let window else { return }
        let buttons: [NSWindow.ButtonType] = [.closeButton, .miniaturizeButton, .zoomButton]
        for type in buttons {
            guard let button = window.standardWindowButton(type),
                  let superview = button.superview else { continue }
            let frameInWindow = superview.convert(button.frame, to: nil)
            let desiredCenterY = window.frame.height - centerFromTop
            let delta = desiredCenterY - frameInWindow.midY
            guard abs(delta) > 0.5 else { continue }
            var origin = button.frame.origin
            origin.y += superview.isFlipped ? -delta : delta
            button.setFrameOrigin(origin)
        }
    }
}

/// Restores the title-bar drag the WKWebView underneath would swallow.
struct WindowDragArea: NSViewRepresentable {
    func makeNSView(context: Context) -> NSView { DragView() }
    func updateNSView(_ nsView: NSView, context: Context) {}

    private final class DragView: NSView {
        override var mouseDownCanMoveWindow: Bool { false }
        override func mouseDown(with event: NSEvent) { window?.performDrag(with: event) }
    }
}

/// Never truncates; the title pill yields instead.
extension CheckIcon {
    struct Shape: SwiftUI.Shape {
        func path(in rect: CGRect) -> Path {
            let s = rect.width / CheckIcon.grid
            var path = Path()
            path.addLines(CheckIcon.points.map { CGPoint(x: rect.minX + $0.x * s, y: rect.minY + $0.y * s) })
            return path
        }
    }

    struct View: SwiftUI.View {
        let size: CGFloat
        var body: some SwiftUI.View {
            Shape()
                .stroke(style: StrokeStyle(lineWidth: strokeWidth * size / grid, lineCap: .round, lineJoin: .round))
                .frame(width: size, height: size)
        }
    }
}

private struct StatusPill: View {
    let text: String

    var body: some View {
        HStack(spacing: 6) {
            CheckIcon.View(size: 12)
                .foregroundStyle(ReaderTheme.copyConfirm)
            Text(text)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .lineLimit(1)
        .fixedSize()
        .padding(.horizontal, 12)
        .frame(height: ReaderTheme.headerPillHeight)
        .floatingSurface(Capsule(), fill: ReaderTheme.pill)
        .allowsHitTesting(false)
    }
}

private struct PillIcon<Glyph: View>: View {
    private static var hitArea: CGSize { CGSize(width: 30, height: 26) }
    private static var hoverShape: RoundedRectangle { RoundedRectangle(cornerRadius: 8, style: .continuous) }
    private static var hoverOpacity: Double { 0.07 }

    var tint: Color?
    var disabled = false
    let hovered: Bool
    @ViewBuilder let glyph: () -> Glyph

    var body: some View {
        glyph()
            .font(.system(size: 13, weight: .medium))
            .foregroundStyle(disabled ? AnyShapeStyle(.tertiary)
                                      : tint.map(AnyShapeStyle.init) ?? AnyShapeStyle(.secondary))
            .frame(width: Self.hitArea.width, height: Self.hitArea.height)
            .background(
                Self.hoverShape
                    .fill(Color.primary.opacity(hovered && !disabled ? Self.hoverOpacity : 0))
            )
            .contentShape(Self.hoverShape)
    }
}

private struct PillIconButton<Glyph: View>: View {
    let label: String
    var tint: Color?
    var disabled = false
    let action: () -> Void
    @ViewBuilder let glyph: () -> Glyph
    @State private var hovered = false

    var body: some View {
        Button(action: action) {
            PillIcon(tint: tint, disabled: disabled, hovered: hovered, glyph: glyph)
        }
        .buttonStyle(.plain)
        .disabled(disabled)
        .onHover { hovered = $0 }
        .help(label)
        .accessibilityLabel(label)
    }
}

extension PillIconButton where Glyph == Image {
    init(icon: String, label: String, tint: Color? = nil, disabled: Bool = false, action: @escaping () -> Void) {
        self.init(label: label, tint: tint, disabled: disabled, action: action) { Image(systemName: icon) }
    }
}

private struct PillMenu<Items: View>: View {
    let icon: String
    let label: String
    var disabled = false
    @ViewBuilder let items: () -> Items
    @State private var hovered = false

    var body: some View {
        Menu(content: items) {
            PillIcon(disabled: disabled, hovered: hovered) { Image(systemName: icon) }
        }
        .menuStyle(.button)
        .buttonStyle(.plain)
        .menuIndicator(.hidden)
        .fixedSize()
        .disabled(disabled)
        .onHover { hovered = $0 }
        .help(label)
        .accessibilityLabel(label)
    }
}

/// Confirmation state matches the code-block copy button.
private struct CopyButton: View {
    let text: () -> String
    var html: () -> String? = { nil }
    var onCopied: () -> Void = {}
    @State private var confirmed = false
    @State private var resetWork: DispatchWorkItem?

    var body: some View {
        PillIconButton(
            label: confirmed ? "Copied" : "Copy to Clipboard",
            tint: confirmed ? ReaderTheme.copyConfirm : nil,
            action: copy
        ) {
            if confirmed {
                CheckIcon.View(size: 14)
            } else {
                Image(systemName: "square.on.square")
            }
        }
    }

    private func copy() {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(text(), forType: .string)
        if let html = html() {
            pasteboard.setString(html, forType: .html)
        }
        confirmed = true
        resetWork?.cancel()
        let work = DispatchWorkItem { confirmed = false }
        resetWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + CheckIcon.confirmSeconds, execute: work)
        onCopied()
    }
}

struct FindBar: View {
    @ObservedObject var state: FindState
    @FocusState private var searchFocused: Bool

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.secondary)

            TextField("Find", text: $state.searchText)
                .textFieldStyle(.plain)
                .focused($searchFocused)
                .onSubmit { NotificationCenter.default.post(name: .findNext, object: nil) }

            if !state.searchText.isEmpty {
                Text(matchStatus)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .monospacedDigit()
            }

            Button(action: { NotificationCenter.default.post(name: .findPrevious, object: nil) }) {
                Image(systemName: "chevron.up")
            }
            .buttonStyle(.borderless)
            .disabled(state.searchText.isEmpty)

            Button(action: { NotificationCenter.default.post(name: .findNext, object: nil) }) {
                Image(systemName: "chevron.down")
            }
            .buttonStyle(.borderless)
            .disabled(state.searchText.isEmpty)

            Button(action: close) {
                Image(systemName: "xmark")
            }
            .buttonStyle(.borderless)
            .keyboardShortcut(.escape, modifiers: [])
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .floatingSurface(RoundedRectangle(cornerRadius: 10, style: .continuous), fill: .regularMaterial)
        .frame(maxWidth: 380)
        .padding(.horizontal, 16)
        .onAppear(perform: focusAndSelectSearchText)
        .onChange(of: state.focusRequest) { _ in
            focusAndSelectSearchText()
        }
    }

    private var matchStatus: String {
        if state.totalMatches == 0 { return "No results" }
        return "\(state.currentMatch) of \(state.totalMatches)"
    }

    private func close() {
        withAnimation(.easeOut(duration: 0.15)) {
            state.isVisible = false
        }
        state.searchText = ""
    }

    private func focusAndSelectSearchText() {
        searchFocused = true
        DispatchQueue.main.async {
            (NSApp.keyWindow?.firstResponder as? NSTextView)?.selectAll(nil)
        }
    }
}
