import Foundation
import os
import SwiftUI
import WebKit

/* Homework, from the school's ManageBac.

   Signing in is done on ManageBac's own page, in a web view inside the app
   (ManageBacSignIn): the password goes to ManageBac and nowhere else, and
   what the app keeps is the session ManageBac hands back, in the web view's
   own cookie store. With that it reads what the website reads:

   - /student/events.json, the feed ManageBac's calendar draws from: every
     task with its title, its due time, what kind it is, and a link that
     names the class it was set in;
   - the class list in the sidebar of any student page, for the classes'
     names;
   - the calendar's "Subscribe to Calendar" feed, which has the first few
     hundred characters of each task's description. That feed on its own
     says nothing of which class a task is for, which is why it is not the
     way in.

   ManageBac's names are not the timetable's ("Economics SL/HL" and "DP
   Econ"), so each class is matched to the timetable by the subject in its
   name, and the match can be put right in Settings.

   What was read is kept, so the page has it at once next time and while
   offline; it is looked at again every ten minutes while the app is open. */
enum ManageBac {
    static let school = URL(string: "https://kueishan.managebac.com")!
    static let login = school.appending(path: "login")

    static let log = Logger(subsystem: "com.tigercho.ManageBacTimetable", category: "ManageBac")
}

/// One task set in a class: what it is, when it is due, and where it is.
struct HomeworkTask: Codable, Hashable, Identifiable {
    /// ManageBac's own number for it.
    var id: String
    var title: String
    /// The start of its description, as the calendar feed has it.
    var detail = ""
    /// "Homework", "Summative" and the like, as ManageBac files it.
    var kind = ""
    var due: Date
    var allDay = false
    var classID: String?
    var link: URL?

    /// "Today 10:20", "Tomorrow", "Fri 23 Oct 23:00".
    func dueText(at now: Date) -> String {
        let cal = Timetable.calendar
        let time = allDay ? nil : Timetable.hhmm(due)
        let day: String
        if cal.isDate(due, inSameDayAs: now) {
            day = "Today"
        } else if let tomorrow = cal.date(byAdding: .day, value: 1, to: now), cal.isDate(due, inSameDayAs: tomorrow) {
            day = "Tomorrow"
        } else {
            day = due.formatted(.dateTime.weekday(.abbreviated).day().month(.abbreviated))
        }
        return [day, time].compactMap { $0 }.joined(separator: " ")
    }
}

/// One class on ManageBac, by its name there.
struct ManageBacClass: Codable, Hashable, Identifiable {
    var id: String
    var name: String
}

@MainActor @Observable
final class Homework {
    static let shared = Homework()

    enum Status: Equatable {
        /// Never signed in, or signed out.
        case signedOut
        case signedIn
        /// ManageBac sent the last look to its sign-in page: the session has run out.
        case expired
    }

    private(set) var status = Status.signedOut
    private(set) var tasks: [HomeworkTask] = []
    private(set) var classes: [ManageBacClass] = []
    private(set) var fetched: Date?
    private(set) var isLoading = false
    /// Why the last look failed, when it did for some reason other than the session.
    private(set) var problem: String?
    /// The sign-in page is up.
    var signingIn = false
    /// The page ManageBac is being read from, while it is. The phone puts a
    /// web page that is in no window to sleep before it has loaded, so the
    /// phone's page gives it a place, out of sight (`ManageBacReading`).
    private(set) var reading: WebPage?

    private struct Saved: Codable {
        var tasks: [HomeworkTask]
        var classes: [ManageBacClass]
        var fetched: Date?
        var signedIn: Bool
        /// The calendar feed's address, found once on the calendar page.
        var feed: URL?
    }

    private static let saveKey = "homework"
    private var feed: URL?

    init() {
        if let data = UserDefaults.standard.data(forKey: Self.saveKey),
           let saved = try? JSONDecoder().decode(Saved.self, from: data) {
            tasks = saved.tasks
            classes = saved.classes
            fetched = saved.fetched
            feed = saved.feed
            status = saved.signedIn ? .signedIn : .signedOut
        }
    }

