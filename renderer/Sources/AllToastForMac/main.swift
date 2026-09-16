import AppKit
import QuartzCore

struct Theme: Decodable {
    let symbol: String?
    let accent: String?
    let iconPath: String?
}

struct DigestItem: Decodable {
    let title: String
    let time: String
    let summary: String
    let source: String?
    let verification: String?
    let action: String?
    let url: URL
}

struct DigestPayload: Decodable {
    let title: String
    let window: String
    let theme: Theme?
    let items: [DigestItem]
}

struct Options {
    var title = "新提醒"
    var message = "有新的信息值得留意。"
    var detail: String?
    var url: URL?
    var iconPath: String?
    var symbol = "bell.fill"
    var accent = "systemBlue"
    var duration: TimeInterval = 30
    var sticky = false
    var sound = "Glass"
    var digestJSONPath: String?
}

enum Metrics {
    static let margin: CGFloat = 24
    static let toastWidth: CGFloat = 440
    static let toastHeight: CGFloat = 176
    static let digestWidth: CGFloat = 480
    static let digestRowHeight: CGFloat = 144
    static let digestMinHeight: CGFloat = 300
    static let digestMaxHeight: CGFloat = 760
    static let cornerRadius: CGFloat = 18
}

func accentColor(_ name: String?) -> NSColor {
    switch name?.lowercased() {
    case "systemorange", "orange": return .systemOrange
    case "systemred", "red": return .systemRed
    case "systemgreen", "green": return .systemGreen
    case "systempurple", "purple": return .systemPurple
    case "systempink", "pink": return .systemPink
    case "systemyellow", "yellow": return .systemYellow
    case "systemteal", "teal": return .systemTeal
    default: return .systemBlue
    }
}

class ClickableView: NSView {
    var onClick: (() -> Void)?

    override func mouseDown(with event: NSEvent) {
        onClick?()
    }

    override func resetCursorRects() {
        if onClick != nil {
            addCursorRect(bounds, cursor: .pointingHand)
        }
    }
}

final class ClosureButton: NSButton {
    var handler: (() -> Void)?

    override func mouseDown(with event: NSEvent) {
        handler?()
    }
}

final class FlippedView: NSView {
    override var isFlipped: Bool { true }
}

func configureCard(_ view: NSView, alpha: CGFloat = 0.97) {
    view.wantsLayer = true
    view.layer?.cornerRadius = Metrics.cornerRadius
    if #available(macOS 10.15, *) {
        view.layer?.cornerCurve = .continuous
    }
    view.layer?.backgroundColor = NSColor(calibratedWhite: 0.055, alpha: alpha).cgColor
    view.layer?.borderColor = NSColor.white.withAlphaComponent(0.10).cgColor
    view.layer?.borderWidth = 1
    view.layer?.shadowColor = NSColor.black.cgColor
    view.layer?.shadowOpacity = 0.32
    view.layer?.shadowRadius = 24
    view.layer?.shadowOffset = CGSize(width: 0, height: -6)
}

func makeIcon(symbol: String, accent: NSColor, iconPath: String?, size: CGFloat) -> NSView {
    let container = NSView()
    container.wantsLayer = true
    container.layer?.cornerRadius = size * 0.30
    container.layer?.backgroundColor = accent.withAlphaComponent(0.18).cgColor
    container.layer?.borderColor = accent.withAlphaComponent(0.28).cgColor
    container.layer?.borderWidth = 1

    let imageView = NSImageView()
    imageView.imageScaling = .scaleProportionallyUpOrDown
    if let iconPath, let image = NSImage(contentsOfFile: iconPath) {
        imageView.image = image
    } else {
        imageView.image = NSImage(systemSymbolName: symbol, accessibilityDescription: "提醒")
        imageView.contentTintColor = accent
    }
    imageView.translatesAutoresizingMaskIntoConstraints = false
    container.addSubview(imageView)
    NSLayoutConstraint.activate([
        imageView.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: size * 0.22),
        imageView.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -size * 0.22),
        imageView.topAnchor.constraint(equalTo: container.topAnchor, constant: size * 0.22),
        imageView.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -size * 0.22)
    ])
    return container
}

func makeCloseButton(_ handler: @escaping () -> Void) -> ClosureButton {
    let button = ClosureButton(title: "", target: nil, action: nil)
    button.isBordered = false
    button.image = NSImage(systemSymbolName: "xmark.circle.fill", accessibilityDescription: "关闭")
    button.contentTintColor = NSColor.white.withAlphaComponent(0.46)
    button.handler = handler
    button.translatesAutoresizingMaskIntoConstraints = false
    NSLayoutConstraint.activate([
        button.widthAnchor.constraint(equalToConstant: 24),
        button.heightAnchor.constraint(equalToConstant: 24)
    ])
    return button
}

