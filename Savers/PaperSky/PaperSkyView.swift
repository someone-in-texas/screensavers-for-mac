import ScreenSaver

@objc(PaperSkyView)
final class PaperSkyView: SceneSaverView {
    @objc(initWithFrame:isPreview:)
    init?(frame: NSRect, isPreview: Bool) { super.init(frame: frame, isPreview: isPreview, kind: .paperSky) }
    required init?(coder: NSCoder) { nil }
}
