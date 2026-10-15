//
//  ScheduleView.swift
//  TourOps
//
//  The Schedule tab: a week strip, team filter chips and an agenda of shows
//  from the selected day onward. Everything shown is derived from the existing
//  teams, tours and shows (see ScheduleAgenda); nothing new is stored.
//

import SwiftUI

struct ScheduleView: View {

    let teamRepository: TeamRepositoryProtocol
    let tourRepository: TourRepositoryProtocol
    let showRepository: ShowRepositoryProtocol

    @Environment(DataRefreshSignal.self) private var refreshSignal
    @Environment(\.floatingNavInset) private var navInset
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    /// Holds the shows and handles editing and deleting from show detail.
    @State private var showModel: ShowListViewModel

    @State private var teams: [Team] = []
    @State private var tours: [Tour] = []
    @State private var loadError: String?
    @State private var hasCompletedFirstLoad = false

    @State private var selectedDay = Calendar.current.startOfDay(for: Date())
    @State private var selectedTeamID: UUID?
    @State private var showingDatePicker = false

    init(
        teamRepository: TeamRepositoryProtocol,
        tourRepository: TourRepositoryProtocol,
        showRepository: ShowRepositoryProtocol
    ) {
        self.teamRepository = teamRepository
        self.tourRepository = tourRepository
        self.showRepository = showRepository

        _showModel = State(
            initialValue: ShowListViewModel(repository: showRepository)
        )
    }

    private var calendar: Calendar { .current }

    // MARK: - Derived data

    private var sortedTeams: [Team] {
        teams.sorted { lhs, rhs in
            let result = lhs.name.localizedStandardCompare(rhs.name)

            if result == .orderedSame {
                return lhs.createdAt < rhs.createdAt
            }

            return result == .orderedAscending
        }
    }

    /// The selected team filter, or `nil` if none is selected or the team no
    /// longer exists.
    private var activeTeamID: UUID? {
        guard let selectedTeamID, teams.contains(where: { $0.id == selectedTeamID }) else {
            return nil
        }

        return selectedTeamID
    }

    private var entries: [ScheduleAgenda.Entry] {
        ScheduleAgenda.entries(
            shows: showModel.shows,
            tours: tours,
            teams: teams,
            teamFilter: activeTeamID
        )
    }

    // MARK: - Body

    var body: some View {
        NavigationStack {
            ZStack {
                Palette.canvas
                    .ignoresSafeArea()

                VStack(spacing: 0) {
                    header
                    content
                }
            }
            .toolbar(.hidden, for: .navigationBar)
            .sheet(isPresented: $showingDatePicker) {
                datePickerSheet
            }
            .task(id: refreshSignal.generation) {
                await load()
            }
        }
    }

    private func load() async {
        await showModel.loadShows()

        do {
            async let fetchedTeams = teamRepository.fetchTeams()
            async let fetchedTours = tourRepository.fetchTours()

            let (loadedTeams, loadedTours) = try await (fetchedTeams, fetchedTours)

            teams = loadedTeams
            tours = loadedTours
            loadError = showModel.loadErrorMessage
        } catch is CancellationError {
            // A superseded load is not a failure.
        } catch {
            loadError = error.localizedDescription
        }

        // A cancelled load was superseded; the replacement marks completion.
        if !Task.isCancelled {
            hasCompletedFirstLoad = true
        }
    }

    // MARK: - Header

