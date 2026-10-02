import ScreenSaver

@objc(LatticeView)
final class LatticeView: SceneSaverView {
    @objc(initWithFrame:isPreview:)
    init?(frame: NSRect, isPreview: Bool) { super.init(frame: frame, isPreview: isPreview, kind: .lattice) }
    required init?(coder: NSCoder) { nil }
}