final class ToastView: ClickableView {
    init(options: Options, onClose: @escaping () -> Void) {
        super.init(frame: .zero)
        configureCard(self)
        if let url = options.url {
            onClick = {
                NSWorkspace.shared.open(url)
                onClose()
            }
        }

        let accent = accentColor(options.accent)
        let icon = makeIcon(symbol: options.symbol, accent: accent, iconPath: options.iconPath, size: 46)
        icon.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            icon.widthAnchor.constraint(equalToConstant: 46),
            icon.heightAnchor.constraint(equalToConstant: 46)
        ])

        let titleLabel = NSTextField(wrappingLabelWithString: options.title)
        titleLabel.font = NSFont.systemFont(ofSize: 15.5, weight: .semibold)
        titleLabel.textColor = .white
        titleLabel.maximumNumberOfLines = 2

        let messageLabel = NSTextField(wrappingLabelWithString: options.message)
        messageLabel.font = NSFont.systemFont(ofSize: 13, weight: .regular)
        messageLabel.textColor = NSColor.white.withAlphaComponent(0.74)
        messageLabel.maximumNumberOfLines = 2

        var textViews: [NSView] = [titleLabel, messageLabel]
        if let detail = options.detail, !detail.isEmpty, detail != options.message {
            let detailLabel = NSTextField(wrappingLabelWithString: detail)
            detailLabel.font = NSFont.systemFont(ofSize: 12, weight: .regular)
            detailLabel.textColor = NSColor.white.withAlphaComponent(0.56)
            detailLabel.maximumNumberOfLines = 3
            textViews.append(detailLabel)
        }
        if options.url != nil {
            let hint = NSTextField(labelWithString: "点击打开原文")
            hint.font = NSFont.systemFont(ofSize: 11, weight: .medium)
            hint.textColor = accent.withAlphaComponent(0.92)
            textViews.append(hint)
        }
        let textStack = NSStackView(views: textViews)
        textStack.orientation = .vertical
        textStack.alignment = .leading
        textStack.spacing = 6

        let content = NSStackView(views: [icon, textStack])
        content.orientation = .horizontal
        content.alignment = .top
        content.spacing = 15
        content.translatesAutoresizingMaskIntoConstraints = false
        addSubview(content)

        let close = makeCloseButton(onClose)
        addSubview(close)
        NSLayoutConstraint.activate([
            content.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 18),
            content.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -42),
            content.topAnchor.constraint(equalTo: topAnchor, constant: 24),
            content.bottomAnchor.constraint(lessThanOrEqualTo: bottomAnchor, constant: -20),
            textStack.widthAnchor.constraint(equalToConstant: 335),
            close.topAnchor.constraint(equalTo: topAnchor, constant: 10),
            close.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -10)
        ])
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
}

final class DigestRowView: ClickableView {
    init(item: DigestItem, accent: NSColor) {
        super.init(frame: .zero)
        wantsLayer = true
        layer?.cornerRadius = 11
        layer?.backgroundColor = NSColor.white.withAlphaComponent(0.048).cgColor
        onClick = { NSWorkspace.shared.open(item.url) }

        let title = NSTextField(wrappingLabelWithString: item.title)
        title.font = NSFont.systemFont(ofSize: 14.5, weight: .semibold)
        title.textColor = .white
        title.maximumNumberOfLines = 2

        var metaParts = [item.time]
        if let source = item.source, !source.isEmpty { metaParts.append(source) }
        if item.verification == "pending" { metaParts.append("待核实") }
        if item.verification == "conflicting" { metaParts.append("信息冲突") }
        let meta = NSTextField(labelWithString: metaParts.joined(separator: " · "))
        meta.font = NSFont.systemFont(ofSize: 11, weight: .medium)
        meta.textColor = item.verification == "pending" ? accent : NSColor.white.withAlphaComponent(0.48)
        meta.lineBreakMode = .byTruncatingTail

        let summary = NSTextField(wrappingLabelWithString: item.summary)
        summary.font = NSFont.systemFont(ofSize: 12.5, weight: .regular)
        summary.textColor = NSColor.white.withAlphaComponent(0.70)
        summary.maximumNumberOfLines = 3

        let stack = NSStackView(views: [title, meta, summary])
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 6
        stack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stack)
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 14),
            stack.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -14),
            stack.topAnchor.constraint(equalTo: topAnchor, constant: 12),
            stack.bottomAnchor.constraint(lessThanOrEqualTo: bottomAnchor, constant: -12),
            title.widthAnchor.constraint(equalTo: stack.widthAnchor),
            meta.widthAnchor.constraint(equalTo: stack.widthAnchor),
            summary.widthAnchor.constraint(equalTo: stack.widthAnchor)
        ])
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
}