    private var header: some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: 0) {
                Text("Schedule")
                    .font(.screenTitle)
                    .foregroundStyle(Palette.primaryText)
                    .accessibilityAddTraits(.isHeader)

                monthRow
                    .padding(.top, 14)

                weekStrip
                    .padding(.top, 12)

                Rectangle()
                    .fill(Palette.hairline)
                    .frame(height: 0.7)
                    .padding(.top, 14)
                    .accessibilityHidden(true)
            }
            .padding(.horizontal, 20)

            if !teams.isEmpty {
                teamChips
                    .padding(.top, 12)
            }
        }
        .padding(.top, 14)
        .padding(.bottom, 8)
    }

    private var monthRow: some View {
        let title = selectedDay.formatted(.dateTime.month(.wide).year())

        return Button {
            showingDatePicker = true
        } label: {
            HStack(spacing: 10) {
                Text(title)
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(Palette.primaryText)

                Image(systemName: "chevron.up.chevron.down")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(Palette.secondaryText)
                    .frame(width: 24, height: 24)
                    .background(Circle().fill(Palette.surfaceRaised))
                    .accessibilityHidden(true)
            }
            .frame(minHeight: 44, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Choose date")
        .accessibilityValue(title)
    }

    private var weekStrip: some View {
        let week = ScheduleAgenda.weekDays(containing: selectedDay, calendar: calendar)
        let daysWithShows = ScheduleAgenda.daysWithShows(in: entries, calendar: calendar)
        let today = calendar.startOfDay(for: Date())

        return HStack(spacing: 0) {
            ForEach(week, id: \.self) { day in
                DayCell(
                    day: day,
                    isSelected: calendar.isDate(day, inSameDayAs: selectedDay),
                    isToday: day == today,
                    hasShows: daysWithShows.contains(day)
                ) {
                    selectedDay = day
                }
                .frame(maxWidth: .infinity)
            }
        }
        .gesture(
            DragGesture(minimumDistance: 24)
                .onEnded { value in
                    if value.translation.width < -40 {
                        shiftWeek(by: 1)
                    } else if value.translation.width > 40 {
                        shiftWeek(by: -1)
                    }
                }
        )
        .accessibilityAction(named: "Next week") { shiftWeek(by: 1) }
        .accessibilityAction(named: "Previous week") { shiftWeek(by: -1) }
    }

    private func shiftWeek(by weeks: Int) {
        guard let moved = calendar.date(byAdding: .day, value: weeks * 7, to: selectedDay) else {
            return
        }

        withAnimation(.snappy(duration: 0.25)) {
            selectedDay = calendar.startOfDay(for: moved)
        }
    }

    private var teamChips: some View {
        ScrollView(.horizontal) {
            HStack(spacing: 10) {
                ScheduleChip(title: "All teams", isSelected: activeTeamID == nil) {
                    selectedTeamID = nil
                }

                ForEach(sortedTeams) { team in
                    ScheduleChip(title: team.name, isSelected: activeTeamID == team.id) {
                        selectedTeamID = team.id
                    }
                }
            }
            .padding(.horizontal, 20)
        }
        .scrollIndicators(.hidden)
    }

    private var datePickerSheet: some View {
        VStack(spacing: 8) {
            HStack {
                Button("Today") {
                    selectedDay = calendar.startOfDay(for: Date())
                    showingDatePicker = false
                }

                Spacer()

                Button("Done") {
                    showingDatePicker = false
                }
                .fontWeight(.semibold)
            }
            .padding(.horizontal, 20)
            .padding(.top, 22)

            DatePicker(
                "Date",
                selection: Binding(
                    get: { selectedDay },
                    set: { selectedDay = calendar.startOfDay(for: $0) }
                ),
                displayedComponents: .date
            )
            .datePickerStyle(.graphical)
            .labelsHidden()
            .padding(.horizontal, 12)

            Spacer(minLength: 0)
        }
        .background(Palette.canvas.ignoresSafeArea())
        .presentationDetents([.medium])
        .presentationDragIndicator(.visible)
        .presentationCornerRadius(Radius.sheet)
        .presentationBackground(Palette.canvas)
    }

    // MARK: - Content

    @ViewBuilder
    private var content: some View {
        if !hasCompletedFirstLoad {
            LoadingPanel(message: "Loading schedule…")
        } else if let loadError, showModel.shows.isEmpty, teams.isEmpty {
            StatePanel(
                symbol: "exclamationmark.triangle",
                title: "Couldn’t load the schedule",
                message: loadError,
                actionTitle: "Try Again",
                isPrimaryAction: false
            ) {
                Task { await load() }
            }
        } else if teams.isEmpty {
            StatePanel(
                symbol: "calendar",
                title: "Nothing scheduled yet",
                message: "Add a team with the + button. Its tours and shows will appear here."
            )
        } else {
            agenda
        }
    }

    private var agenda: some View {
        let allEntries = entries
        let sections = ScheduleAgenda.sections(
            entries: allEntries,
            from: selectedDay,
            calendar: calendar
        )
        let nextID = ScheduleAgenda.nextUp(in: allEntries)?.id

        return ScrollView {
            LazyVStack(alignment: .leading, spacing: 24) {
                ForEach(sections) { section in
                    daySection(
                        section,
                        nextID: nextID,
                        hasAnyShows: !allEntries.isEmpty
                    )
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 14)
            .padding(.bottom, 32 + navInset)
        }
        .scrollIndicators(.hidden)
    }

    private func daySection(
        _ section: ScheduleAgenda.DaySection,
        nextID: UUID?,
        hasAnyShows: Bool
    ) -> some View {
        let count = section.entries.count

        return VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                Text(
                    section.day.formatted(
                        .dateTime.weekday(.wide).day().month(.wide)
                    )
                )
                .font(.title3.weight(.bold))
                .foregroundStyle(Palette.primaryText)
                .accessibilityAddTraits(.isHeader)

                Spacer(minLength: 8)

                Text(count == 1 ? "1 show" : "\(count) shows")
                    .font(.subheadline)
                    .foregroundStyle(Palette.secondaryText)
            }

            if section.entries.isEmpty {
                emptyDay(hasAnyShows: hasAnyShows)
            } else {
                ForEach(section.entries) { entry in
                    ScheduleRow(
                        entry: entry,
                        isNext: entry.id == nextID,
                        showModel: showModel
                    )
                }
            }
        }
    }

    private func emptyDay(hasAnyShows: Bool) -> some View {
        Text(
            hasAnyShows
                ? "No shows on this day."
                : "No shows yet. Use + to add one."
        )
        .font(.subheadline)
        .foregroundStyle(Palette.secondaryText)
        .frame(maxWidth: .infinity, minHeight: 64, alignment: .center)
        .multilineTextAlignment(.center)
        .padding(.horizontal, 16)
        .cardSurface()
    }
}

