import CoreLocation
#if !os(watchOS)
import MapKit
#endif
import SwiftUI

/* The weather outside, for the sky painted behind the page. It comes from
   Open-Meteo, which wants no key and no account, for roughly where the phone
   is: the position is rounded to about a kilometre before it is sent. Without
   leave to use the location, or without a connection, there is simply no
   weather and the page keeps its plain background. */

/// What the sky is doing, cut down from the WMO codes Open-Meteo reports.
enum Sky: String, Codable, CaseIterable {
    case clear, mostlyClear, partlyCloudy, overcast, fog, drizzle, rain, heavyRain, snow, thunderstorm

    init(wmo code: Int) {
        switch code {
        case 0: self = .clear
        case 1: self = .mostlyClear
        case 2: self = .partlyCloudy
        case 45, 48: self = .fog
        case 51...57: self = .drizzle
        case 65, 67, 82: self = .heavyRain
        case 61...67, 80, 81: self = .rain
        case 71...77, 85, 86: self = .snow
        case 95...99: self = .thunderstorm
        default: self = .overcast   // 3, and anything new
        }
    }

    func label(isDay: Bool) -> String {
        switch self {
        case .clear: isDay ? "Sunny" : "Clear"
        case .mostlyClear: isDay ? "Mostly sunny" : "Mostly clear"
        case .partlyCloudy: "Partly cloudy"
        case .overcast: "Cloudy"
        case .fog: "Fog"
        case .drizzle: "Drizzle"
        case .rain: "Rain"
        case .heavyRain: "Heavy rain"
        case .snow: "Snow"
        case .thunderstorm: "Thunderstorm"
        }
    }

    func symbol(isDay: Bool) -> String {
        switch self {
        case .clear: isDay ? "sun.max" : "moon.stars"
        case .mostlyClear, .partlyCloudy: isDay ? "cloud.sun" : "cloud.moon"
        case .overcast: "cloud"
        case .fog: "cloud.fog"
        case .drizzle: "cloud.drizzle"
        case .rain: "cloud.rain"
        case .heavyRain: "cloud.heavyrain"
        case .snow: "cloud.snow"
        case .thunderstorm: "cloud.bolt.rain"
        }
    }
}

/// Where the sun is in its day: up, down, or the half hour or so either side
/// of its rising and setting.
enum DayPhase: String, CaseIterable {
    case day, twilight, night
}

struct Weather: Codable, Equatable {
    var sky: Sky
    /// Degrees Celsius, as Open-Meteo gives them.
    var temperature: Double
    var high: Double?
    var low: Double?
    /// km/h.
    var wind: Double
    var isDay: Bool
    var sunrise: Date?
    var sunset: Date?
    var place = ""
    var fetched = Date.now

    /// Worked out from today's sunrise and sunset, so the sky turns between
    /// one reading and the next.
    func phase(at now: Date) -> DayPhase {
        guard let sunrise, let sunset else { return isDay ? .day : .night }
        let edge: TimeInterval = 40 * 60
        if abs(now.timeIntervalSince(sunrise)) < edge || abs(now.timeIntervalSince(sunset)) < edge { return .twilight }
        return sunrise < now && now < sunset ? .day : .night
    }

    /// "24°C", or "75°" where Fahrenheit is the custom.
    static func degrees(_ celsius: Double) -> String {
        Measurement(value: celsius, unit: UnitTemperature.celsius)
            .formatted(.measurement(width: .narrow, usage: .weather, numberFormatStyle: .number.precision(.fractionLength(0))))
    }
}

/// Fetches the weather and keeps it while the app is open.
@MainActor @Observable
final class WeatherModel {
    private(set) var current: Weather?
    private var lastTry = Date.distantPast

    private static let saveKey = "weather"
    /// A reading older than this says nothing about the sky now.
    private static let shelfLife: TimeInterval = 3 * 3600

    init() {
        current = Self.demo ?? Self.saved()
    }

    /// Fetch again if the last go is ten minutes old, or half a minute when
    /// there is nothing to show yet.
    func refresh() async {
        guard Self.demo == nil else { return }
        guard Date.now.timeIntervalSince(lastTry) > (current == nil ? 30 : 600) else { return }
        lastTry = .now
        if let location = await Self.whereabouts(), var weather = try? await Self.fetch(location.coordinate) {
            // the sky first; the name of the place can follow
            weather.place = current?.place ?? ""
            current = weather
            save()
            if let place = await Self.placeName(location) {
                current?.place = place
                save()
            }
        }
        if let current, Date.now.timeIntervalSince(current.fetched) > Self.shelfLife { self.current = nil }
    }

    private func save() {
        UserDefaults.standard.set(try? JSONEncoder().encode(current), forKey: Self.saveKey)
    }

    // MARK: Where

    /* A simulator has no position unless one is set for it by hand, and
       loses the one it had when it is erased; without a position there is no
       weather, and without the weather the page has no sky, which is the
       first thing the phone's page has. So in a simulator a fix that does
       not come is made up for with the middle of Taipei, and is not waited
       on for long. On a phone or a watch none of this is compiled in. */
    #if targetEnvironment(simulator)
    private static let patience = 5.0
    private static let standIn: CLLocation? = CLLocation(latitude: 25.04, longitude: 121.56)
    #else
    private static let patience = 30.0
    private static let standIn: CLLocation? = nil
    #endif

