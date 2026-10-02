import ScreenSaver

@objc(GoodResearchTakesTimeView)
final class GoodResearchTakesTimeView: SceneSaverView {
    @objc(initWithFrame:isPreview:)
    init?(frame: NSRect, isPreview: Bool) { super.init(frame: frame, isPreview: isPreview, kind: .goodResearchTakesTime) }
    required init?(coder: NSCoder) { nil }
}