// MARK: - Day cell

private struct DayCell: View {

    let day: Date
    let isSelected: Bool
    let isToday: Bool
    let hasShows: Bool
    let action: () -> Void

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        Button(action: action) {
            VStack(spacing: 6) {
                Text(day.formatted(.dateTime.weekday(.abbreviated)))
                    .font(.subheadline)
                    .foregroundStyle(Palette.secondaryText)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)

                Text(day.formatted(.dateTime.day()))
                    .font(.title3.weight(.bold))
                    .foregroundStyle(isToday ? Palette.orange : Palette.primaryText)

                Circle()
                    .fill(dotColor)
                    .frame(width: 5, height: 5)
            }
            .padding(.vertical, 10)
            .frame(maxWidth: .infinity)
            .background {
                if isSelected {
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .fill(Palette.surface)
                        .shadow(
                            color: colorScheme == .dark ? .clear : Color.black.opacity(0.07),
                            radius: 8,
                            x: 0,
                            y: 3
                        )
                        .overlay {
                            RoundedRectangle(cornerRadius: 22, style: .continuous)
                                .strokeBorder(Palette.hairline, lineWidth: 0.7)
                        }
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
        .accessibilityLabel(
            day.formatted(.dateTime.weekday(.wide).day().month(.wide))
        )
        .accessibilityValue(accessibilityValue)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    private var dotColor: Color {
        guard hasShows else {
            return .clear
        }

        return isSelected ? Palette.primaryText : Palette.secondaryText.opacity(0.75)
    }

    private var accessibilityValue: String {
        var parts: [String] = []

        if isToday {
            parts.append("Today")
        }

        if hasShows {
            parts.append("Has shows")
        }

        return parts.joined(separator: ", ")
    }
}

// MARK: - Filter chip

private struct ScheduleChip: View {

    let title: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.subheadline.weight(isSelected ? .semibold : .regular))
                .foregroundStyle(isSelected ? Palette.onAccent : Palette.secondaryText)
                .lineLimit(1)
                .padding(.horizontal, 16)
                .padding(.vertical, 9)
                .background {
                    Capsule().fill(isSelected ? Palette.accent : Palette.chipFill)
                }
                .overlay {
                    Capsule()
                        .strokeBorder(
                            isSelected ? Color.clear : Palette.hairline,
                            lineWidth: 0.7
                        )
                }
                .frame(minHeight: 44)
                .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

// MARK: - Row

/// One show in the agenda: a time rail on the left and a card that opens the
/// show's detail screen.
private struct ScheduleRow: View {

    let entry: ScheduleAgenda.Entry
    let isNext: Bool
    let showModel: ShowListViewModel

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @ScaledMetric(relativeTo: .body) private var railWidth: CGFloat = 56

    var body: some View {
        let layout = dynamicTypeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: 8))
            : AnyLayout(HStackLayout(alignment: .top, spacing: 12))

        return layout {
            timeRail

            NavigationLink {
                ShowDetailView(
                    showID: entry.show.id,
                    viewModel: showModel
                )
            } label: {
                ScheduleShowCard(entry: entry, isNext: isNext)
            }
            .buttonStyle(CardPressStyle())
            .accessibilityHint("Opens show details")
        }
    }

