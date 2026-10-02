import AppKit

func runPaperSkyTests() {
    let suite = "screensavers.paper-tests.\(UUID().uuidString)"
    let defaults = UserDefaults(suiteName: suite)!
    defer { defaults.removePersistentDomain(forName: suite) }
    let store = SettingsStore(.paperSky, defaults: defaults)
    var settings = SaverSettings()
    settings.paperSky.camera = .side; settings.paperSky.palette = .lagoon
    settings.paperSky.companions = false; settings.paperSky.clouds = 0.25
    store.value = settings
    expect(store.value == settings, "Paper Sky settings survive persistence")
    defaults.set(Data(#"{"cosmos":{"view":"saturn","background":"nebula","angle":"classic","secondsPerView":40,"speed":1,"pixelSize":3,"glow":0.35,"starDensity":0.7,"orbits":true,"labels":true,"asteroids":true},"speed":8}"#.utf8), forKey: "settings.v2")
    expect(store.value.paperSky == PaperSkySettings() && store.value.cosmos.view == .saturn && store.value.cosmos.composition == .varied && store.value.speed == 8,
           "v0.4 records preserve Cosmos and map settings while adding composition and Paper Sky defaults")
    var invalid = PaperSkySettings(); invalid.speed = .nan; invalid.secondsPerView = -.infinity; invalid.clouds = 9; invalid.glow = -4
    let safe = invalid.sanitized()
    expect(safe.speed == 1 && safe.secondsPerView == 45 && safe.clouds == 1 && safe.glow == 0, "Paper Sky clamps invalid settings")

    let size = CGSize(width: 600, height: 400)
    func snapshot(seed: UInt64, camera: PaperCamera = .isometric) -> Data {
        let scene = PaperSkyScene(seed: seed), c = bitmap(width: 600, height: 400)!
        var s = SaverSettings(); s.paperSky.camera = camera
        scene.apply(s); scene.start(); scene.draw(in: c, size: size, time: 0, date: Date(timeIntervalSince1970: 0)); scene.stop()
        return c.makeImage()!.dataProvider!.data! as Data
    }
    let first = snapshot(seed: 42)
    expect(first == snapshot(seed: 42), "seeded Paper Sky renders reproducibly")
    expect(first != snapshot(seed: 91), "different launch seeds produce different skies")
    expect(first != snapshot(seed: 42, camera: .chase) && first != snapshot(seed: 42, camera: .side), "three camera projections have distinct visible geometry")

    let scene = PaperSkyScene(seed: 42), root = CALayer()
    root.bounds = CGRect(origin: .zero, size: size)
    var s = SaverSettings(); s.paperSky.speed = 0; s.paperSky.secondsPerView = 20
    scene.apply(s); scene.start()
    _ = scene.updateLayer(root, size: size, time: 0, date: Date())
    _ = scene.updateLayer(root, size: size, time: 20, date: Date())
    expect(scene.activeCamera == .chase && scene.currentCamera.perspective == 0, "camera change starts continuously at outgoing projection")
    _ = scene.updateLayer(root, size: size, time: 23.5, date: Date())
    near(scene.currentCamera.perspective, 0.5, "camera moves through an intermediate 3D projection")
    _ = scene.updateLayer(root, size: size, time: 27, date: Date())
    expect(scene.currentCamera.perspective == 1 && scene.elapsed == 0, "camera tour continues while flight and palette are paused")
    _ = scene.updateLayer(root, size: size, time: 40, date: Date())
    expect(scene.activeCamera == .side, "journey visits the side-on camera")
    scene.stop()
    _ = scene.updateLayer(root, size: size, time: 1000, date: Date())
    scene.start()
    _ = scene.updateLayer(root, size: size, time: 2000, date: Date())
    expect(scene.activeCamera == .side && scene.elapsed == 0, "stop and restart exclude suspended wall time")
    s.paperSky.camera = .isometric; s.paperSky.speed = 1; scene.apply(s)
    var companionCounts = Set<Int>()
    let paperWorld = root.sublayers![0].sublayers!.first { $0.name == "paper.world" }!
    let layerCount = paperWorld.sublayers!.count
    for frame in 1...850 {
        _ = scene.updateLayer(root, size: size, time: 2000+Double(frame)/10, date: Date())
        companionCounts.insert(scene.visibleCompanions)
    }
    expect(companionCounts.count > 1, "companions arrive and depart over sustained flight")
    expect(root.sublayers!.count == 1 && paperWorld.sublayers!.count == layerCount, "long flight retains a bounded layer tree")
    expect(root.sublayers![0].animationKeys()?.isEmpty ?? true, "frame updates do not enqueue implicit layer animations")
    s.paperSky.companions = false; s.paperSky.clouds = 0; s.paperSky.sun = false; s.paperSky.trails = false; scene.apply(s)
    _ = scene.updateLayer(root, size: CGSize(width: 280, height: 180), time: 2086, date: Date())
    expect(scene.visibleCompanions == 0, "solo flight disables all companions")
    let canvas = root.sublayers![0], world = paperWorld
    expect(canvas.sublayers!.first { $0.name == "paper.sun" }!.isHidden && world.sublayers!.filter { $0.name?.hasPrefix("paper.cloud.") == true }.allSatisfy(\.isHidden), "sun and cloud switches update the live scene")
    expect(canvas.frame.size == CGSize(width: 280, height: 180), "Paper Sky resizes within the host bounds")
    scene.stop()

    // Camera orbits must move persistent cloud volumes, never morph one screen
    // layout into another. Sample the actual layer publication at animation cadence.
    let orbit = PaperSkyScene(seed: 42), orbitRoot = CALayer()
    var orbitSettings = SaverSettings(); orbitSettings.paperSky.secondsPerView = 20
    orbit.apply(orbitSettings); orbit.start()
    _ = orbit.updateLayer(orbitRoot, size: size, time: 0, date: Date())
    let orbitCanvas = orbitRoot.sublayers![0]
    let orbitWorld = orbitCanvas.sublayers!.first { $0.name == "paper.world" }!
    let volumes = orbitWorld.sublayers!.filter { $0.name?.hasPrefix("paper.cloud.") == true }
    let silhouettes = volumes.map { ($0.mask as! CAShapeLayer).path! }
    var previous = volumes.map { ($0.position, $0.opacity) }
    var maxVisibleStep = 0.0, visibleSamples = 0
    var stableShapes = true, finitePositions = true
    for frame in 1...1500 {
        _ = orbit.updateLayer(orbitRoot, size: size, time: Double(frame)/30, date: Date())
        for (i, cloud) in volumes.enumerated() {
            finitePositions = finitePositions && cloud.position.x.isFinite && cloud.position.y.isFinite
            stableShapes = stableShapes && CFEqual((cloud.mask as! CAShapeLayer).path!, silhouettes[i])
            if cloud.opacity > 0.12 && previous[i].1 > 0.12 && cloud.frame.intersects(CGRect(origin: .zero, size: size)) {
                maxVisibleStep = max(maxVisibleStep, hypot(Double(cloud.position.x-previous[i].0.x), Double(cloud.position.y-previous[i].0.y)))
                visibleSamples += 1
            }
            previous[i] = (cloud.position, cloud.opacity)
        }
    }
    expect(volumes.count == 48 && visibleSamples > 100, "orbit continuity samples visible clouds across all three camera modes")
    expect(stableShapes && finitePositions && maxVisibleStep < 12, "clouds retain their silhouettes and continuous positions through camera rotations")
    orbit.stop()

    let solar = PaperSkyScene(seed: 42), solarRoot = CALayer()
    var solarSettings = SaverSettings(); solarSettings.paperSky.camera = .isometric
    solar.apply(solarSettings); solar.start()
    _ = solar.updateLayer(solarRoot, size: size, time: 0, date: Date())
    let solarCanvas = solarRoot.sublayers![0]
    let disc = solarCanvas.sublayers!.first { $0.name == "paper.sun" }!, openingPosition = disc.position
    for frame in 1...600 { _ = solar.updateLayer(solarRoot, size: size, time: Double(frame)/10, date: Date()) }
    let solarTravel = hypot(disc.position.x-openingPosition.x, disc.position.y-openingPosition.y)
    expect(solarTravel > 1 && solarTravel < 25, "sun follows a slow arc even in a fixed camera view")
    solarSettings.paperSky.speed = 0; solar.apply(solarSettings)
    let heldPosition = disc.position
    _ = solar.updateLayer(solarRoot, size: size, time: 61, date: Date())
    expect(disc.position == heldPosition, "zero speed also holds sunlight motion")
    solar.stop()
}