    private func save() {
        let saved = Saved(tasks: tasks, classes: classes, fetched: fetched, signedIn: status != .signedOut, feed: feed)
        UserDefaults.standard.set(try? JSONEncoder().encode(saved), forKey: Self.saveKey)
    }

    // MARK: Signing in and out

    /// The sign-in page has reached a student page: the session is there to use.
    func signedIn() async {
        // which of ManageBac's cookies there are, and whether each outlasts the app; never their values
        let cookies = await WKWebsiteDataStore.default().httpCookieStore.allCookies().filter { $0.domain.hasSuffix("managebac.com") }
        let kept = cookies.map { "\($0.name)\($0.isSessionOnly ? "" : " (kept)")" }.joined(separator: ", ")
        ManageBac.log.notice("signed in; cookies: \(kept, privacy: .public)")
        status = .signedIn
        signingIn = false
        // kept at once, not only once the first look is done: a look that never ended left the
        // phone thinking it had never been signed in
        save()
        await refresh(force: true)
    }

    /// Forget the session and everything read with it.
    func signOut() async {
        let store = WKWebsiteDataStore.default().httpCookieStore
        for cookie in await store.allCookies() where cookie.domain.hasSuffix("managebac.com") {
            await store.deleteCookie(cookie)
        }
        status = .signedOut
        tasks = []
        classes = []
        fetched = nil
        feed = nil
        problem = nil
        save()
    }

    // MARK: Reading

    /// Look again, if the last look is ten minutes old or `force`.
    func refresh(force: Bool = false) async {
        guard status != .signedOut, !isLoading else { return }
        if !force, let fetched, Date.now.timeIntervalSince(fetched) < 600 { return }
        isLoading = true
        defer { isLoading = false }
        do {
            let page = WebPage()
            reading = page
            defer { reading = nil }
            let reader = try await Reader(page: page)
            let start = Timetable.calendar.date(byAdding: .day, value: -14, to: Timetable.calendar.startOfDay(for: .now))!
            var read = try await reader.tasks(from: start, days: 75)
            classes = (try? await reader.classes()) ?? classes
            // the descriptions are a nicety: without them the tasks still stand
            if feed == nil { feed = try? await reader.feed() }
            if let feed, let details = try? await Reader.details(from: feed) {
                for index in read.indices {
                    read[index].detail = details[read[index].id]
                        ?? details["\(read[index].title)|\(Int(read[index].due.timeIntervalSince1970))"] ?? ""
                }
            }
            tasks = read.sorted { $0.due < $1.due }
            fetched = .now
            status = .signedIn
            problem = nil
            ManageBac.log.notice("read \(read.count, privacy: .public) tasks in \(self.classes.count, privacy: .public) classes")
        } catch Reader.Failure.signedOut {
            status = .expired
            ManageBac.log.notice("the session has run out")
        } catch {
            problem = error.localizedDescription
            ManageBac.log.error("reading failed: \(error.localizedDescription, privacy: .public)")
        }
        save()
    }

    // MARK: Matching

    /* The timetable subjects a ManageBac class is: every subject of this
       timetable its name describes. Guidance's class is both of the
       timetable's Guidance slots. */
    func subjects(of classID: String) -> [String] {
        subjects(of: classID, among: Self.candidates)
    }

    private func subjects(of classID: String, among candidates: [String]) -> [String] {
        guard let name = classes.first(where: { $0.id == classID })?.name else { return [] }
        return candidates.filter { Self.describes(name, $0) }
    }

    /// The subjects a class can be matched to: this timetable's, less the
    /// revision classes, which go with the class they are for.
    static var candidates: [String] {
        let subjects = Set(Timetable.lessons.map(\.subject)).filter { !$0.localizedCaseInsensitiveContains("evision") }
        return subjects.sorted { Timetable.displayName($0) < Timetable.displayName($1) }
    }

    /// The tasks set in the class `subject` is, from `start` on, soonest first.
    /// A revision class has the tasks of the class it is for.
    func tasks(for subject: String, from start: Date) -> [HomeworkTask] {
        let wanted = Self.parent(of: subject) ?? subject
        let candidates = Self.candidates
        let classes = Set(self.classes.map(\.id).filter { subjects(of: $0, among: candidates).contains(wanted) })
        return tasks.filter { task in task.due >= start && task.classID.map(classes.contains) == true }
    }

