import SwiftUI

/* Setup: who you are and which classes are yours, one question to a page.
   Your name, your form, then each set of classes that are on at the same
   time — so only one of them can be yours — then any SL revision that goes
   with what you picked, and what your clubs are called. It runs the first
   time the app is opened, and again, already filled in, whenever the name
   under the clock is tapped. What it ends with is a Profile. */
struct SetupView: View {
    /// Called with the finished profile.
    let done: (Profile) -> Void
    /// A way out without changing anything; nil the first time, when there is nothing to go back to.
    let cancel: (() -> Void)?

    @State private var draft: Profile
    @State private var clubs: [ClubEntry] = []
    @State private var step = 0
    @FocusState private var typingName: Bool

    init(existing: Profile?, done: @escaping (Profile) -> Void, cancel: (() -> Void)? = nil) {
        self.done = done
        self.cancel = cancel
        _draft = State(initialValue: existing ?? Profile())
    }

    private enum Step: Hashable {
        case name, form, set(Int), revision, clubs
    }

    /// One club slot on the timetable, as it is typed in: one club for both
    /// weeks, or a different one in Week 2.
    private struct ClubEntry: Identifiable {
        let subject: String
        var first = Profile.Club(subject: "", name: "")
        var splits = false
        var second = Profile.Club(subject: "", name: "")
        var id: String { subject }
    }

    private var catalog: Catalog { Timetable.catalog(for: draft.form) }

    /// The pages still to come depend on the form, and on what is picked from it.
    private var steps: [Step] {
        var steps: [Step] = [.name, .form]
        guard !draft.form.isEmpty else { return steps }
        steps += catalog.sets.indices.map { .set($0) }
        if !draft.revision.isEmpty { steps.append(.revision) }
        if !clubs.isEmpty { steps.append(.clubs) }
        return steps
    }

    private var current: Step { steps[min(step, steps.count - 1)] }
    private var isLast: Bool { !draft.form.isEmpty && step >= steps.count - 1 }

