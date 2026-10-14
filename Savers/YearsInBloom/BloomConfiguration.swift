import AppKit
final class BloomConfiguration: NotebookConfiguration {
    override func populate() {
        let s = store.value.bloom
        choice("Plant",value:s.plant,titles:BloomPlant.allCases.map(\.title)) { $0.bloom.plant = $1 }
        choice("Composition",value:s.layout) { $0.bloom.layout = $1 }
        choice("Palette",value:s.palette) { $0.bloom.palette = $1 }
        choice("Rendering",value:s.art.rendering,titles:BloomRendering.allCases.map(\.title)) { $0.bloom.art.rendering = $1 }
        choice("Pace",value:s.pace) { $0.bloom.pace = $1 }
        choice("Weather",value:s.weather) { $0.bloom.weather = $1 }
        choice("Paper texture",value:s.texture) { $0.bloom.texture = $1 }
        choice("Season emphasis",value:s.emphasis) { $0.bloom.emphasis = $1 }
        note("An illustrated garden across five years. Plants grow, rest and begin again. Season emphasis lengthens a season; the year keeps turning. Entirely offline.",height:72)
    }
}
