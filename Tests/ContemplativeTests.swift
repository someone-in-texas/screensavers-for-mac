import AppKit

func runContemplativeTests(){
    func connected(_ count:Int,_ edges:[WorldEdge])->Bool {
        var seen:Set<Int>=[0],pending=[0]
        while let node=pending.popLast(){for edge in edges {let next=edge.a==node ? edge.b:edge.b==node ? edge.a:-1;if next>=0 && !seen.contains(next){seen.insert(next);pending.append(next)}}}
        return seen.count==count
    }
    for seed:UInt64 in [0,42,91,807,UInt64.max] {
        let strawberry=StrawberryWorld(seed:seed,settings:.init()),again=StrawberryWorld(seed:seed,settings:.init())
        expect(strawberry==again,"seed reproduces terrain, plants, roots, stars and camera phase")
        expect(connected(strawberry.nodes.count,strawberry.edges),"underground signal graph is connected")
        expect(strawberry.plants.allSatisfy{$0.position.x>0 && $0.position.x<4000 && $0.position.y>=1050 && $0.position.y<=1500 && $0.scale>0 && $0.scale<2.2},"plants stay in grounded field band")
        expect(strawberry.hills.count==5 && strawberry.hills.allSatisfy{$0.count==61},"bounded layered terrain")
        let research=ResearchWorld(seed:seed,settings:.init())
        expect(research==ResearchWorld(seed:seed,settings:.init()),"seed reproduces cave rooms, rocks, maze and atmosphere")
        expect(connected(research.rooms.count,research.connections),"cave rooms connected by walkways")
        expect(research.rooms.allSatisfy{$0.width>0 && $0.height>0 && $0.center.x>800 && $0.center.x<3200 && $0.center.y>0 && $0.center.y<1200},"procedural chambers stay inside authored cave")
        let maze=research.maze,n=maze.columns*maze.rows
        expect(maze.passages.count==n-1 && connected(n,maze.passages),"perfect maze covers every cell without disconnected paths")
        expect(Set(maze.traversal).count==n && maze.traversal.first==0 && maze.traversal.last==0,"maze agent explores entire tree and returns through actual passages")
        expect(zip(maze.traversal,maze.traversal.dropFirst()).allSatisfy{maze.open($0.0,$0.1)},"every agent move follows an open neighboring passage")
        for t in stride(from:0.0,through:7200,by:17.5){
            let a=maze.agent(t),b=maze.agent(t+0.001)
            expect(a.x>=0.5 && a.x<Double(maze.columns) && a.y>=0.5 && a.y<Double(maze.rows),"maze cursor stays in cell bounds")
            expect(hypot(a.x-b.x,a.y-b.y)<0.005,"maze cursor remains continuous including reverse traversal")
        }
        for balance in StrawberryBalance.allCases {for pace in StrawberryPace.allCases {
            var s=StrawberrySettings();s.balance=balance;s.pace=pace
            for t in stride(from:0.0,through:7200,by:7.75){
                let a=strawberry.camera(t,s),b=strawberry.camera(t+0.01,s)
                expect(hypot(a.x-b.x,a.y-b.y)<0.3 && abs(a.zoom-b.zoom)<0.001,"field/descent/return camera continuous at every pace")
                expect(a.y>500 && a.y<1580 && a.zoom>0.95 && a.zoom<1.12,"camera stays within landscape and chamber safe framing")
            }
        }}
        for pace in ResearchPace.allCases {
            var s=ResearchSettings();s.pace=pace
            for t in stride(from:0.0,through:7200,by:21.5){let a=research.camera(t,s),b=research.camera(t+0.01,s)
                expect(hypot(a.x-b.x,a.y-b.y)<0.25 && a.zoom>0.89 && a.zoom<1.11,"patient camera stays smooth and bounded for long sessions")
                expect((0.995...0.998).contains(research.readiness(t)),"ritual delay never claims a real release or reaches a completion state")
            }
        }
    }
    for seed:UInt64 in [42,91] {
        var settings=StrawberrySettings();settings.lore = .knowing
        let world=StrawberryWorld(seed:seed,settings:settings)
        let hero=world.plants.first {$0.variant==8}!
        expect(hero.fruit==(seed%2==0 ? 3:2),"deliberate fruit triad alternates with the inspection-bench composition")
        settings.lore = .pureArt
        expect(StrawberryWorld(seed:seed,settings:settings).plants.first {$0.variant==8}!.fruit==2,"Pure Art cannot stage the hero triad")
    }
    expect(researchInstrumentTest(),"fictional instrument changes at hour boundaries and deep lore waits for a visible panel")
    var fullField=StrawberrySettings(),fullCave=ResearchSettings()
    fullField.lore = .terminallyOnline;fullField.text = .normal;fullCave.lore = .deepLore;fullCave.text = .lore
    var fieldFragments=Set<String>(),caveFragments=Set<String>()
    for seed:UInt64 in 0..<7 {
        let field=StrawberryWorld(seed:seed,settings:fullField),cave=ResearchWorld(seed:seed,settings:fullCave)
        for slot in 0..<88 {fieldFragments.insert(field.fragment(Double(slot)*125+57,fullField).0)}
        for visit in 0..<9 {for offset in [70.0,170.0] {caveFragments.insert(cave.fragment(Double(visit)*1260+offset,fullCave).0)}}
    }
    let fieldAttributes:[NSAttributedString.Key:Any]=[.font:NSFont.monospacedSystemFont(ofSize:10,weight:.regular),.kern:1.1]
    let terminalAttributes:[NSAttributedString.Key:Any]=[.font:NSFont.monospacedSystemFont(ofSize:10.5,weight:.regular),.kern:1.1]
    expect(fieldFragments.allSatisfy{($0 as NSString).size(withAttributes:fieldAttributes).width<=248},"every field fragment fits its terminal with horizontal padding")
    expect(caveFragments.allSatisfy{($0 as NSString).size(withAttributes:terminalAttributes).width<=280},"every cave fragment fits its instrument panel")
    expect(StrawberryWorld(seed:1,settings:.init()) != StrawberryWorld(seed:2,settings:.init()),"new seed changes the field")
    expect(ResearchWorld(seed:1,settings:.init()) != ResearchWorld(seed:2,settings:.init()),"new seed changes the cave")
    let strawberry=StrawberryWorld(seed:42,settings:.init()),research=ResearchWorld(seed:42,settings:.init())
    var sf=StrawberrySettings(),gr=ResearchSettings();sf.lore = .pureArt;sf.text = .normal;gr.lore = .pureArt;gr.text = .lore
    for t in stride(from:0.0,through:14400,by:1){
        expect(strawberry.fragment(t,sf).0.isEmpty && strawberry.fragment(t,sf).1==0,"Pure Art cannot expose strawberry lore even with text normal")
        expect(research.fragment(t,gr).0.isEmpty && research.fragment(t,gr).1==0,"Pure Art cannot expose cave lore even with lore text")
    }
    sf.lore = .knowing;gr.lore = .subtle
    let deep=["ILYA","DON'T DIE","Q *","PATIENCE BROS","THE CAVE"]
    var sfMessages=Set<String>(),grMessages=Set<String>(),sfVisible=0,grVisible=0
    for t in 0..<7200 {
        let a=strawberry.fragment(Double(t),sf),b=research.fragment(Double(t),gr)
        expect(deep.allSatisfy{!a.0.contains($0) && !b.0.contains($0)},"default lore never shows deep references")
        if a.1>0 {sfMessages.insert(a.0);sfVisible+=1};if b.1>0 {grMessages.insert(b.0);grVisible+=1}
        expect(a.1>=0 && a.1<=1 && b.1>=0 && b.1<=1,"messages smoothly fade within safe opacity")
    }
    expect(sfMessages.contains("READY") && sfMessages.contains("NOT READY"),"contradictory readiness is scheduled as local fiction")
    expect(sfVisible<1000 && grVisible<900,"text leaves long uninterrupted visual intervals")
    sf.text = .none
    expect((0..<7200).allSatisfy{strawberry.fragment(Double($0),sf).0.isEmpty},"text None overrides knowing lore")
    sf.wind = .still
    expect(strawberry.plants.allSatisfy{strawberry.wind(230,$0,sf)==0},"still wind disables all plant swaying")
    for weather in StrawberryWeather.allCases {sf.weather=weather;sf.wind = .breezy
        for t in stride(from:0.0,through:7200,by:2.5){let a=strawberry.weather(t,sf),b=strawberry.weather(t+0.001,sf)
            expect(abs(a-b)<0.001 && a >= -0.36 && a<=0.61,"hype fronts accelerate and decelerate without abrupt weather")
            if weather == .off {expect(a==0,"weather Off is inert")}
            expect(abs(strawberry.wind(t,strawberry.plants[0],sf))<0.05,"wind remains restrained even in a front")
        }
    }
    for i in 0..<8 {for t in stride(from:0.0,through:1000,by:9){let p=strawberry.signal(t,i);expect(p.x>=1000 && p.x<=3200 && p.y>=200 && p.y<=960,"network signals stay inside the connected graph")}}
    var clock=WorldClock();clock.tick(0,running:true);clock.tick(0.1,running:true);clock.pause();clock.tick(900,running:true);near(clock.elapsed,0.1,"suspension excluded from scene clock");clock.tick(.nan,running:true);clock.tick(900.1,running:true);near(clock.elapsed,0.2,"nonfinite host time cannot poison animation")
    var value=SaverSettings();value.strawberry.palette = .softFuture;value.strawberry.seed=UInt64.max;value.research.palette = .sodium;value.research.seedBehavior = .fixed
    expect(try! JSONDecoder().decode(SaverSettings.self,from:JSONEncoder().encode(value))==value,"new settings roundtrip preserves both saver schemas")
    let old=try! JSONDecoder().decode(SaverSettings.self,from:Data("{\"speed\":7}".utf8))
    expect(old.strawberry==StrawberrySettings() && old.research==ResearchSettings() && old.speed==7,"older settings gain new saver defaults without losing existing preferences")
    for palette in StrawberryPalette.allCases {let p=palette.colors;expect([p.sky,p.haze,p.leaf,p.fruit,p.light,p.signal].allSatisfy(\.valid),"all seven field palettes have valid role colors")}
    for palette in ResearchPalette.allCases {let p=palette.colors;expect([p.dark,p.stone,p.paper,p.lamp,p.screen].allSatisfy(\.valid),"all six cave palettes have valid role colors")}
    for scene:SaverScene in [StrawberryFieldsScene(seed:42),GoodResearchScene(seed:42)] {
        let root=CALayer(),size=CGSize(width:800,height:600);root.bounds=CGRect(origin:.zero,size:size)
        scene.start();_ = scene.updateLayer(root,size:size,time:0,date:Date(timeIntervalSince1970:0))
        let canvas=root.sublayers![0],stage=canvas.sublayers![0],count=stage.sublayers!.count
        for frame in 1...10800 {_ = scene.updateLayer(root,size:size,time:Double(frame)/3,date:Date(timeIntervalSince1970:0))}
        let before=stage.position;scene.stop();_ = scene.updateLayer(root,size:size,time:50000,date:Date());scene.start();_ = scene.updateLayer(root,size:size,time:90000,date:Date())
        expect(stage.position==before,"stop and restart excludes sleep time without moving camera")
        expect(root.sublayers?.count==1 && stage.sublayers?.count==count,"long sessions keep bounded layers without accumulating scenery")
        _ = scene.updateLayer(root,size:CGSize(width:300,height:900),time:90000.1,date:Date());expect(stage.position.x.isFinite && stage.position.y.isFinite,"portrait resize preserves finite camera projection")
        scene.stop()
    }
}

private func researchInstrumentTest()->Bool {
    let w=ResearchWorld(seed:42,settings:.init());var s=ResearchSettings();s.lore = .deepLore;s.text = .lore
    return w.experiment(0)==w.experiment(3599) && w.experiment(3599) != w.experiment(3600) && w.fragment(850,s).0.isEmpty && w.fragment(2590,s).0=="PATIENCE BROS" && abs(w.camera(2590,s).x-2040)<30
}
