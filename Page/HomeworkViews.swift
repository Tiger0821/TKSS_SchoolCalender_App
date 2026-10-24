import SwiftUI
import WebKit

/* What is shown of the homework (ManageBac.swift reads it): a class's
   tasks, opened by clicking the class in the day's list; the Homework box,
   with what is due soonest across them all; the sign-in page; and the rows
   in Settings. */

// MARK: - Signing in

/// ManageBac's own sign-in page, in a sheet. Once it reaches a student page
/// the session is there, and the sheet goes. A parent's or a teacher's
/// account has no student pages: one already signed in on the phone, filled
/// in by the phone's saved passwords, went straight to /parent and the sheet
/// waited for ever. Such an account is said to be one, with the way out of
/// it, back to the login form.
struct ManageBacSignIn: View {
    @State private var page = WebPage()
    /// The account the page landed in is a parent's or a teacher's: "parent" or "teacher".
    @State private var role: String?

    var body: some View {
        VStack(spacing: 0) {
            HStack(alignment: .firstTextBaseline, spacing: 12) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Sign in to ManageBac")
                        .font(.headline)
                    if let role {
                        Text("This is a \(role)'s account. Timetable reads a student's homework: sign in with your own.")
                            .font(.footnote)
                            .foregroundStyle(.red)
                            .fixedSize(horizontal: false, vertical: true)
                        Button("Use Another Account") {
                            Task {
                                await Homework.shared.signOut()
                                self.role = nil
                                _ = page.load(ManageBac.login)
                            }
                        }
                        .buttonStyle(PillButtonStyle(compact: true))
                        .padding(.top, 4)
                    } else {
                        Text("Your password goes to ManageBac, not to Timetable. Tick \u{201C}Remember me\u{201D} to stay signed in.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                Spacer(minLength: 0)
                Button("Cancel") { Homework.shared.signingIn = false }
                    .keyboardShortcut(.cancelAction)
            }
            .padding(16)
            Divider()
            WebView(page)
                .overlay {
                    if page.isLoading && page.url == nil { ProgressView() }
                }
        }
        #if os(macOS)
        .frame(width: 520, height: 680)
        #endif
        .onAppear { _ = page.load(ManageBac.login) }
        .onChange(of: page.url) { _, url in
            // where it has got to: the address, never what is typed
            let path = url?.path() ?? "nothing"
            ManageBac.log.notice("the sign-in page is at \(path, privacy: .public)")
            guard let url, url.host() == ManageBac.school.host() else { return }
            if url.path().hasPrefix("/student") {
                role = nil
                Task { await Homework.shared.signedIn() }
            } else if let other = ["parent", "teacher"].first(where: { url.path().hasPrefix("/\($0)") }) {
                role = other
            }
        }
    }
}

/* Where ManageBac is read from, out of sight. The phone puts a web page
   that is in no window to sleep before it has finished loading, so the page
   being read from is given a place in one while it is read: a point across,
   and not seen or touched. The Mac reads from a page in no window. */
struct ManageBacReading: View {
    var body: some View {
        if let page = Homework.shared.reading {
            WebView(page)
                .frame(width: 1, height: 1)
                .opacity(0.01)
                .allowsHitTesting(false)
                .accessibilityHidden(true)
        }
    }
}

// MARK: - One class

/// The homework of the class in a block of the day: what is due from today on.
struct HomeworkList: View {
    let segment: Segment
    let now: Date

    var body: some View {
        let homework = Homework.shared
        let start = Timetable.calendar.startOfDay(for: now)
        var seen = Set<String>()
        let tasks = segment.lessons.flatMap { homework.tasks(for: $0.subject, from: start) }
            .filter { seen.insert($0.id).inserted }
            .sorted { $0.due < $1.due }
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 10) {
                RoundedRectangle(cornerRadius: 2)
                    .fill(segment.tint)
                    .frame(width: 4, height: 28)
                VStack(alignment: .leading, spacing: 0) {
                    Text(segment.title)
                        .font(.headline)
                    Text("Homework")
                        .font(.caption.weight(.semibold))
                        .textCase(.uppercase)
                        .foregroundStyle(.secondary)
                }
            }
            switch homework.status {
            case .signedOut:
                ConnectPrompt(text: "Sign in to ManageBac to see what's set for each class.")
            case .expired, .signedIn:
                if homework.status == .expired {
                    ConnectPrompt(text: "Signed out of ManageBac. This is what it said last.", again: true)
                }
                if tasks.isEmpty {
                    Text(homework.fetched == nil ? "Looking…" : "Nothing due.")
                        .foregroundStyle(.secondary)
                } else {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 14) {
                            ForEach(tasks) { task in
                                TaskDetail(task: task, now: now, tint: segment.tint)
                                if task.id != tasks.last?.id { Divider() }
                            }
                        }
                        // a lane of its own for the scroll bar, which was drawn over the dates
                        .padding(.trailing, 14)
                    }
                    .scrollBounceBehavior(.basedOnSize)
                    .frame(maxHeight: 420)
                }
                UpdatedLine()
            }
        }
        .padding(18)
        #if os(macOS)
        .frame(width: 380)
        #else
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        #endif
        .presentationDetents([.medium, .large])
    }
}

