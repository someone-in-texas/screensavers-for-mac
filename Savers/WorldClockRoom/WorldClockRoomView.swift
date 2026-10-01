import AppKit
import ScreenSaver

@objc(WorldClockRoomView)
final class WorldClockRoomView: SceneSaverView {
    @objc(initWithFrame:isPreview:) init?(frame: NSRect, isPreview: Bool) { super.init(frame: frame, isPreview: isPreview, kind: .worldClockRoom) }
    required init?(coder: NSCoder) { nil }
}
