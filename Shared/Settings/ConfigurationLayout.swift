import AppKit

/// Adapts an options panel after its controls have been built at their preferred
/// coordinates. The bottom footer stays fixed; only the body scrolls when needed.
enum ConfigurationPanelLayout {
    private static let scrollIdentifier = NSUserInterfaceItemIdentifier("configurationBodyScroll")

    /// Distance from the top, for retaining the viewport across a controls rebuild.
    static func distanceFromTop(in window: NSWindow) -> CGFloat {
        guard let scroll = window.contentView?.subviews.first(where: { $0.identifier == scrollIdentifier }) as? NSScrollView,
              let document = scroll.documentView else { return 0 }
        return max(0, document.bounds.height - scroll.contentView.bounds.maxY)
    }

    /// Build body controls using `preferredHeight`, not the window's current height,
    /// then call this once. Views starting at or above `footerHeight` become the body.
    /// `visibleFrame` permits deterministic small-display tests without changing screens.
    static func apply(to window: NSWindow, preferredHeight: CGFloat, footerHeight: CGFloat = 80,
                      distanceFromTop: CGFloat = 0, visibleFrame: NSRect? = nil) {
        guard let content = window.contentView else { return }
        // Also allow reapplying after a display change without nesting scroll views.
        if let existing = content.subviews.first(where: { $0.identifier == scrollIdentifier }) as? NSScrollView {
            for view in existing.documentView?.subviews ?? [] {
                view.removeFromSuperview()
                view.frame.origin.y += footerHeight
                content.addSubview(view)
            }
            existing.removeFromSuperview()
        }
        let screenFrame = visibleFrame ?? window.sheetParent?.screen?.visibleFrame
            ?? window.screen?.visibleFrame ?? NSScreen.main?.visibleFrame
        let chrome = window.frameRect(forContentRect: NSRect(x: 0, y: 0, width: content.bounds.width,
                                                            height: preferredHeight)).height - preferredHeight
        // Leave room for sheet attachment and window placement as well as title chrome.
        let availableHeight = screenFrame.map { max(footerHeight + 80, $0.height - chrome - 48) } ?? preferredHeight
        let height = min(preferredHeight, availableHeight)
        let width = content.bounds.width
        window.setContentSize(NSSize(width: width, height: height))
        guard height < preferredHeight else { return }

        let body = NSView(frame: NSRect(x: 0, y: 0, width: width, height: preferredHeight - footerHeight))
        for view in content.subviews where view.frame.minY >= footerHeight {
            view.removeFromSuperview()
            view.frame.origin.y -= footerHeight
            body.addSubview(view)
        }
        let scroll = NSScrollView(frame: NSRect(x: 0, y: footerHeight, width: width, height: height - footerHeight))
        scroll.identifier = scrollIdentifier
        scroll.hasVerticalScroller = true
        scroll.hasHorizontalScroller = false
        scroll.scrollerStyle = .overlay
        scroll.autohidesScrollers = true
        scroll.drawsBackground = false
        scroll.documentView = body
        scroll.setAccessibilityLabel("Options settings")
        content.addSubview(scroll)
        let maximumOffset = max(0, body.bounds.height - scroll.contentView.bounds.height)
        scroll.contentView.scroll(to: NSPoint(x: 0, y: maximumOffset - min(maximumOffset, max(0, distanceFromTop))))
        scroll.reflectScrolledClipView(scroll.contentView)
    }
}