/// One task in full: its title, when it is due and the arrow that opens it
/// in ManageBac, what kind it is, and the start of what it says.
struct TaskDetail: View {
    let task: HomeworkTask
    let now: Date
    let tint: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .firstTextBaseline) {
                Text(task.title)
                    .font(.body.weight(.semibold))
                    .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 8)
                Text(task.dueText(at: now))
                    .font(.footnote.weight(.semibold).monospacedDigit())
                    .foregroundStyle(task.isSoon(at: now) ? Color.red : .secondary)
                // the arrow alone: under every task, "Open in ManageBac" in words was too many
                if let link = task.link {
                    Link(destination: link) {
                        Image(systemName: "arrow.up.right.square")
                    }
                    .font(.footnote.weight(.semibold))
                    .focusEffectDisabled()
                    .help("Open in ManageBac")
                    .accessibilityLabel("Open in ManageBac")
                }
            }
            if !task.kind.isEmpty {
                Text(task.kind)
                    .font(.caption2.weight(.bold))
                    .textCase(.uppercase)
                    .foregroundStyle(tint)
            }
            if !task.detail.isEmpty {
                Text(task.detail)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .lineLimit(5)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

extension HomeworkTask {
    /// Due by the end of tomorrow, and not yet past.
    func isSoon(at now: Date) -> Bool {
        let cal = Timetable.calendar
        guard let end = cal.date(byAdding: .day, value: 2, to: cal.startOfDay(for: now)) else { return false }
        return due >= now && due < end
    }
}

/// The count of a class's tasks due this week, at the end of its row.
struct HomeworkBadge: View {
    let segment: Segment
    let tint: Color

    var body: some View {
        let homework = Homework.shared
        let now = Date.now
        let cal = Timetable.calendar
        let end = cal.date(byAdding: .day, value: 7, to: cal.startOfDay(for: now))!
        var seen = Set<String>()
        let count = segment.lessons.flatMap { homework.tasks(for: $0.subject, from: now) }
            .filter { $0.due < end && seen.insert($0.id).inserted }.count
        if count > 0 {
            Label("\(count)", systemImage: "checklist")
                .font(.caption.weight(.bold).monospacedDigit())
                .foregroundStyle(tint)
                .padding(.horizontal, 7)
                .padding(.vertical, 3)
                .background(tint.opacity(0.16), in: .capsule)
                .accessibilityLabel("\(count) due this week")
        }
    }
}

// MARK: - The Homework box

/// What is due soonest, across every class.
struct HomeworkCard: View {
    let now: Date

    var body: some View {
        let homework = Homework.shared
        let start = Timetable.calendar.startOfDay(for: now)
        let due = homework.tasks.filter { $0.due >= start }.prefix(6)
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("Homework", systemImage: "checklist")
                    .font(.boxTitle)
                    .textCase(.uppercase)
                    .foregroundStyle(.indigo)
                Spacer()
                if homework.isLoading { ProgressView().controlSize(.small) }
            }
            switch homework.status {
            case .signedOut:
                Text("Click a class to see what's set for it, once Timetable can read your ManageBac.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                ConnectPrompt(text: nil)
            case .expired, .signedIn:
                if homework.status == .expired {
                    ConnectPrompt(text: "Signed out of ManageBac.", again: true)
                }
                if due.isEmpty {
                    if let problem = homework.problem, !homework.isLoading {
                        // a look that failed says so, and can be tried again, rather than looking on
                        Text(problem)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                        Button("Try Again") { Task { await homework.refresh(force: true) } }
                            .buttonStyle(PillButtonStyle(compact: true))
                    } else {
                        Text(homework.fetched == nil ? "Looking…" : "Nothing due.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
                ForEach(Array(due)) { task in
                    HomeworkRow(task: task, now: now)
                }
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassEffect(.regular.tint(Color.indigo.opacity(0.08)), in: .rect(cornerRadius: 28))
    }
}

/// One task in the box: its class's colour, its title, the class and when
/// it is due. Clicked, it opens in full.
private struct HomeworkRow: View {
    let task: HomeworkTask
    let now: Date
    @State private var open = false

    var body: some View {
        let homework = Homework.shared
        let subject = homework.subject(of: task)
        let tint = subject.map(Timetable.tint(for:)) ?? .secondary
        let course = subject.map(Timetable.shortName)
            ?? homework.classes.first { $0.id == task.classID }?.name ?? ""
        Button {
            open = true
        } label: {
            HStack(spacing: 10) {
                Capsule()
                    .fill(tint)
                    .frame(width: 4, height: 30)
                VStack(alignment: .leading, spacing: 0) {
                    Text(task.title)
                        .font(.subheadline.weight(.semibold))
                        .lineLimit(1)
                    Text(course)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                Spacer(minLength: 6)
                Text(task.dueText(at: now))
                    .font(.footnote.weight(.semibold).monospacedDigit())
                    .foregroundStyle(task.isSoon(at: now) ? Color.red : .secondary)
                    .lineLimit(1)
            }
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .popover(isPresented: $open) {
            TaskDetail(task: task, now: now, tint: tint)
                .padding(18)
                #if os(macOS)
                .frame(width: 360)
                #else
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                #endif
                .presentationDetents([.medium])
        }
    }
}

/// The way in: a line saying why, and the button that opens the sign-in page.
/// From inside a class's sheet or popover, that goes first: a phone shows one
/// sheet at a time, and the sign-in page asked for over it never came.
private struct ConnectPrompt: View {
    let text: String?
    var again = false
    @Environment(\.isPresented) private var isPresented
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let text {
                Text(text)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Button(again ? "Sign In Again" : "Connect ManageBac") {
                guard isPresented else {
                    Homework.shared.signingIn = true
                    return
                }
                dismiss()
                Task {
                    try? await Task.sleep(for: .milliseconds(500))
                    Homework.shared.signingIn = true
                }
            }
            .buttonStyle(PillButtonStyle())
        }
    }
}

/// When the homework was last read, and a way to read it again now.
private struct UpdatedLine: View {
    var body: some View {
        let homework = Homework.shared
        HStack(spacing: 6) {
            if let fetched = homework.fetched {
                Text("Updated \(Timetable.hhmm(fetched))")
            }
            Spacer()
            if homework.isLoading {
                ProgressView().controlSize(.small)
            } else {
                Button("Refresh") { Task { await homework.refresh(force: true) } }
                    .buttonStyle(.borderless)
            }
        }
        .font(.footnote)
        .foregroundStyle(.secondary)
    }
}

// MARK: - Settings

/* The ManageBac rows of Settings, the same on the phone and the Mac: whether
   it is signed in, how much it read and when it last looked. */
struct ManageBacSettings: View {
    var body: some View {
        let homework = Homework.shared
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(homework.status == .signedOut ? "Not connected" : homework.status == .expired ? "Signed out" : "Connected")
                        .font(.body.weight(.semibold))
                        .foregroundStyle(.primary)
                    Text(statusLine)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                if homework.status == .signedIn {
                    Button("Refresh") { Task { await homework.refresh(force: true) } }
                        .disabled(homework.isLoading)
                    Button("Sign Out") { Task { await homework.signOut() } }
                } else {
                    Button(homework.status == .expired ? "Sign In Again" : "Sign In") { homework.signingIn = true }
                }
            }
            if let problem = homework.problem {
                Text(problem)
                    .font(.footnote)
                    .foregroundStyle(.red)
            }
        }
    }

    private var statusLine: String {
        let homework = Homework.shared
        switch homework.status {
        case .signedOut: return "Sign in to see each class's homework. Timetable reads kueishan.managebac.com."
        case .expired: return "ManageBac's session ran out; sign in again to keep the homework up to date."
        case .signedIn:
            let when = homework.fetched.map { " · updated \(Timetable.hhmm($0))" } ?? ""
            return "\(homework.tasks.count) tasks in \(homework.classes.count) classes\(when)"
        }
    }
}
