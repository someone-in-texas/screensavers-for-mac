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
    expect(ChairMotion.occasional.angle(0)==ChairMotion.occasional.angle(35),"occasional turn holds chair between deliberate turns")
    // A new seed must change the outline itself, not only texture or placement.
    for i in 0..<3 {
        expect(FineArtArtwork.fruitPath(i,seed:42) == FineArtArtwork.fruitPath(i,seed:42),"fruit silhouette repeats for a fixed seed")
        expect(FineArtArtwork.fruitPath(i,seed:42) != FineArtArtwork.fruitPath(i,seed:91),"new editions change the strawberry silhouette")
    }
    for seed:UInt64 in [0,42,91,807,UInt64.max] {
        for composition in StrawberryComposition.allCases {
            var settings=StrawberryFineSettings();settings.composition=composition
            let printWorld=StrawberryPrint(seed:seed,settings:settings)
            for (i,form) in printWorld.forms.enumerated() {
                let image=FineArtArtwork.fruit(form,index:i,colors:settings.palette.colors,settings:settings,seed:seed)
                let data=image.dataProvider!.data!
                let intact=withExtendedLifetime(data) {
                    let bytes=CFDataGetBytePtr(data)!,stride=image.bytesPerRow
                    let topBottom=(0..<image.width).allSatisfy{bytes[$0*4+3]==0 && bytes[(image.height-1)*stride+$0*4+3]==0}
                    let sides=(0..<image.height).allSatisfy{bytes[$0*stride+3]==0 && bytes[$0*stride+(image.width-1)*4+3]==0}
                    return topBottom && sides
                }
                expect(intact,"fruit crown and tilted silhouette never clip their cached image (seed \(seed), \(composition), fruit \(i))")
            }
        }
    }
    let organic=StrawberryPrint(seed:42,settings:{var s=StrawberryFineSettings();s.blend = .organic;return s}())
    expect(organic.strokes.allSatisfy{!$0.digital},"organic option contains no circuit terminals")
    let evolving=ResearchPrint(seed:42,settings:ResearchFineSettings()).strokes
    expect(evolving.contains{abs($0.evolution(8,research:true).end-$0.evolution(0,research:true).end)>0.2},"research drawing grows visibly within eight seconds")
    let roots=StrawberryPrint(seed:42,settings:StrawberryFineSettings()).strokes
    expect(roots.contains{abs($0.evolution(8,research:false).end-$0.evolution(0,research:false).end)>0.2},"roots grow visibly within eight seconds")
    expect(roots.allSatisfy{$0.evolution(0,research:false).end==0},"all three strawberries start with ungenerated roots")
    for fruit in 0..<3 {
        expect(roots.filter{$0.family/6==fruit}.contains{$0.evolution(8,research:false).end>0.06},"each strawberry visibly grows from startup")
    }
    for research in [true,false] {
        let paths=research ? evolving:roots
        // Measure growing tips, not camera drift or pulses: no five-second idle
        // window is acceptable during an hour-long default session.
        for t in stride(from:10.0,through:3600,by:5) {
            let active=paths.filter { stroke in
                (0..<5).contains { offset in
                    let a=stroke.evolution(t+Double(offset),research:research),b=stroke.evolution(t+Double(offset)+1,research:research)
                    return a.opacity>0.15 && a.end>0.01 && b.end-a.end>0.004
                }
            }.count
            expect(active >= (research ? 1:6),"meaningful tips keep growing across five seconds at \(t)s (research \(research), active \(active))")
            if research {
                // A deliberate handoff can have one growing trunk while older
                // chambers fade. Require another visible change during it.
                let changing=paths.filter { stroke in
                    (0..<5).contains { offset in
                        let a=stroke.evolution(t+Double(offset),research:true),b=stroke.evolution(t+Double(offset)+1,research:true)
                        return (a.opacity>0.15 && a.end>0.01 && b.end-a.end>0.004) || (a.end>0.2 && abs(b.opacity-a.opacity)>0.015)
                    }
                }.count
                expect(changing>=2,"research handoff keeps growing ink and retiring chambers active at \(t)s")
            }
        }
    }
    let regrown=StrawberryPrint(seed:42,settings:StrawberryFineSettings(),generations:[0:1])
    expect(regrown.forms==StrawberryPrint(seed:42,settings:StrawberryFineSettings()).forms,"branch renewal retains fruit identity and attachment")
    expect(regrown.strokes[0].points != roots[0].points && regrown.strokes[3].points == roots[3].points,"renewal changes one connected root without disturbing its neighbors")
    let redrawn=ResearchPrint(seed:42,settings:ResearchFineSettings(),generations:[0:1])
    expect(redrawn.strokes.map(\.points) != evolving.map(\.points),"research renews its architecture across generations")
    for research in [true,false] {
        for stroke in research ? evolving:roots {
            for t in stride(from:0.0,through:420,by:0.05) {
                let a=stroke.evolution(t,research:research),b=stroke.evolution(t+0.001,research:research)
                expect(a.end.isFinite && a.end>=0 && a.end<=1 && a.opacity>=0 && a.opacity<=1,"growth and fade remain bounded")
                expect(abs(a.end*a.opacity-b.end*b.opacity)<0.002,"family renewal never pops visible ink at a wrap")
            }
        }
    }
    for research in [true,false] {
        let scene=FineArtScene(research:research,seed:42),root=CALayer(),size=CGSize(width:800,height:600)
        root.bounds=CGRect(origin:.zero,size:size);scene.start()
        _=scene.updateLayer(root,size:size,time:0,date:Date())
        let canvas=root.sublayers![0],stage=canvas.sublayers!.last!,count=stage.sublayers!.count
        if research {
            let mapped=stage.convert(scene.artworkCenter,to:canvas)
            expect(abs(mapped.x-size.width/2)<0.01 && abs(mapped.y-size.height/2)<0.01,"actual chair-and-maze bounds are centered at startup")
            let chair=stage.sublayers!.last!
            expect(chair.contents==nil && (chair.sublayers?.compactMap{$0 as? CAShapeLayer}.count ?? 0)>30,"chair is native vector ink rather than a resized bitmap")
        }
        let initialCenter=scene.artworkCenter
        for frame in 1...14400 {_=scene.updateLayer(root,size:size,time:Double(frame)/4,date:Date())}
        expect(scene.artworkCenter==initialCenter && scene.renewalCount>50,"long sessions renew drawings without chasing their changing bounds")
        expect(stage.sublayers?.count==count && root.sublayers?.count==1,"one-hour animation retains bounded layer count")
        for l in stage.sublayers!.compactMap({$0 as? CAShapeLayer}) {expect(l.strokeEnd.isFinite && l.strokeEnd>=0 && l.strokeEnd<=1,"long-running line evolution stays finite")}
        scene.stop();let angle=scene.chairAngle;_=scene.updateLayer(root,size:size,time:90000,date:Date());expect(scene.chairAngle==angle,"stopped artwork does not advance")
        for dims in [CGSize(width:280,height:180),CGSize(width:800,height:1400),CGSize(width:3440,height:1440)] {_=scene.updateLayer(root,size:dims,time:90000,date:Date());expect(stage.position.x.isFinite && stage.position.y.isFinite && stage.frame.height<=dims.height,"resizing fits the whole composition")}
        // Reproduce the host lifecycle: offset screen origin, tiny preview,
        // Retina/full screen, settings rebuild while scaled, and reparenting.
        for origin in [CGPoint.zero,CGPoint(x:1920,y:1080),CGPoint(x:-1440,y:300)] {
            for dims in [CGSize(width:280,height:180),CGSize(width:2560,height:1440),CGSize(width:800,height:1400)] {
                root.bounds=CGRect(origin:origin,size:dims);root.contentsScale=2
                var v=SaverSettings();v.strawberry.seed=91;v.research.seed=91;scene.apply(v)
                _=scene.updateLayer(root,size:dims,time:90000,date:Date())
                expect(canvas.bounds.origin == .zero && canvas.position == CGPoint(x:origin.x+dims.width/2,y:origin.y+dims.height/2),"host bounds origin never leaks into local artwork coordinates")
                expect(abs(stage.position.x-dims.width/2)<dims.width*0.05 && abs(stage.position.y-dims.height/2)<dims.height*0.05,"reused and rebuilt prints remain centered after preview-to-display resize")
                let needed=max(1,root.contentsScale*stage.transform.m11)
                expect(stage.sublayers!.compactMap{$0 as? CAShapeLayer}.allSatisfy{$0.contentsScale>=needed},"ink resolves enough pixels for Retina after a display resize")
                for subject in stage.sublayers!.filter({$0.contents != nil}) {
                    let image=subject.contents as! CGImage
                    expect(Double(image.width)>=subject.bounds.width*needed,"cached subject supplies enough pixels at the effective display scale")
                }
            }
        }
        let other=CALayer();other.bounds=CGRect(x:300,y:200,width:1920,height:1080)
        _=scene.updateLayer(other,size:other.bounds.size,time:90000,date:Date())
        expect(other.sublayers?.count==1 && canvas.superlayer === other,"existing print reparents without losing its centered canvas")
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
