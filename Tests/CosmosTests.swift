import AppKit

func runCosmosTests() {
    let suite = "screensavers.cosmos-tests.\(UUID().uuidString)"
    let defaults = UserDefaults(suiteName: suite)!
    defer { defaults.removePersistentDomain(forName: suite) }
    let store = SettingsStore(.voxelCosmos, defaults: defaults)
    expect(Set(SaverKind.allCases.map(\.identifier)).count == SaverKind.allCases.count, "all saver preference domains unique")
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
        let closeUp = VoxelCosmosScene.renderSize(size, pixelSize: 2, closeUp: true)
        expect(closeUp.width > pixels.width && closeUp.width <= 1000 && closeUp.height <= 750, "close-ups add modest detail within bounded buffers")
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

    // A fixed sculpture must not progressively rescale or crawl across the pixel grid.
    let steady = VoxelCosmosScene(), steadyRoot = CALayer()
    var fixed = SaverSettings(); fixed.cosmos.view = .mercury; fixed.cosmos.angle = .classic
    fixed.cosmos.composition = .centered; fixed.cosmos.background = .void; fixed.cosmos.glow = 0; fixed.cosmos.labels = false
    steady.apply(fixed); steady.start()
    _ = steady.updateLayer(steadyRoot, size: size, time: 0, date: Date())
    let fixedFrame = steadyRoot.sublayers![0].contents as! CGImage
    let fixedBytes = fixedFrame.dataProvider!.data! as Data
    for i in 1...80 { _ = steady.updateLayer(steadyRoot, size: size, time: Double(i)/10, date: Date()) }
    let rotatedBytes = (steadyRoot.sublayers![0].contents as! CGImage).dataProvider!.data! as Data
    expect(fixedBytes != rotatedBytes, "close-up surface rotates even without a moon")
    func silhouette(_ data: Data) -> [Bool] {
        let bytes = [UInt8](data)
        return stride(from: 0, to: bytes.count, by: 4).map { bytes[$0] != 0 || bytes[$0+1] != 0 || bytes[$0+2] != 0 }
    }
    expect(silhouette(fixedBytes) == silhouette(rotatedBytes), "rotation preserves the exact silhouette without zoom or pixel crawl")
    expect(fixedBytes == fixedFrame.dataProvider!.data! as Data, "published frame remains immutable after subsequent rendering")
    steady.stop()
    _ = steady.updateLayer(steadyRoot, size: size, time: 1000, date: Date())
    expect(rotatedBytes == (steadyRoot.sublayers![0].contents as! CGImage).dataProvider!.data! as Data, "stopped close-up holds its rotation")
    steady.start()
    _ = steady.updateLayer(steadyRoot, size: size, time: 1001, date: Date())
    expect(rotatedBytes == (steadyRoot.sublayers![0].contents as! CGImage).dataProvider!.data! as Data, "resuming rotation excludes paused wall time")
    fixed.cosmos.view = .earth; steady.apply(fixed)
    _ = steady.updateLayer(steadyRoot, size: size, time: 9, date: Date())
    let movingFrame = steadyRoot.sublayers![0].contents as! CGImage
    let movingBytes = movingFrame.dataProvider!.data! as Data
    for i in 1...100 { _ = steady.updateLayer(steadyRoot, size: size, time: 9+Double(i)/10, date: Date()) }
    expect(movingBytes != (steadyRoot.sublayers![0].contents as! CGImage).dataProvider!.data! as Data, "orbiting moon changes complete frames")
    expect(movingBytes == movingFrame.dataProvider!.data! as Data, "a retained moving frame never borrows mutable back-buffer pixels")
    steady.stop(); fixed.cosmos.view = .mercury
    var anchors = Set<String>()
    let compositionScene = VoxelCosmosScene()
    fixed.cosmos.composition = .varied; fixed.cosmos.secondsPerView = 15
    compositionScene.apply(fixed); compositionScene.start()
    for i in 0..<6 {
        _ = compositionScene.updateLayer(steadyRoot, size: size, time: Double(i)*15, date: Date())
        anchors.insert("\(compositionScene.compositionAnchor)")
    }
    expect(anchors.count == 5, "composition tour includes center and all four quadrants")
    compositionScene.stop()
    for view in [CosmosView.innerPlanets, .outerPlanets] {
        let system = VoxelCosmosScene(), systemRoot = CALayer()
        var settings = fixed; settings.cosmos.view = view; settings.cosmos.asteroids = false; settings.cosmos.orbits = false
        system.apply(settings); system.start()
        _ = system.updateLayer(systemRoot, size: size, time: 0, date: Date())
        let image = systemRoot.sublayers![0].contents as! CGImage
        let bytes = [UInt8](image.dataProvider!.data! as Data)
        let offset = (image.height/2)*image.bytesPerRow + (image.width/2)*4
        let centerIsBlack = bytes[offset] == 0 && bytes[offset+1] == 0 && bytes[offset+2] == 0
        expect(centerIsBlack == (view == .outerPlanets), "only inner planets retain the central Sun, even with guides and labels disabled")
        system.stop()
    }
    for composition in CosmosComposition.allCases where composition != .varied {
        fixed.cosmos.composition = composition; steady.apply(fixed)
        _ = steady.updateLayer(steadyRoot, size: size, time: 0, date: Date())
        let frame = steadyRoot.sublayers![0].contents as! CGImage
        let data = [UInt8](frame.dataProvider!.data! as Data)
        var xSum = 0.0, count = 0.0
        for y in 0..<frame.height { for x in 0..<frame.width {
            let offset = y*frame.bytesPerRow+x*4
            if data[offset] > 20 || data[offset+1] > 20 || data[offset+2] > 20 { xSum += Double(x); count += 1 }
        } }
        expect(count > 0 && abs(xSum/count/Double(frame.width)-composition.anchor.x) < 0.05, "rendered planet follows requested composition, not a host corner")
    }

    let catalog = Array(MapCity.all.prefix(12)), recent = Array(catalog.suffix(8).map(\.name))
    let candidates = MapCity.startupCandidates(recent: recent, catalog: catalog)
    expect(candidates.prefix(4).allSatisfy { !recent.contains($0.name) }, "startup cache search prefers less recent cities")
    expect(candidates.count == catalog.count && candidates.last == catalog.last, "recent cached cities remain an oldest-first fallback")
    expect(CityDriftScene.cityDuration == 120, "default city duration is two minutes")
}