    /// One fix on the phone's position, or nil when it is refused or slow.
    private static func whereabouts() async -> CLLocation? {
        #if os(macOS)
        if asker.authorizationStatus == .notDetermined { asker.requestWhenInUseAuthorization() }
        #endif
        return await fix() ?? standIn
    }

    #if os(macOS)
    /// A Mac has no service session to ask leave with, so it is asked the
    /// older way, by a manager kept for as long as the app runs; the updates
    /// below wait on the answer.
    private static let asker = CLLocationManager()
    #endif

    private static func fix() async -> CLLocation? {
        await withTaskGroup(of: CLLocation?.self) { group in
            group.addTask {
                #if !os(macOS)
                // asks for leave to use the location the first time
                let session = CLServiceSession(authorization: .whenInUse)
                defer { session.invalidate() }
                #endif
                let settled = try? await CLLocationUpdate.liveUpdates().first { update in
                    update.location != nil || update.authorizationDenied || update.authorizationDeniedGlobally
                        || update.authorizationRestricted
                }
                return settled?.location
            }
            group.addTask {
                try? await Task.sleep(for: .seconds(patience))
                return nil
            }
            let first = await group.next() ?? nil
            group.cancelAll()
            return first
        }
    }

    private static func placeName(_ location: CLLocation) async -> String? {
        #if os(watchOS)
        // the watch shows the sky and not where it is over
        return nil
        #else
        guard let request = MKReverseGeocodingRequest(location: location) else { return nil }
        return try? await request.mapItems.first?.addressRepresentations?.cityName
        #endif
    }

    // MARK: What

    private struct Report: Decodable {
        struct Current: Decodable {
            let temperature: Double
            let isDay: Int
            let code: Int
            let wind: Double

            enum CodingKeys: String, CodingKey {
                case temperature = "temperature_2m", isDay = "is_day", code = "weather_code", wind = "wind_speed_10m"
            }
        }
        struct Daily: Decodable {
            let sunrise: [Double]
            let sunset: [Double]
            let high: [Double]
            let low: [Double]

            enum CodingKeys: String, CodingKey {
                case sunrise, sunset, high = "temperature_2m_max", low = "temperature_2m_min"
            }
        }
        let current: Current
        let daily: Daily
    }

    private static func fetch(_ coordinate: CLLocationCoordinate2D) async throws -> Weather {
        var address = URLComponents(string: "https://api.open-meteo.com/v1/forecast")!
        address.queryItems = [
            // two decimal places: near enough for weather, and no closer than a kilometre
            URLQueryItem(name: "latitude", value: String(format: "%.2f", coordinate.latitude)),
            URLQueryItem(name: "longitude", value: String(format: "%.2f", coordinate.longitude)),
            URLQueryItem(name: "current", value: "temperature_2m,is_day,weather_code,wind_speed_10m"),
            URLQueryItem(name: "daily", value: "sunrise,sunset,temperature_2m_max,temperature_2m_min"),
            URLQueryItem(name: "timeformat", value: "unixtime"),
            URLQueryItem(name: "timezone", value: "auto"),
            URLQueryItem(name: "forecast_days", value: "1"),
        ]
        let (data, response) = try await URLSession.shared.data(from: address.url!)
        guard (response as? HTTPURLResponse)?.statusCode == 200 else { throw URLError(.badServerResponse) }
        let report = try JSONDecoder().decode(Report.self, from: data)
        return Weather(
            sky: Sky(wmo: report.current.code),
            temperature: report.current.temperature,
            high: report.daily.high.first,
            low: report.daily.low.first,
            wind: report.current.wind,
            isDay: report.current.isDay == 1,
            sunrise: report.daily.sunrise.first.map(Date.init(timeIntervalSince1970:)),
            sunset: report.daily.sunset.first.map(Date.init(timeIntervalSince1970:))
        )
    }

    private static func saved() -> Weather? {
        guard let data = UserDefaults.standard.data(forKey: saveKey),
              let weather = try? JSONDecoder().decode(Weather.self, from: data),
              Date.now.timeIntervalSince(weather.fetched) < shelfLife else { return nil }
        return weather
    }

    /// A made-up sky for trying the scenes, with nothing fetched: launch with
    /// `-demoWeather rain-night`, any `Sky` and any `DayPhase`.
    private static var demo: Weather? {
        guard let name = UserDefaults.standard.string(forKey: "demoWeather") else { return nil }
        let parts = name.split(separator: "-").map(String.init)
        guard let sky = Sky(rawValue: parts[0]) else { return nil }
        let phase = parts.count > 1 ? DayPhase(rawValue: parts[1]) ?? .day : .day
        // a sunrise and sunset that put this moment in the phase asked for
        let hours: (rise: Double, set: Double) = switch phase {
        case .day: (-6, 6)
        case .twilight: (-12, 0)
        case .night: (-18, -6)
        }
        return Weather(sky: sky, temperature: sky == .snow ? -2 : 24, high: sky == .snow ? 1 : 27, low: sky == .snow ? -5 : 21,
                       wind: sky == .thunderstorm ? 40 : 9, isDay: phase != .night,
                       sunrise: Date.now + hours.rise * 3600, sunset: Date.now + hours.set * 3600, place: "Demo")
    }
}