final class DigestView: NSView {
    init(payload: DigestPayload, fallback: Options, onClose: @escaping () -> Void) {
        super.init(frame: .zero)
        configureCard(self, alpha: 0.91)
        layer?.masksToBounds = true

        let symbol = payload.theme?.symbol ?? fallback.symbol
        let accentName = payload.theme?.accent ?? fallback.accent
        let accent = accentColor(accentName)
        let iconPath = payload.theme?.iconPath ?? fallback.iconPath
        let icon = makeIcon(symbol: symbol, accent: accent, iconPath: iconPath, size: 40)
        icon.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            icon.widthAnchor.constraint(equalToConstant: 40),
            icon.heightAnchor.constraint(equalToConstant: 40)
        ])

        let title = NSTextField(labelWithString: payload.title)
        title.font = NSFont.systemFont(ofSize: 18, weight: .bold)
        title.textColor = .white
        title.lineBreakMode = .byTruncatingTail
        let subtitle = NSTextField(labelWithString: payload.window)
        subtitle.font = NSFont.systemFont(ofSize: 11.5, weight: .medium)
        subtitle.textColor = NSColor.white.withAlphaComponent(0.50)
        let headingText = NSStackView(views: [title, subtitle])
        headingText.orientation = .vertical
        headingText.alignment = .leading
        headingText.spacing = 4
        let heading = NSStackView(views: [icon, headingText])
        heading.orientation = .horizontal
        heading.alignment = .centerY
        heading.spacing = 12

        let header = NSStackView(views: [heading, NSView(), makeCloseButton(onClose)])
        header.orientation = .horizontal
        header.alignment = .centerY
        header.spacing = 10
        header.edgeInsets = NSEdgeInsets(top: 18, left: 18, bottom: 14, right: 14)

        let rows = NSStackView()
        rows.orientation = .vertical
        rows.alignment = .leading
        rows.spacing = 10
        rows.edgeInsets = NSEdgeInsets(top: 0, left: 14, bottom: 14, right: 14)
        rows.translatesAutoresizingMaskIntoConstraints = false
        for item in payload.items {
            let row = DigestRowView(item: item, accent: accent)
            row.translatesAutoresizingMaskIntoConstraints = false
            rows.addArrangedSubview(row)
            row.widthAnchor.constraint(equalTo: rows.widthAnchor, constant: -28).isActive = true
            row.heightAnchor.constraint(equalToConstant: Metrics.digestRowHeight).isActive = true
        }

        let document = FlippedView()
        document.translatesAutoresizingMaskIntoConstraints = false
        document.addSubview(rows)
        NSLayoutConstraint.activate([
            rows.leadingAnchor.constraint(equalTo: document.leadingAnchor),
            rows.trailingAnchor.constraint(equalTo: document.trailingAnchor),
            rows.topAnchor.constraint(equalTo: document.topAnchor),
            rows.bottomAnchor.constraint(equalTo: document.bottomAnchor),
            document.widthAnchor.constraint(equalToConstant: Metrics.digestWidth)
        ])

        let scroll = NSScrollView()
        scroll.drawsBackground = false
        scroll.hasVerticalScroller = true
        scroll.autohidesScrollers = true
        scroll.scrollerStyle = .overlay
        scroll.documentView = document

        let root = NSStackView(views: [header, scroll])
        root.orientation = .vertical
        root.alignment = .leading
        root.spacing = 0
        root.translatesAutoresizingMaskIntoConstraints = false
        addSubview(root)
        NSLayoutConstraint.activate([
            root.leadingAnchor.constraint(equalTo: leadingAnchor),
            root.trailingAnchor.constraint(equalTo: trailingAnchor),
            root.topAnchor.constraint(equalTo: topAnchor),
            root.bottomAnchor.constraint(equalTo: bottomAnchor),
            header.widthAnchor.constraint(equalTo: root.widthAnchor),
            scroll.widthAnchor.constraint(equalTo: root.widthAnchor)
        ])
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
}

final class AllToastForMacApp: NSObject, NSApplicationDelegate {
    private let options: Options
    private var panel: NSPanel?
    private var digest: DigestPayload?
    private var closeTask: DispatchWorkItem?