    /// The subject a revision class is for, when it is one.
    static func parent(of subject: String) -> String? {
        guard let form = Timetable.profile?.form else { return nil }
        return Timetable.catalog(for: form).revision.first { $0.value.contains { $0.subject == subject } }?.key
    }

    /// The timetable subject a task is for, if it is matched to one.
    func subject(of task: HomeworkTask) -> String? {
        task.classID.flatMap { subjects(of: $0).first }
    }

    /// Whether a ManageBac class's name is of the timetable's `subject`.
    static func describes(_ name: String, _ subject: String) -> Bool {
        let n = name.lowercased()
        func has(_ words: String...) -> Bool { words.allSatisfy { n.contains($0) } }
        switch subject {
        case let s where s.hasPrefix("DP MAA"): return has("analysis and approaches")
        case let s where s.hasPrefix("DP MAI"): return has("applications and interpretation")
        case let s where s.hasPrefix("DP Chi A"): return has("chinese a")
        case let s where s.hasPrefix("DP Chi B"): return has("chinese b")
        // English A is Language and Literature; Eng Lit is Literature alone
        case let s where s.hasPrefix("DP Eng A"): return has("english", "language")
        case "Eng Lit": return has("english", "literature") && !n.contains("language")
        case let s where s.hasPrefix("DP Eng B"): return has("english b")
        case "DP Comp. Sc.": return has("computer science")
        case "DP Bus Man": return has("business")
        case "DP Econ": return has("economics")
        case "DP Chem": return has("chemistry")
        case "DP Bio": return has("biology")
        case "DP Physics": return has("physics")
        case "DP ESS": return has("environmental")
        case "DP History": return has("history")
        case "DP Psych": return has("psychology")
        case "DP V. Arts": return has("visual arts")
        case let s where s.hasPrefix("DP TOK"): return has("theory of knowledge") || n.hasPrefix("tok")
        case let s where s.hasPrefix("G:") || s == "Guidance": return has("guidance")
        default: return n.contains(Timetable.shortName(subject).lowercased())
        }
    }
}

// MARK: - Reading from ManageBac

/* One look at ManageBac, from inside it. The calendar page is opened out
   of sight with the session the sign-in page left, and everything else is
   asked for from that page — the way the userscript asks, and the way the
   site's own calendar does — so each request goes out as the browser's
   own, cookies and all. Asked from outside, with copies of the session's
   cookies, ManageBac turned every request away to its sign-in page. A page
   that lands on the sign-in page means the session has run out. */
@MainActor
private struct Reader {
    enum Failure: LocalizedError {
        case signedOut
        case unreadable
        case noAnswer

        var errorDescription: String? {
            switch self {
            case .signedOut: "Signed out of ManageBac."
            case .unreadable: "ManageBac sent something Timetable couldn't read."
            case .noAnswer: "ManageBac didn't answer."
            }
        }
    }

    private let page: WebPage

    /// Open the calendar page: its sidebar has the classes, and its
    /// Subscribe button the calendar feed's address. Given up on after
    /// forty seconds: a page that never finished left the box looking for
    /// ever.
    init(page: WebPage) async throws {
        self.page = page
        try await withThrowingTaskGroup(of: Void.self) { group in
            group.addTask { @MainActor in
                for try await event in page.load(ManageBac.school.appending(path: "student/calendar")) where event == .finished {
                    break
                }
            }
            group.addTask {
                try await Task.sleep(for: .seconds(40))
                throw Failure.noAnswer
            }
            try await group.next()
            group.cancelAll()
        }
        let landed = page.url?.path() ?? "nothing"
        ManageBac.log.notice("the calendar page opened at \(landed, privacy: .public)")
        guard let url = page.url, !url.path().hasPrefix("/login") else { throw Failure.signedOut }
    }