    private var timeRail: some View {
        let parts = entry.show.date
            .formatted(date: .omitted, time: .shortened)
            .components(separatedBy: .whitespaces)
            .filter { !$0.isEmpty }

        return VStack(alignment: .leading, spacing: 2) {
            Text(parts.first ?? "")
                .font(.headline)
                .foregroundStyle(Palette.primaryText)
                .lineLimit(1)
                .minimumScaleFactor(0.8)

            if parts.count > 1 {
                Text(parts[1])
                    .font(.subheadline)
                    .foregroundStyle(Palette.secondaryText)
            }
        }
        .frame(
            width: dynamicTypeSize.isAccessibilitySize ? nil : railWidth,
            alignment: .leading
        )
        .padding(.top, 14)
        .accessibilityHidden(true)
    }
}

// MARK: - Card

private struct ScheduleShowCard: View {

    let entry: ScheduleAgenda.Entry
    let isNext: Bool

    @ScaledMetric(relativeTo: .body) private var monogramSize: CGFloat = 24

    private var title: String {
        let city = entry.show.city.trimmed
        return city.isEmpty ? entry.show.name.trimmed : city
    }

    private var subtitle: String {
        [entry.tour.name.trimmed, entry.show.venue.trimmed]
            .filter { !$0.isEmpty }
            .joined(separator: " · ")
    }

    private var accessibilityText: String {
        var parts = [
            title,
            entry.show.date.formatted(date: .complete, time: .shortened)
        ]

        if !subtitle.isEmpty {
            parts.append(subtitle)
        }

        parts.append(entry.team.name.trimmed)

        if isNext {
            parts.append("Next up")
        }

        return parts.joined(separator: ", ")
    }

    var body: some View {
        let tint = TeamTints.tint(for: entry.team.id)

        return HStack(alignment: .top, spacing: 12) {
            RoundedRectangle(cornerRadius: 2, style: .continuous)
                .fill(tint.background)
                .frame(width: 3)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 4) {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(title)
                        .font(.title3.weight(.bold))
                        .foregroundStyle(Palette.primaryText)
                        .lineLimit(2)

                    if isNext {
                        Text("Next up")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(Palette.orangeText)
                            .lineLimit(1)
                            .fixedSize()
                    }
                }

                if !subtitle.isEmpty {
                    Text(subtitle)
                        .font(.callout)
                        .foregroundStyle(Palette.secondaryText)
                        .lineLimit(2)
                }

                HStack(spacing: 8) {
                    Monogram(
                        initials: entry.team.name.monogram(maxLetters: 2),
                        tint: tint,
                        size: monogramSize
                    )

                    Text(entry.team.name)
                        .font(.callout)
                        .foregroundStyle(Palette.secondaryText)
                        .lineLimit(1)

                    Spacer(minLength: 4)

                    Image(systemName: "chevron.right")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(Palette.secondaryText)
                        .accessibilityHidden(true)
                }
                .padding(.top, 8)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardSurface()
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityText)
    }
}

// MARK: - Previews

#if DEBUG
@MainActor
private func previewSchedule(
    shows: [Show],
    tours: [Tour] = [PreviewData.upcomingTour],
    teams: [Team] = [PreviewData.team]
) -> some View {
    ScheduleView(
        teamRepository: PreviewTeamRepository(teams: teams),
        tourRepository: PreviewTourRepository(tours: tours),
        showRepository: PreviewShowRepository(shows: shows)
    )
    .environment(DataRefreshSignal())
}

#Preview("Populated, light") {
    previewSchedule(shows: [
        PreviewData.todayShow,
        PreviewData.upcomingShow,
        PreviewData.pastShow
    ])
    .preferredColorScheme(.light)
}

#Preview("Populated, dark") {
    previewSchedule(shows: [
        PreviewData.todayShow,
        PreviewData.upcomingShow,
        PreviewData.pastShow
    ])
    .preferredColorScheme(.dark)
}

#Preview("No shows") {
    previewSchedule(shows: [])
}

#Preview("No teams") {
    previewSchedule(shows: [], tours: [], teams: [])
}

#Preview("Accessibility text size") {
    previewSchedule(shows: [PreviewData.upcomingShow, PreviewData.longShow])
        .dynamicTypeSize(.accessibility3)
}
#endif
