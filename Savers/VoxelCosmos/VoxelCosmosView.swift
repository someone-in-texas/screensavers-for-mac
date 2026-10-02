import AppKit
import ScreenSaver

@objc(VoxelCosmosView)
final class VoxelCosmosView: SceneSaverView {
    @objc(initWithFrame:isPreview:) init?(frame: NSRect, isPreview: Bool) { super.init(frame: frame, isPreview: isPreview, kind: .voxelCosmos) }
    required init?(coder: NSCoder) { nil }
}