    init(options: Options) {
        self.options = options
        if let path = options.digestJSONPath,
           let data = FileManager.default.contents(atPath: path) {
            self.digest = try? JSONDecoder().decode(DigestPayload.self, from: data)
            let file = URL(fileURLWithPath: path)
            if file.lastPathComponent.hasPrefix("all-toast-") && file.pathExtension == "json" {
                try? FileManager.default.removeItem(at: file)
            }
        }
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        show()
        if !options.sound.isEmpty { NSSound(named: options.sound)?.play() }
        if !options.sticky {
            let task = DispatchWorkItem { [weak self] in self?.close() }
            closeTask = task
            DispatchQueue.main.asyncAfter(deadline: .now() + options.duration, execute: task)
        }
    }

    private func show() {
        guard let screen = NSScreen.main else { NSApp.terminate(nil); return }
        let visible = screen.visibleFrame
        let content: NSView
        let frame: NSRect
        if let digest {
            let naturalHeight = 96 + CGFloat(digest.items.count) * (Metrics.digestRowHeight + 10)
            let height = min(max(Metrics.digestMinHeight, naturalHeight), min(Metrics.digestMaxHeight, visible.height - Metrics.margin * 2))
            frame = NSRect(
                x: visible.maxX - Metrics.digestWidth - Metrics.margin,
                y: visible.minY + (visible.height - height) / 2,
                width: Metrics.digestWidth,
                height: height
            )
            content = DigestView(payload: digest, fallback: options, onClose: { [weak self] in self?.close() })
        } else {
            frame = NSRect(
                x: visible.maxX - Metrics.toastWidth - Metrics.margin,
                y: visible.minY + Metrics.margin,
                width: Metrics.toastWidth,
                height: Metrics.toastHeight
            )
            content = ToastView(options: options, onClose: { [weak self] in self?.close() })
        }

        let start = frame.offsetBy(dx: 18, dy: 0)
        let panel = NSPanel(contentRect: start, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        panel.isReleasedWhenClosed = false
        panel.level = digest == nil ? .statusBar : .normal
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .transient]
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hasShadow = false
        panel.ignoresMouseEvents = false
        panel.alphaValue = 0
        content.frame = NSRect(origin: .zero, size: frame.size)
        content.autoresizingMask = [.width, .height]
        panel.contentView = content
        self.panel = panel
        panel.orderFrontRegardless()
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.28
            context.timingFunction = CAMediaTimingFunction(name: .easeOut)
            panel.animator().setFrame(frame, display: true)
            panel.animator().alphaValue = 1
        }
    }

    private func close() {
        closeTask?.cancel()
        guard let panel else { NSApp.terminate(nil); return }
        NSAnimationContext.runAnimationGroup({ context in
            context.duration = 0.26
            panel.animator().alphaValue = 0
        }, completionHandler: { NSApp.terminate(nil) })
    }
}

func parseOptions(_ arguments: [String]) -> Options {
    var options = Options()
    var index = 1
    func nextValue() -> String? {
        guard index + 1 < arguments.count else { return nil }
        index += 1
        return arguments[index]
    }
    while index < arguments.count {
        switch arguments[index] {
        case "--title": if let value = nextValue() { options.title = value }
        case "--message": if let value = nextValue() { options.message = value }
        case "--detail": if let value = nextValue() { options.detail = value }
        case "--url": if let value = nextValue() { options.url = URL(string: value) }
        case "--icon": if let value = nextValue() { options.iconPath = value }
        case "--symbol": if let value = nextValue() { options.symbol = value }
        case "--accent": if let value = nextValue() { options.accent = value }
        case "--duration":
            if let value = nextValue(), let duration = TimeInterval(value) {
                options.duration = max(1, min(duration, 120))
            }
        case "--sticky": options.sticky = true
        case "--sound": if let value = nextValue() { options.sound = value }
        case "--digest-json": if let value = nextValue() { options.digestJSONPath = value }
        case "--help", "-h":
            print("""
            Usage:
              all-toast-for-mac --title TITLE --message MESSAGE [--detail DETAIL] [--url URL] [--symbol NAME] [--accent COLOR] [--icon PATH] [--duration 30] [--sticky] [--sound Glass]
              all-toast-for-mac --digest-json PATH [--symbol NAME] [--accent COLOR] [--sticky] [--sound Glass]
            """)
            exit(0)
        default: break
        }
        index += 1
    }
    return options
}

let app = NSApplication.shared
let delegate = AllToastForMacApp(options: parseOptions(CommandLine.arguments))
app.delegate = delegate
app.run()
