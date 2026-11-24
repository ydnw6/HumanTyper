import AppKit
import SwiftUI

/// A small always-on-top panel that shows how far typing has got. It never takes focus, so clicking or
/// dragging it doesn't pull the keyboard away from the target app, and it's kept out of screenshots.
final class OverlayController {
    private weak var model: AppModel?
    private var panel: NSPanel?
    private var hideWork: DispatchWorkItem?
    private var moveObserver: NSObjectProtocol?

    init(model: AppModel) { self.model = model }

    func show() {
        hideWork?.cancel()
        let p = panel ?? makePanel()
        panel = p
        p.orderFrontRegardless()
    }

    func hide(after delay: TimeInterval = 0) {
        hideWork?.cancel()
        let work = DispatchWorkItem { [weak self] in self?.panel?.orderOut(nil) }
        hideWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: work)
    }

    private func makePanel() -> NSPanel {
        let size = NSSize(width: 560, height: 128)
        let p = NSPanel(contentRect: NSRect(origin: .zero, size: size),
                        styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        p.isFloatingPanel = true
        p.level = .statusBar
        p.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
        p.isMovableByWindowBackground = true
        p.hidesOnDeactivate = false
        p.backgroundColor = .clear
        p.isOpaque = false
        p.hasShadow = true
        p.sharingType = .none
        if let model { p.contentView = NSHostingView(rootView: OverlayView(model: model)) }

        if let m = model, m.settings.overlayX > -99999, m.settings.overlayY > -99999 {
            p.setFrameOrigin(NSPoint(x: m.settings.overlayX, y: m.settings.overlayY))
        } else if let screen = NSScreen.main {
            let f = screen.visibleFrame
            p.setFrameOrigin(NSPoint(x: f.midX - size.width / 2, y: f.maxY - size.height - 24))
        }
        moveObserver = NotificationCenter.default.addObserver(forName: NSWindow.didMoveNotification, object: p, queue: .main) { [weak self, weak p] _ in
            guard let p else { return }
            self?.model?.overlayMoved(to: p.frame.origin)
        }
        return p
    }
}

struct OverlayView: View {
    @ObservedObject var model: AppModel

    private var accent: Color {
        switch model.state {
        case .paused: return .orange
        case .finished: return .green
        case .stopped: return .gray
        default: return .accentColor
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Circle().fill(accent).frame(width: 8, height: 8)
                Text(model.stateTitle).font(.system(size: 13, weight: .semibold))
                Text(model.status).font(.system(size: 11)).foregroundColor(.secondary).lineLimit(1)
                Spacer()
                Text("\(model.percent)%").font(.system(size: 18, weight: .bold)).monospacedDigit()
                Button { model.overlayClosedByUser() } label: {
                    Image(systemName: "xmark").font(.system(size: 10, weight: .bold))
                }
                .buttonStyle(.plain)
                .foregroundColor(.secondary)
            }
            ProgressView(value: Double(model.done), total: Double(max(1, model.total)))
                .progressViewStyle(.linear)
                .tint(accent)
            teleprompter
            HStack {
                Text("\(model.done) / \(model.total) 字")
                Spacer()
                Text(model.remainingText)
            }
            .font(.system(size: 11))
            .foregroundColor(.secondary)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .frame(width: 560, height: 128)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(nsColor: .windowBackgroundColor).opacity(0.95))
        )
    }

    /// The character being typed right now, between what's done and what's next.
    private var teleprompter: some View {
        let u = model.units
        let i = min(model.done, u.count)
        let before = u[max(0, i - 24)..<i].joined().replacingOccurrences(of: "\n", with: "↵")
        let cur = i < u.count ? (u[i] == "\n" ? "↵" : u[i] == " " ? "␣" : u[i]) : ""
        let after = i + 1 < u.count ? u[(i + 1)..<min(u.count, i + 25)].joined().replacingOccurrences(of: "\n", with: "↵") : ""
        return HStack(spacing: 0) {
            Text(before).foregroundColor(.secondary).lineLimit(1).truncationMode(.head)
                .frame(maxWidth: .infinity, alignment: .trailing)
            Text(cur).fontWeight(.bold).padding(.horizontal, 3).background(Color.yellow.opacity(0.55)).cornerRadius(3)
            Text(after).lineLimit(1).truncationMode(.tail)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .font(.system(size: 15))
    }
}
