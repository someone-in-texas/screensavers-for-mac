import AppKit

func runFineArtTests() {
    let fresh=SaverSettings()
    expect(!fresh.research.loreMode && !fresh.strawberry.loreMode,"fine artwork is default for both savers")
    let old=Data("{\"research\":{\"seed\":91,\"palette\":\"archive\",\"lore\":\"deepLore\"},\"strawberry\":{\"seed\":807,\"palette\":\"moonlit\",\"balance\":\"moreBasement\"},\"speed\":9}".utf8)
    let migrated=try! JSONDecoder().decode(SaverSettings.self,from:old)
    expect(migrated.research.seed==91 && migrated.research.palette == .archive && migrated.research.lore == .deepLore,"legacy research keys survive migration")
    expect(migrated.strawberry.seed==807 && migrated.strawberry.palette == .moonlit && migrated.strawberry.balance == .moreBasement,"legacy strawberry keys survive migration")
    expect(!migrated.research.loreMode && !migrated.strawberry.loreMode && migrated.speed==9,"migration introduces fine art without activating hidden mode or losing unrelated values")
    let malformed=try! JSONDecoder().decode(SaverSettings.self,from:Data("{\"research\":{\"palette\":\"unknown\",\"seed\":32},\"strawberry\":{\"loreMode\":\"bad\",\"seed\":4}}".utf8))
    expect(malformed.research.seed==32 && malformed.strawberry.seed==4,"invalid individual values do not erase the whole settings record")
    let suite="fine-art-tests.\(UUID().uuidString)",defaults=UserDefaults(suiteName:suite)!
    defer {defaults.removePersistentDomain(forName:suite)}
    defaults.set(old,forKey:"settings.v2")
    let store=SettingsStore(.goodResearchTakesTime,defaults:defaults)
    var saved=store.value;saved.research.loreMode=true;saved.strawberry.fineArt.blend = .synthetic;saved.research.fineArt.composition = .radial
    store.value=saved;expect(store.value==saved,"mode and namespaced fine settings persist alongside original preferences")
    store.reset();expect(store.value==fresh,"reset restores fine art")
    _ = NSApplication.shared
    for kind in [SaverKind.goodResearchTakesTime,.strawberryFieldsForever] {
        let panelStore=SettingsStore(kind,defaults:defaults);panelStore.reset()
        var callbacks=0
        let panel=ConfigurationController(store:panelStore){_ in callbacks += 1}
        func labels()->[String] {panel.window!.contentView!.subviews.compactMap {($0 as? NSTextField)?.stringValue}}
        expect(!labels().contains("Enable Lore Mode"),"ordinary Options does not advertise the easter egg")
        (panel.window as? ConfigurationWindow)?.revealAlternate?()
        expect(labels().contains("Enable Lore Mode"),"modifier discovery reveals the alternate checkbox")
        let toggle=panel.window!.contentView!.subviews.compactMap{$0 as? NSButton}.first{$0.accessibilityLabel()=="Enable Lore Mode"}!
        toggle.performClick(nil)
        expect(callbacks==1 && (kind == .goodResearchTakesTime ? panelStore.value.research.loreMode:panelStore.value.strawberry.loreMode),"checkbox persists enabled mode and publishes the change")
        expect(labels().contains("Lore density") && !labels().contains("Composition"),"alternate panel replaces fine-art rows with compact legacy controls")
        let off=panel.window!.contentView!.subviews.compactMap{$0 as? NSButton}.first{$0.accessibilityLabel()=="Enable Lore Mode"}!
        off.performClick(nil);panel.prepareForPresentation()
        expect(!labels().contains("Enable Lore Mode") && labels().contains("Composition"),"leaving alternate mode and reopening restores the undisclosed panel")
        panel.close()
    }
    for p in ResearchGround.allCases {expect([p.colors.ground,p.colors.ink,p.colors.pigment].allSatisfy(\.valid),"research fine palette is valid")}
    for p in StrawberryGround.allCases {expect([p.colors.ground,p.colors.ink,p.colors.pigment].allSatisfy(\.valid),"strawberry fine palette is valid")}
    for seed:UInt64 in [0,42,91,807,UInt64.max] {
        for composition in ResearchComposition.allCases {for drawing in ResearchDrawing.allCases {
            var s=ResearchFineSettings();s.composition=composition;s.drawing=drawing;s.density = .dense
            let a=ResearchPrint(seed:seed,settings:s),b=ResearchPrint(seed:seed,settings:s)
            expect(a.strokes.map(\.points)==b.strokes.map(\.points),"research drawing reproduces seeded geometry")
            expect(a.strokes.count<50 && a.strokes.allSatisfy{CGRect(x:100,y:80,width:1400,height:820).contains($0.path.boundingBoxOfPath)},"all drawing archetypes stay within quiet margins with bounded geometry")
        }}
        for composition in StrawberryComposition.allCases {for blend in RootBlend.allCases {
            var s=StrawberryFineSettings();s.composition=composition;s.blend=blend
            let a=StrawberryPrint(seed:seed,settings:s),b=StrawberryPrint(seed:seed,settings:s)
            expect(a.forms.count==3 && a.forms==b.forms && a.strokes.map(\.points)==b.strokes.map(\.points),"exactly three reproducible forms and root networks")
            expect(a.strokes.count<60 && a.strokes.allSatisfy{CGRect(x:100,y:80,width:1400,height:820).contains($0.path.boundingBoxOfPath)},"all roots remain within composition bounds")
        }}
    }
    for motion in ChairMotion.allCases {
        for t in stride(from:0.0,through:86400,by:0.23) {
            let a=motion.angle(t),b=motion.angle(t+0.001)
            expect(a.isFinite && abs(a-b)<0.0001,"chair motion continuous over day-long sessions and cycle boundaries")
        }
        expect(motion.angle(.nan).isFinite && motion.angle(.infinity).isFinite,"invalid time cannot poison chair projection")
    }
    expect(ChairMotion.occasional.angle(0)==ChairMotion.occasional.angle(200),"occasional turn holds chair still for several minutes")
    for research in [true,false] {
        let scene=FineArtScene(research:research,seed:42),root=CALayer(),size=CGSize(width:800,height:600)
        root.bounds=CGRect(origin:.zero,size:size);scene.start()
        _=scene.updateLayer(root,size:size,time:0,date:Date())
        let canvas=root.sublayers![0],stage=canvas.sublayers![0],count=stage.sublayers!.count
        for frame in 1...14400 {_=scene.updateLayer(root,size:size,time:Double(frame)/4,date:Date())}
        expect(stage.sublayers?.count==count && root.sublayers?.count==1,"one-hour animation retains bounded layer count")
        for l in stage.sublayers!.compactMap({$0 as? CAShapeLayer}) {expect(l.strokeEnd.isFinite && l.strokeEnd>=0 && l.strokeEnd<=1,"long-running line evolution stays finite")}
        scene.stop();let angle=scene.chairAngle;_=scene.updateLayer(root,size:size,time:90000,date:Date());expect(scene.chairAngle==angle,"stopped artwork does not advance")
        for dims in [CGSize(width:280,height:180),CGSize(width:800,height:1400),CGSize(width:3440,height:1440)] {_=scene.updateLayer(root,size:dims,time:90000,date:Date());expect(stage.position.x.isFinite && stage.position.y.isFinite && stage.frame.height<=dims.height,"resizing fits the whole composition")}
        let wrapper:SaverScene=research ? GoodResearchScene(seed:42):StrawberryFieldsScene(seed:42)
        wrapper.start()
        for enabled in [false,true,false,true,false] {
            var v=SaverSettings();v.research.loreMode=enabled;v.strawberry.loreMode=enabled;wrapper.apply(v)
            let target=CALayer();target.bounds=CGRect(origin:.zero,size:size)
            _=wrapper.updateLayer(target,size:size,time:0,date:Date())
            // Exercise both toggles on the SAME live root, not only scene construction.
            v.research.loreMode = !enabled;v.strawberry.loreMode = !enabled;wrapper.apply(v)
            _=wrapper.updateLayer(target,size:size,time:0.1,date:Date())
            expect(target.sublayers?.count==1,"mode switch removes previous renderer on a live root")
        }
        wrapper.stop()
    }
}
