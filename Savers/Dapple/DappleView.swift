import ScreenSaver

@objc(DappleView)
final class DappleView: SceneSaverView {
    @objc(initWithFrame:isPreview:)
    init?(frame: NSRect, isPreview: Bool) { super.init(frame: frame, isPreview: isPreview, kind: .dapple) }
    required init?(coder: NSCoder) { nil }
}
