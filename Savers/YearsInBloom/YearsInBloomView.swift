import ScreenSaver

@objc(YearsInBloomView)
final class YearsInBloomView: SceneSaverView {
    @objc(initWithFrame:isPreview:)
    init?(frame: NSRect, isPreview: Bool) { super.init(frame: frame, isPreview: isPreview, kind: .yearsInBloom) }
    required init?(coder: NSCoder) { nil }
}
