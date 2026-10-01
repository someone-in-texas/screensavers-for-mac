import Foundation

struct MapCity: Equatable {
    let name: String
    let region: String
    let latitude: Double
    let longitude: Double
    let zoom: Int
    init(_ name: String, _ region: String, _ latitude: Double, _ longitude: Double, _ zoom: Int = 14) {
        self.name = name; self.region = region; self.latitude = latitude; self.longitude = longitude; self.zoom = zoom
    }
    static let all: [MapCity] = [
        .init("Tokyo", "Japan", 35.6812, 139.7671), .init("Kyoto", "Japan", 35.004, 135.768),
        .init("Osaka", "Japan", 34.686, 135.502), .init("Seoul", "South Korea", 37.566, 126.978),
        .init("Taipei", "Taiwan", 25.041, 121.532), .init("Hong Kong", "Hong Kong", 22.285, 114.158),
        .init("Singapore", "Singapore", 1.29, 103.851), .init("Bangkok", "Thailand", 13.75, 100.501),
        .init("Hanoi", "Vietnam", 21.029, 105.852), .init("Kuala Lumpur", "Malaysia", 3.15, 101.696),
        .init("Mumbai", "India", 18.94, 72.835), .init("Delhi", "India", 28.632, 77.219),
        .init("Jaipur", "India", 26.925, 75.823), .init("Dhaka", "Bangladesh", 23.728, 90.407),
        .init("Kathmandu", "Nepal", 27.708, 85.306), .init("Dubai", "UAE", 25.195, 55.276),
        .init("Istanbul", "Türkiye", 41.017, 28.974), .init("Jerusalem", "Jerusalem", 31.778, 35.231),
        .init("Paris", "France", 48.857, 2.352), .init("London", "United Kingdom", 51.507, -0.128),
        .init("Rome", "Italy", 41.897, 12.473), .init("Venice", "Italy", 45.437, 12.335),
        .init("Barcelona", "Spain", 41.392, 2.166), .init("Madrid", "Spain", 40.417, -3.704),
        .init("Lisbon", "Portugal", 38.712, -9.139), .init("Amsterdam", "Netherlands", 52.371, 4.895),
        .init("Copenhagen", "Denmark", 55.679, 12.569), .init("Stockholm", "Sweden", 59.327, 18.068),
        .init("Helsinki", "Finland", 60.17, 24.948), .init("Reykjavík", "Iceland", 64.147, -21.94),
        .init("Berlin", "Germany", 52.52, 13.405), .init("Prague", "Czechia", 50.087, 14.421),
        .init("Vienna", "Austria", 48.208, 16.373), .init("Budapest", "Hungary", 47.499, 19.045),
        .init("Athens", "Greece", 37.975, 23.735), .init("New York", "United States", 40.729, -73.99),
        .init("Chicago", "United States", 41.886, -87.63), .init("Dallas", "United States", 32.783, -96.8),
        .init("Austin", "United States", 30.268, -97.744), .init("San Francisco", "United States", 37.783, -122.417),
        .init("Seattle", "United States", 47.607, -122.336), .init("Boston", "United States", 42.357, -71.061),
        .init("New Orleans", "United States", 29.957, -90.066), .init("Washington", "United States", 38.899, -77.036),
        .init("Montréal", "Canada", 45.508, -73.567), .init("Vancouver", "Canada", 49.282, -123.12),
        .init("Mexico City", "Mexico", 19.433, -99.133), .init("Havana", "Cuba", 23.138, -82.357),
        .init("Buenos Aires", "Argentina", -34.607, -58.384), .init("São Paulo", "Brazil", -23.551, -46.634),
        .init("Rio de Janeiro", "Brazil", -22.907, -43.177), .init("Lima", "Peru", -12.047, -77.032),
        .init("Santiago", "Chile", -33.438, -70.65), .init("Bogotá", "Colombia", 4.599, -74.075),
        .init("Cairo", "Egypt", 30.047, 31.236), .init("Marrakesh", "Morocco", 31.628, -7.989),
        .init("Nairobi", "Kenya", -1.286, 36.822), .init("Cape Town", "South Africa", -33.924, 18.424),
        .init("Dakar", "Senegal", 14.671, -17.435), .init("Accra", "Ghana", 5.557, -0.202),
        .init("Sydney", "Australia", -33.867, 151.208), .init("Melbourne", "Australia", -37.814, 144.963),
        .init("Auckland", "New Zealand", -36.848, 174.764), .init("Wellington", "New Zealand", -41.29, 174.779)
    ]
    static func choose(recent: [String], randomIndex: (Int) -> Int = { Int.random(in: 0..<$0) }) -> MapCity {
        let candidates = all.filter { !recent.suffix(8).contains($0.name) }
        let pool = candidates.isEmpty ? all : candidates
        return pool[max(0, min(pool.count - 1, randomIndex(pool.count)))]
    }
}
