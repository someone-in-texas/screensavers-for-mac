import ScreenSaver

@objc(FlourishView)
final class FlourishView: SceneSaverView {
    @objc(initWithFrame:isPreview:)
    init?(frame: NSRect, isPreview: Bool) { super.init(frame: frame, isPreview: isPreview, kind: .flourish) }
    required init?(coder: NSCoder) { nil }
}
