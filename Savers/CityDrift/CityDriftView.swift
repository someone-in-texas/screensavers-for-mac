import AppKit
import ScreenSaver

@objc(CityDriftView)
final class CityDriftView: SceneSaverView {
    @objc(initWithFrame:isPreview:) init?(frame: NSRect, isPreview: Bool) { super.init(frame: frame, isPreview: isPreview, kind: .cityDrift) }
    required init?(coder: NSCoder) { nil }
}
