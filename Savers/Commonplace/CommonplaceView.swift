import ScreenSaver

@objc(CommonplaceView)
final class CommonplaceView: SceneSaverView {
    @objc(initWithFrame:isPreview:)
    init?(frame: NSRect, isPreview: Bool) { super.init(frame: frame, isPreview: isPreview, kind: .commonplace) }
    required init?(coder: NSCoder) { nil }
}
