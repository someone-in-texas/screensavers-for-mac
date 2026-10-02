import ScreenSaver

@objc(StrawberryFieldsForeverView)
final class StrawberryFieldsForeverView: SceneSaverView {
    @objc(initWithFrame:isPreview:)
    init?(frame: NSRect, isPreview: Bool) { super.init(frame: frame, isPreview: isPreview, kind: .strawberryFieldsForever) }
    required init?(coder: NSCoder) { nil }
}
