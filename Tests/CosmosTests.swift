import AppKit

func runCosmosTests() {
    let suite = "screensavers.cosmos-tests.\(UUID().uuidString)"
    let defaults = UserDefaults(suiteName: suite)!
    defer { defaults.removePersistentDomain(forName: suite) }
    let store = SettingsStore(.voxelCosmos, defaults: defaults)
    expect(Set(SaverKind.allCases.map(\.identifier)).count == 3, "all saver preference domains unique")
    var s = SaverSettings(); s.cosmos.view = .saturn; s.cosmos.background = .aurora; s.cosmos.glow = 0; s.cosmos.angle = .low
    store.value = s
    expect(store.value == s, "cosmos options survive persistence")
    let old = Data(#"{"speed":4,"palette":"night"}"#.utf8)
    defaults.set(old, forKey: "settings.v2")
    expect(store.value.cosmos == CosmosSettings() && store.value.speed == 4, "older appearance records decode cosmos defaults without losing preferences")
    var invalid = CosmosSettings(); invalid.secondsPerView = .infinity; invalid.speed = -1; invalid.glow = .nan; invalid.pixelSize = 900
    let safe = invalid.sanitized()
    expect(safe.secondsPerView == 40 && safe.speed == 0 && safe.glow == 0.35 && safe.pixelSize == 5, "cosmos settings sanitize nonfinite and extreme inputs")
    expect(Set(CosmosView.itinerary.compactMap(\.planet)) == Set(0...7), "grand tour visits every planet")
    for size in [CGSize(width: 7680, height: 4320), CGSize(width: 2000, height: 5000), CGSize(width: 280, height: 180)] {
        let pixels = VoxelCosmosScene.renderSize(size, pixelSize: 2)
        expect(pixels.width <= 800 && pixels.height <= 600, "cosmos pixel buffer is bounded in either orientation")
        expect(abs(pixels.width / pixels.height - size.width / size.height) < 0.02, "cosmos preserves viewport aspect ratio")
    }
    let scene = VoxelCosmosScene(), root = CALayer(), size = CGSize(width: 480, height: 320)
    var paused = SaverSettings(); paused.cosmos.speed = 0; paused.cosmos.secondsPerView = 15
    scene.apply(paused); scene.start()
    CATransaction.begin(); CATransaction.setDisableActions(true)
    _ = scene.updateLayer(root, size: size, time: 0, date: Date())
    let opening = root.sublayers![0].contents as! CGImage
    _ = scene.updateLayer(root, size: size, time: 10, date: Date())
    let held = root.sublayers![0].contents as! CGImage
    expect(opening.dataProvider!.data! as Data == held.dataProvider!.data! as Data, "zero motion holds pixel scene exactly")
    _ = scene.updateLayer(root, size: size, time: 15, date: Date())
    expect(scene.activeView == .earth && root.sublayers![1].opacity == 1, "tour advances with paused motion and retains outgoing image")
    _ = scene.updateLayer(root, size: size, time: 18, date: Date())
    expect(root.sublayers![1].contents == nil, "cosmos dissolve releases outgoing image")
    scene.stop()
    _ = scene.updateLayer(root, size: size, time: 1000, date: Date())
    expect(scene.activeView == .earth, "stopped cosmos does not advance tour")
    scene.start()
    _ = scene.updateLayer(root, size: size, time: 2000, date: Date())
    expect(scene.activeView == .earth, "restart excludes wall time while stopped")
    paused.cosmos.view = .neptune; paused.cosmos.angle = .classic; paused.cosmos.labels = false
    scene.apply(paused)
    _ = scene.updateLayer(root, size: size, time: 2001, date: Date())
    _ = scene.updateLayer(root, size: size, time: 2500, date: Date())
    expect(scene.activeView == .neptune && root.sublayers![2].contents == nil, "fixed view stays selected and captions can be hidden")
    expect(root.sublayers?.count == 3 && root.sublayers![0].magnificationFilter == .nearest, "bounded layer tree preserves crisp pixels")
    scene.stop(); CATransaction.commit()

    let catalog = Array(MapCity.all.prefix(12)), recent = Array(catalog.suffix(8).map(\.name))
    let candidates = MapCity.startupCandidates(recent: recent, catalog: catalog)
    expect(candidates.prefix(4).allSatisfy { !recent.contains($0.name) }, "startup cache search prefers less recent cities")
    expect(candidates.count == catalog.count && candidates.last == catalog.last, "recent cached cities remain an oldest-first fallback")
    expect(CityDriftScene.cityDuration == 120, "default city duration is two minutes")
}