    private var canGoOn: Bool {
        switch current {
        case .name: !draft.name.trimmingCharacters(in: .whitespaces).isEmpty
        case .form: !draft.form.isEmpty
        default: true
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            topBar
            ScrollView {
                page
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.top, 28)
                    .padding(.bottom, 24)
                    .id(current)
                    .transition(.opacity)
            }
            .scrollBounceBehavior(.basedOnSize)
            .scrollDismissesKeyboard(.interactively)
            bottomBar
        }
        // in a window wider than a phone (the Mac's), the questions keep to a column
        .frame(maxWidth: 620)
        .padding(.horizontal, 20)
        .frame(maxWidth: .infinity)
        .background {
            GeometryReader { proxy in
                // a clear night: nothing drifts behind the questions, white reads over all
                // of it, and the moon sits low on the right, clear of the words
                PixelSky(scene: SkyScene(sky: .clear, phase: .night, wind: 0),
                         window: CGRect(x: 0, y: proxy.size.height - 232, width: proxy.size.width, height: 96))
            }
            // so the moon stays put when the keyboard comes up
            .ignoresSafeArea(.keyboard)
        }
        .preferredColorScheme(.dark)
        .onAppear {
            clubs = entries(for: draft)
            typingName = draft.name.isEmpty
        }
    }

    // MARK: - The frame

    private var topBar: some View {
        HStack(spacing: 12) {
            // one pip for each page; the pages after the form aren't known until it is picked
            HStack(spacing: 5) {
                ForEach(steps.indices, id: \.self) { index in
                    Capsule()
                        .fill(index <= step ? AnyShapeStyle(.primary) : AnyShapeStyle(.tertiary))
                        .frame(width: index == step ? 22 : 8, height: 6)
                }
            }
            .accessibilityElement()
            .accessibilityLabel("Step \(step + 1) of \(steps.count)")
            Spacer()
            if let cancel {
                Button("Cancel", action: cancel)
                    .font(.subheadline.weight(.semibold))
            }
        }
        .frame(minHeight: 44)
        .padding(.top, 8)
    }

    private var bottomBar: some View {
        HStack(spacing: 12) {
            if step > 0 {
                Button {
                    go(to: step - 1)
                } label: {
                    Label("Back", systemImage: "chevron.left")
                        .font(.headline)
                        .frame(minHeight: 52)
                        .padding(.horizontal, 18)
                        // the whole button takes the tap, not only the words on it
                        .contentShape(.capsule)
                }
                .buttonStyle(.plain)
                .glassEffect(.regular.interactive(), in: .capsule)
            }
            Button {
                isLast ? finish() : go(to: step + 1)
            } label: {
                Text(isLast ? "Done" : "Next")
                    .font(.headline)
                    .frame(maxWidth: .infinity, minHeight: 52)
                    .contentShape(.capsule)
            }
            .buttonStyle(.plain)
            .glassEffect(.regular.tint(.accentColor.opacity(canGoOn ? 0.7 : 0.15)).interactive(), in: .capsule)
            .disabled(!canGoOn)
            .opacity(canGoOn ? 1 : 0.5)
        }
        .padding(.vertical, 12)
    }

    private func go(to index: Int) {
        typingName = false
        withAnimation(.snappy) { step = max(0, min(index, steps.count - 1)) }
    }

    // MARK: - The pages

    @ViewBuilder private var page: some View {
        switch current {
        case .name:
            question("What's your name?", "It goes at the top of your timetable.") {
                TextField("Your name", text: $draft.name)
                    .font(.title2.weight(.semibold))
                    // the Mac's own field has a frame drawn round it; the glass is frame enough
                    .textFieldStyle(.plain)
                    #if os(iOS)
                    .textContentType(.givenName)
                    #endif
                    .submitLabel(.next)
                    .focused($typingName)
                    .onSubmit { if canGoOn { go(to: step + 1) } }
                    .padding(18)
                    .glassEffect(.regular, in: .rect(cornerRadius: 22))
            }
        case .form:
            question("Which form are you in?", "Each form has its own timetable.") {
                ForEach(TimetableData.forms, id: \.name) { form in
                    row(form.name, detail: nil, picked: draft.form == form.name) {
                        pick(form: form.name)
                        go(to: step + 1)
                    }
                }
            }
        case .set(let index):
            let set = catalog.sets[index]
            // when every class in the set clashes with every other, it is one or none
            let oneOnly = set.allSatisfy { choice in choice.clashes.isSuperset(of: set.map(\.subject).filter { $0 != choice.subject }) }
            question(oneOnly ? "Which of these do you take?" : "Which of these are yours?",
                     oneOnly ? "They're on at the same time, so it's one of them or none."
                             : "Pick each one you take. Picking one drops any that are on at the same time as it.") {
                ForEach(set) { choice in
                    row(choice.name, detail: choice.staff, picked: draft.subjects.contains(choice.subject), tint: Timetable.tint(for: choice.subject)) {
                        let adding = !draft.subjects.contains(choice.subject)
                        draft.toggle(choice)
                        if oneOnly && adding { go(to: step + 1) }
                    }
                }
                if oneOnly {
                    row("None of these", detail: nil, picked: set.allSatisfy { !draft.subjects.contains($0.subject) }) {
                        for choice in set where draft.subjects.contains(choice.subject) { draft.toggle(choice) }
                        go(to: step + 1)
                    }
                }
            }
        case .revision:
            question("Any SL revision?", "Extra classes for what you picked. Leave them off if you don't go.") {
                ForEach(draft.revision) { choice in
                    row(choice.name, detail: choice.staff, picked: draft.subjects.contains(choice.subject), tint: Timetable.tint(for: choice.subject)) {
                        draft.toggle(choice)
                    }
                }
            }
        case .clubs:
            question("What are your clubs?", "The timetable only says \u{201C}Service Clubs\u{201D} and \u{201C}Academic Clubs\u{201D}. Put in what yours are called, or leave them blank.") {
                ForEach($clubs) { $club in
                    VStack(alignment: .leading, spacing: 12) {
                        Text(club.subject)
                            .font(.headline)
                        clubFields(club.splits ? "Week 1 club" : "Club name", $club.first)
                        if club.splits {
                            clubFields("Week 2 club", $club.second)
                        }
                        Toggle("A different club in Week 2", isOn: $club.splits.animation(.snappy))
                            .font(.subheadline)
                    }
                    .padding(18)
                    .glassEffect(.regular, in: .rect(cornerRadius: 22))
                }
            }
        }
    }

    private func question(_ title: String, _ detail: String, @ViewBuilder answers: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.largeTitle.weight(.bold))
                .fixedSize(horizontal: false, vertical: true)
            Text(detail)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.bottom, 10)
            answers()
        }
    }

    /// One answer: a name, who teaches it, and a mark when it is picked.
    private func row(_ title: String, detail: String?, picked: Bool, tint: Color? = nil, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 14) {
                if let tint {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(tint)
                        .frame(width: 4, height: 34)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.title3.weight(.semibold))
                    if let detail, !detail.isEmpty {
                        Text(detail)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
                Spacer(minLength: 8)
                Image(systemName: picked ? "checkmark.circle.fill" : "circle")
                    .font(.title2)
                    .foregroundStyle(picked ? AnyShapeStyle(.tint) : AnyShapeStyle(.tertiary))
            }
            .padding(.horizontal, 18)
            .frame(maxWidth: .infinity, minHeight: 64, alignment: .leading)
            .contentShape(.rect(cornerRadius: 22))
        }
        .buttonStyle(.plain)
        .glassEffect(.regular.tint(picked ? Color.accentColor.opacity(0.28) : nil).interactive(), in: .rect(cornerRadius: 22))
        .accessibilityAddTraits(picked ? .isSelected : [])
    }

    /// A club's name, and under it where it meets and who runs it; only the name is needed.
    private func clubFields(_ prompt: String, _ club: Binding<Profile.Club>) -> some View {
        VStack(spacing: 0) {
            TextField(prompt, text: club.name)
                #if os(iOS)
                .textInputAutocapitalization(.words)
                #endif
                .frame(minHeight: 46)
            Divider()
            HStack(spacing: 10) {
                TextField("Room", text: club.room)
                Divider()
                    .frame(height: 22)
                TextField("Teacher", text: club.staff)
                    #if os(iOS)
                    .textInputAutocapitalization(.words)
                    #endif
            }
            .font(.subheadline)
            .frame(minHeight: 42)
        }
        .textFieldStyle(.plain)
        .padding(.horizontal, 14)
        .background(.quaternary, in: .rect(cornerRadius: 14))
    }

    // MARK: - Picking

    private func pick(form: String) {
        guard form != draft.form else { return }
        draft.pick(form: form)
        clubs = entries(for: draft)
    }

    /// The club slots on the form's timetable, with whatever the profile already calls them.
    private func entries(for profile: Profile) -> [ClubEntry] {
        Timetable.catalog(for: profile.form).everyone.filter { $0.localizedCaseInsensitiveContains("club") }.map { subject in
            var entry = ClubEntry(subject: subject)
            let named = profile.clubs.filter { $0.subject == subject }
            if let both = named.first(where: { $0.week == nil }) {
                entry.first = both
            } else if !named.isEmpty {
                entry.splits = true
                entry.first = named.first { $0.week == 0 } ?? entry.first
                entry.second = named.first { $0.week == 1 } ?? entry.second
            }
            return entry
        }
    }

    private func finish() {
        /// A club as typed, tidied and pinned to its slot and week; nil when it was left blank.
        func club(_ typed: Profile.Club, _ subject: String, _ week: Int?) -> Profile.Club? {
            func trimmed(_ text: String) -> String { text.trimmingCharacters(in: .whitespaces) }
            guard !trimmed(typed.name).isEmpty else { return nil }
            return Profile.Club(subject: subject, week: week, name: trimmed(typed.name), room: trimmed(typed.room), staff: trimmed(typed.staff))
        }
        var profile = draft
        profile.name = draft.name.trimmingCharacters(in: .whitespaces)
        profile.clubs = clubs.flatMap { entry in
            entry.splits
                ? [club(entry.first, entry.subject, 0), club(entry.second, entry.subject, 1)]
                : [club(entry.first, entry.subject, nil)]
        }.compactMap { $0 }
        done(profile)
    }
}

#Preview("First time") {
    SetupView(existing: nil) { _ in }
}