    /// `path`, fetched from inside the page, as text.
    private func fetch(_ path: String, accept: String) async throws -> String {
        let reply = try await page.callJavaScript(#"""
            const response = await fetch(path, { credentials: 'same-origin', headers: { Accept: accept } });
            if (response.status === 401 || new URL(response.url).pathname.startsWith('/login')) return { signedOut: true };
            return { status: response.status, text: await response.text() };
            """#, arguments: ["path": path, "accept": accept]) as? [String: Any]
        guard let reply else { throw Failure.unreadable }
        if reply["signedOut"] != nil { throw Failure.signedOut }
        guard let status = (reply["status"] as? NSNumber)?.intValue, (200..<300).contains(status),
              let text = reply["text"] as? String else { throw URLError(.badServerResponse) }
        return text
    }

    // MARK: The tasks

    /// What the calendar feed gives for one entry; anything else in it is let be.
    private struct Event: Decodable {
        let id: String?
        let title: String?
        let start: String?
        let allDay: Bool?
        let url: String?
        let category: String?

        enum CodingKeys: String, CodingKey { case id, title, start, allDay, url, category }

        init(from decoder: Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            // the id comes as a number or as text
            id = (try? c.decodeIfPresent(String.self, forKey: .id)) ?? (try? c.decodeIfPresent(Int.self, forKey: .id)).flatMap { $0.map(String.init) }
            title = try? c.decodeIfPresent(String.self, forKey: .title)
            start = try? c.decodeIfPresent(String.self, forKey: .start)
            allDay = try? c.decodeIfPresent(Bool.self, forKey: .allDay)
            url = try? c.decodeIfPresent(String.self, forKey: .url)
            category = try? c.decodeIfPresent(String.self, forKey: .category)
        }
    }

    func tasks(from start: Date, days: Int) async throws -> [HomeworkTask] {
        let cal = Timetable.calendar
        let end = cal.date(byAdding: .day, value: days, to: start)!
        func day(_ date: Date) -> String {
            let c = cal.dateComponents([.year, .month, .day], from: date)
            return String(format: "%04d-%02d-%02dT00:00:00", c.year!, c.month!, c.day!)
        }
        var address = URLComponents(string: "/student/events.json")!
        address.queryItems = [URLQueryItem(name: "start", value: day(start)), URLQueryItem(name: "end", value: day(end)),
                              URLQueryItem(name: "timeZone", value: cal.timeZone.identifier)]
        let json = try await fetch(address.string!, accept: "application/json")
        guard let events = try? JSONDecoder().decode([Event].self, from: Data(json.utf8)) else { throw Failure.unreadable }
        return events.compactMap { event in
            guard let title = event.title?.trimmingCharacters(in: .whitespacesAndNewlines), !title.isEmpty,
                  let start = event.start, let due = Self.date(start), let path = event.url else { return nil }
            let link = URL(string: path, relativeTo: ManageBac.school)?.absoluteURL
            let classID = Self.number(after: "/classes/", in: path)
            // a task's own number ends its address; failing that, the feed's id
            let own = path.split(separator: "/").last.map(String.init).flatMap { Int($0) != nil ? $0 : nil }
            return HomeworkTask(id: own ?? event.id ?? "\(title)|\(Int(due.timeIntervalSince1970))", title: title,
                                kind: event.category ?? "", due: due, allDay: event.allDay ?? !start.contains("T"),
                                classID: classID, link: link)
        }
    }

    /// The feed's times: "2026-10-23T10:00:00.000+08:00", with or without
    /// the fraction, or a day alone for a whole-day entry.
    private static func date(_ text: String) -> Date? {
        let withFraction = ISO8601DateFormatter()
        withFraction.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = withFraction.date(from: text) ?? ISO8601DateFormatter().date(from: text) { return date }
        let day = DateFormatter()
        day.calendar = Timetable.calendar
        day.timeZone = Timetable.calendar.timeZone
        day.dateFormat = text.count > 10 ? "yyyy-MM-dd'T'HH:mm:ss" : "yyyy-MM-dd"
        return day.date(from: String(text.prefix(19)))
    }

    private static func number(after marker: String, in text: String) -> String? {
        guard let range = text.range(of: marker) else { return nil }
        let digits = text[range.upperBound...].prefix { $0.isNumber }
        return digits.isEmpty ? nil : String(digits)
    }

    // MARK: The classes

    /* The classes, from the page's sidebar, where the userscript reads them:
       each is a link to /student/classes/<id>, named the way ManageBac names
       it — "IB DP Economics SL/HL (Grade 11) - 2" — which is tidied the way
       the userscript tidies it. Failing the sidebar, any link to a class. */
    func classes() async throws -> [ManageBacClass] {
        let links = try await page.callJavaScript(#"""
            const pick = selector => [...document.querySelectorAll(selector)]
                .map(a => [a.getAttribute('href') || '', a.textContent.replace(/\s+/g, ' ').trim()]);
            const menu = pick('.js-menu-classes-list .f-menu__submenu-link');
            return menu.length ? menu : pick('a[href*="/classes/"]');
            """#) as? [[String]] ?? []
        var seen = Set<String>()
        var out: [ManageBacClass] = []
        for link in links where link.count == 2 {
            guard let id = Self.number(after: "/classes/", in: link[0]) else { continue }
            let name = Self.tidy(link[1])
            guard !name.isEmpty, seen.insert(id).inserted else { continue }
            out.append(ManageBacClass(id: id, name: name))
        }
        return out
    }

    private static func tidy(_ name: String) -> String {
        name.replacing(#/^IB\s+(DP|MYP|PYP|CP)\s+/#.ignoresCase(), with: "")
            .replacing(#/^\[[^\]]*\]\s*/#, with: "")
            .replacing(#/\s*\(Grade\s*\d+\)\s*/#.ignoresCase(), with: " ")
            .replacing(#/\s*-\s*\d+\s*$/#, with: "")
            .replacing(#/\s+/#, with: " ")
            .trimmingCharacters(in: .whitespaces)
    }

    // MARK: The descriptions

    /// The calendar feed's address, from the calendar page's "Subscribe to
    /// Calendar" button. It needs no session to read.
    func feed() async throws -> URL {
        let html = try await page.callJavaScript("return document.documentElement.outerHTML") as? String ?? ""
        guard let match = html.firstMatch(of: #/\/student\/events\/token\/[0-9a-fA-F-]+\.ics/#),
              let url = URL(string: String(match.output), relativeTo: ManageBac.school)?.absoluteURL else {
            throw Failure.unreadable
        }
        return url
    }

    /// Each task's description from the calendar feed, by the task's number,
    /// and by its title and due time for any whose number does not match.
    static func details(from feed: URL) async throws -> [String: String] {
        let (data, _) = try await URLSession.shared.data(from: feed)
        let text = String(decoding: data, as: UTF8.self)
            .replacingOccurrences(of: "\r\n", with: "\n")
            .replacing(#/\n[ \t]/#, with: "")
        let stamp = DateFormatter()
        stamp.dateFormat = "yyyyMMdd'T'HHmmss"
        var out: [String: String] = [:]
        for block in text.components(separatedBy: "BEGIN:VEVENT").dropFirst() {
            var fields: [String: String] = [:]
            var zone: TimeZone?
            for line in block.split(separator: "\n") {
                guard let colon = line.firstIndex(of: ":") else { continue }
                let head = line[..<colon]
                let key = head.split(separator: ";").first.map(String.init) ?? ""
                fields[key] = String(line[line.index(after: colon)...])
                if key == "DTSTART", let tz = head.firstMatch(of: #/TZID=([^;:]+)/#) { zone = TimeZone(identifier: String(tz.output.1)) }
            }
            guard let detail = fields["DESCRIPTION"].map(unescape), !detail.isEmpty else { continue }
            if let uid = fields["UID"] { out[uid] = detail }
            stamp.timeZone = zone ?? Timetable.calendar.timeZone
            if let title = fields["SUMMARY"].map(unescape), let start = fields["DTSTART"].flatMap(stamp.date) {
                out["\(title)|\(Int(start.timeIntervalSince1970))"] = detail
            }
        }
        return out
    }

    private static func unescape(_ text: String) -> String {
        text.replacingOccurrences(of: "\\n", with: "\n")
            .replacingOccurrences(of: "\\,", with: ",")
            .replacingOccurrences(of: "\\;", with: ";")
            .replacingOccurrences(of: "\\\\", with: "\\")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
