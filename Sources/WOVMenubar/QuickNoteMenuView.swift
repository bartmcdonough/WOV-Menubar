import AppKit
import SwiftUI
import WOVMenubarCore

struct QuickNoteMenuView: View {
    @EnvironmentObject private var model: AppModel
    @EnvironmentObject private var appUpdater: AppUpdater
    @State private var showingSetup = false
    @State private var showingOwnerSearch = false
    @State private var showingPropertySearch = false
    @State private var ownerSearchText = ""
    @State private var propertySearchText = ""
    private static let logoImage: NSImage? = {
        let resourceName = "WalkOnValleyLogo"

        if let url = Bundle.main.url(forResource: resourceName, withExtension: "png") {
            return NSImage(contentsOf: url)
        }

        if let bundleURL = Bundle.main.resourceURL?.appendingPathComponent("WOVMenubar_WOVMenubar.bundle"),
           let resourceBundle = Bundle(url: bundleURL),
           let url = resourceBundle.url(forResource: resourceName, withExtension: "png") {
            return NSImage(contentsOf: url)
        }

        return nil
    }()

    var body: some View {
        VStack(spacing: 0) {
            header
            captureBar

            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    connectionSection
                    if shouldShowSetup {
                        setupSection
                    }
                    noteSection
                    recentSection
                }
                .padding(14)
            }
            .frame(minHeight: 430, maxHeight: 650)

            footer
        }
        .background(WOVPortalStyle.background)
        .foregroundStyle(WOVPortalStyle.foreground)
    }

    private var header: some View {
        HStack(spacing: 12) {
            logoMark

            VStack(alignment: .leading, spacing: 3) {
                Text("WALK ON VALLEY")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(Color.white.opacity(0.58))
                Text("Quick Notes")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundStyle(.white)
                Text(headerSubtitle)
                    .font(.system(size: 12))
                    .foregroundStyle(Color.white.opacity(0.66))
                    .lineLimit(1)
            }

            Spacer()

            Button {
                showingSetup.toggle()
            } label: {
                Image(systemName: "gearshape")
            }
            .buttonStyle(PortalIconButtonStyle())
            .foregroundStyle(Color.white.opacity(0.7))
            .help(showingSetup ? "Hide settings" : "Show settings")

            Button {
                NSApplication.shared.terminate(nil)
            } label: {
                Image(systemName: "xmark")
            }
            .buttonStyle(PortalIconButtonStyle())
            .foregroundStyle(Color.white.opacity(0.7))
            .help("Quit")
        }
        .padding(14)
        .background(WOVPortalStyle.sidebar)
    }

    private var logoMark: some View {
        Group {
            if let logoImage = Self.logoImage {
                Image(nsImage: logoImage)
                    .renderingMode(.template)
                    .resizable()
                    .scaledToFit()
                    .foregroundStyle(Color.white.opacity(0.94))
            } else {
                Text("WOV")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(.white)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .frame(width: 126, height: 66)
        .background(WOVPortalStyle.sidebarAccent, in: RoundedRectangle(cornerRadius: WOVPortalStyle.radius, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: WOVPortalStyle.radius, style: .continuous)
                .stroke(Color.white.opacity(0.12), lineWidth: 1)
        )
    }

    private var captureBar: some View {
        HStack(spacing: 12) {
            HStack(spacing: 9) {
                Image(systemName: captureIconName)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(captureIconColor)
                    .frame(width: 28, height: 28)
                    .background(captureIconColor.opacity(0.12), in: Circle())

                VStack(alignment: .leading, spacing: 2) {
                    Text(captureTitle)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(WOVPortalStyle.foreground)
                    Text(captureStatus)
                        .font(.system(size: 12))
                        .foregroundStyle(WOVPortalStyle.muted)
                        .lineLimit(1)
                }
            }

            Spacer()

            primaryCaptureControl
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(WOVPortalStyle.surface)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(WOVPortalStyle.border)
                .frame(height: 1)
        }
    }

    private var connectionSection: some View {
        HStack(spacing: 10) {
            compactConnectionItem(
                title: "Portal",
                value: model.hasPortalSession ? portalUserLabel : "Sign in",
                systemImage: "person.crop.circle",
                isGood: model.hasPortalSession
            )

            compactDivider

            compactConnectionItem(
                title: "Realtime",
                value: model.hasPortalSession ? "Server-side" : "Waiting",
                systemImage: "waveform",
                isGood: model.hasPortalSession
            )

            Spacer(minLength: 8)

            Button {
                Task { await model.refreshPortalContext() }
            } label: {
                Image(systemName: "arrow.clockwise")
            }
            .buttonStyle(PortalIconButtonStyle())
            .help("Refresh")
            .disabled(!model.hasPortalSession)
            .opacity(model.hasPortalSession ? 1 : 0.45)

            Button {
                showingSetup.toggle()
            } label: {
                Image(systemName: showingSetup ? "checkmark" : "gearshape")
            }
            .buttonStyle(PortalIconButtonStyle())
            .help(showingSetup ? "Done" : "Settings")
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(WOVPortalStyle.surface, in: RoundedRectangle(cornerRadius: WOVPortalStyle.radius, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: WOVPortalStyle.radius, style: .continuous)
                .stroke(WOVPortalStyle.border, lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.035), radius: 5, x: 0, y: 2)
    }

    private var setupSection: some View {
        portalPanel(
            title: "Settings",
            subtitle: "Portal access",
            accessory: {
                Button {
                    showingSetup = false
                } label: {
                    Image(systemName: "chevron.up")
                }
                .buttonStyle(PortalIconButtonStyle())
                .help("Hide settings")
            }
        ) {
            VStack(alignment: .leading, spacing: 14) {
                portalSettingsSection
                Divider()
                    .overlay(WOVPortalStyle.border.opacity(0.8))
                updaterSettingsSection
            }
        }
    }

    private var portalSettingsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text("Portal")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(WOVPortalStyle.foreground)
                    Text("System of record")
                        .font(.system(size: 12))
                        .foregroundStyle(WOVPortalStyle.muted)
                }
                Spacer()
                statusPill(model.hasPortalSession ? "Connected" : "Not connected", isGood: model.hasPortalSession)
            }

            if model.hasPortalSession {
                HStack(spacing: 10) {
                    connectionStatusItem(
                        title: "Signed in",
                        value: portalUserLabel,
                        systemImage: "checkmark.circle"
                    )
                    Button {
                        model.clearPortalSession()
                    } label: {
                        Label("Sign Out", systemImage: "rectangle.portrait.and.arrow.right")
                    }
                    .buttonStyle(PortalSecondaryButtonStyle())
                }
            } else {
                VStack(alignment: .leading, spacing: 5) {
                    formLabel("Portal URL")
                    portalTextField("https://portal.walkonvalley.com", text: $model.portalBaseURLText)
                }

                HStack(alignment: .top, spacing: 10) {
                    VStack(alignment: .leading, spacing: 5) {
                        formLabel("Email")
                        portalTextField("name@example.com", text: $model.portalEmail)
                    }
                    VStack(alignment: .leading, spacing: 5) {
                        formLabel("Password")
                        portalSecureField("Password", text: $model.portalPassword)
                    }
                }

                Button {
                    Task { await model.loginToPortal() }
                } label: {
                    Label("Sign In", systemImage: "person.crop.circle.badge.checkmark")
                }
                .buttonStyle(PortalPrimaryButtonStyle())
            }
        }
    }

    private var updaterSettingsSection: some View {
        HStack(alignment: .center, spacing: 10) {
            VStack(alignment: .leading, spacing: 3) {
                Text("Updates")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(WOVPortalStyle.foreground)
                Text(appUpdater.isConfigured ? "Sparkle appcast" : "Release build required")
                    .font(.system(size: 12))
                    .foregroundStyle(WOVPortalStyle.muted)
            }

            Spacer()

            statusPill(appUpdater.isConfigured ? "Ready" : "Not configured", isGood: appUpdater.isConfigured)

            Button {
                appUpdater.checkForUpdates()
            } label: {
                Label("Check for Updates...", systemImage: "arrow.down.circle")
            }
            .buttonStyle(PortalSecondaryButtonStyle())
            .disabled(!appUpdater.isConfigured)
            .opacity(appUpdater.isConfigured ? 1 : 0.52)
        }
    }

    private var noteSection: some View {
        portalPanel(
            title: "Log Quick Note",
            subtitle: "Capture on-site context quickly",
            accessory: { recordingBadge }
        ) {
            VStack(alignment: .leading, spacing: 12) {
                noteEditor

                VStack(alignment: .leading, spacing: 5) {
                    formLabel("Status")
                    Picker("Status", selection: $model.draft.status) {
                        ForEach(QuickNoteStatus.allCases) { status in
                            Text(status.label).tag(status)
                        }
                    }
                    .pickerStyle(.segmented)
                    .tint(WOVPortalStyle.primary)
                }

                HStack(alignment: .top, spacing: 10) {
                    ownerPicker
                    propertyPicker
                }

                HStack(spacing: 8) {
                    Spacer(minLength: 0)

                    Button {
                        model.draft.noteText = ""
                    } label: {
                        Label("Clear", systemImage: "xmark.circle")
                    }
                    .buttonStyle(PortalSecondaryButtonStyle())
                    .disabled(model.draft.noteText.isEmpty)
                    .opacity(model.draft.noteText.isEmpty ? 0.52 : 1)

                    Button {
                        Task { await model.saveQuickNote() }
                    } label: {
                        Label("Save Note", systemImage: "tray.and.arrow.down.fill")
                    }
                    .buttonStyle(PortalPrimaryButtonStyle())
                    .keyboardShortcut(.return, modifiers: [.command])
                    .disabled(!model.canSave)
                    .opacity(model.canSave ? 1 : 0.52)
                }
            }
        }
    }

    private var noteEditor: some View {
        TextEditor(text: $model.draft.noteText)
            .font(.system(size: 13))
            .scrollContentBackground(.hidden)
            .padding(7)
            .frame(minHeight: 116)
            .background(WOVPortalStyle.inputBackground, in: RoundedRectangle(cornerRadius: WOVPortalStyle.radius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: WOVPortalStyle.radius, style: .continuous)
                    .stroke(WOVPortalStyle.border, lineWidth: 1)
            )
            .overlay(alignment: .topLeading) {
                if model.draft.noteText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    Text("Record or type a note...")
                        .font(.system(size: 13))
                        .foregroundStyle(WOVPortalStyle.muted.opacity(0.75))
                        .padding(.horizontal, 13)
                        .padding(.vertical, 14)
                        .allowsHitTesting(false)
                }
            }
    }

    private var ownerPicker: some View {
        VStack(alignment: .leading, spacing: 5) {
            formLabel("Ownership Entity")
            SearchableRecordPicker(
                selectedID: model.selectedEntityID,
                selectedTitle: selectedOwnerTitle,
                searchPrompt: "Search owners",
                emptyTitle: "No owners found",
                options: ownerOptions,
                isPresented: $showingOwnerSearch,
                searchText: $ownerSearchText
            ) { option in
                model.selectedEntityID = option.id
            }
        }
        .frame(maxWidth: .infinity)
    }

    private var propertyPicker: some View {
        VStack(alignment: .leading, spacing: 5) {
            formLabel("Property")
            SearchableRecordPicker(
                selectedID: model.selectedPropertyID,
                selectedTitle: selectedPropertyTitle,
                searchPrompt: "Search properties",
                emptyTitle: "No properties found",
                options: propertyOptions,
                isPresented: $showingPropertySearch,
                searchText: $propertySearchText
            ) { option in
                model.selectedPropertyID = option.id
            }
        }
        .frame(maxWidth: .infinity)
    }

    private var ownerOptions: [SearchablePickerOption] {
        [SearchablePickerOption(id: 0, title: "No ownership entity")]
            + model.entities.map { SearchablePickerOption(id: $0.id, title: $0.name) }
    }

    private var propertyOptions: [SearchablePickerOption] {
        let entityNamesByID = Dictionary(uniqueKeysWithValues: model.entities.map { ($0.id, $0.name) })
        let options = model.selectableProperties.map { property in
            SearchablePickerOption(
                id: property.id,
                title: property.name,
                subtitle: property.entityId.flatMap { entityNamesByID[$0] }
            )
        }
        return [SearchablePickerOption(id: 0, title: "No property")] + options
    }

    private var selectedOwnerTitle: String {
        guard model.selectedEntityID != 0,
              let entity = model.entities.first(where: { $0.id == model.selectedEntityID }) else {
            return "No ownership entity"
        }
        return entity.name
    }

    private var selectedPropertyTitle: String {
        guard model.selectedPropertyID != 0,
              let property = model.properties.first(where: { $0.id == model.selectedPropertyID }) else {
            return "No property"
        }
        return property.name
    }

    @ViewBuilder
    private var recordingControls: some View {
        switch model.recordingState {
        case .idle:
            Button {
                Task { await model.startRecording() }
            } label: {
                Label("Record Note", systemImage: "mic.fill")
            }
            .buttonStyle(PortalPrimaryButtonStyle())
            .disabled(!model.canRecord)
            .opacity(model.canRecord ? 1 : 0.52)
        case .connecting:
            busyControl("Connecting")
        case .recording:
            HStack(spacing: 8) {
                Button {
                    Task { await model.stopRecording() }
                } label: {
                    Label("Stop Recording", systemImage: "stop.fill")
                }
                .buttonStyle(PortalPrimaryButtonStyle())

                Button {
                    Task { await model.cancelRecording() }
                } label: {
                    Image(systemName: "xmark")
                }
                .buttonStyle(PortalIconButtonStyle())
                .help("Cancel recording")
            }
        case .finishing:
            busyControl("Processing")
        }
    }

    @ViewBuilder
    private var primaryCaptureControl: some View {
        if model.recordingState == .idle && !model.canRecord {
            Button {
                showingSetup = true
            } label: {
                Label("Sign In", systemImage: "person.crop.circle.badge.checkmark")
            }
            .buttonStyle(PortalSecondaryButtonStyle())
        } else {
            recordingControls
        }
    }

    private var recentSection: some View {
        portalPanel(
            title: "Recent Notes",
            subtitle: "\(model.recentNotes.count) notes",
            accessory: {
                Image(systemName: "clock")
                    .foregroundStyle(WOVPortalStyle.muted)
            }
        ) {
            VStack(alignment: .leading, spacing: 0) {
                if model.recentNotes.isEmpty {
                    Text("No recent notes loaded.")
                        .font(.system(size: 12))
                        .foregroundStyle(WOVPortalStyle.muted)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.vertical, 2)
                } else {
                    ForEach(model.recentNotes.prefix(4)) { note in
                        VStack(alignment: .leading, spacing: 5) {
                            Text(note.noteText)
                                .font(.system(size: 12, weight: .medium))
                                .foregroundStyle(WOVPortalStyle.foreground)
                                .lineLimit(2)
                            HStack(spacing: 6) {
                                Text(note.status.label)
                                Text("•")
                                    .foregroundStyle(WOVPortalStyle.borderStrong)
                                Text(contextLabel(for: note))
                                    .lineLimit(1)
                            }
                            .font(.system(size: 11))
                            .foregroundStyle(WOVPortalStyle.muted)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.vertical, 8)

                        if note.id != model.recentNotes.prefix(4).last?.id {
                            Divider()
                                .overlay(WOVPortalStyle.border.opacity(0.7))
                        }
                    }
                }
            }
        }
    }

    private var footer: some View {
        HStack(alignment: .top, spacing: 8) {
            Circle()
                .fill(statusDotColor)
                .frame(width: 7, height: 7)
                .padding(.top, 4)
            Text(model.statusMessage)
                .font(.system(size: 12))
                .foregroundStyle(WOVPortalStyle.muted)
                .lineLimit(3)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(WOVPortalStyle.surface)
        .overlay(alignment: .top) {
            Rectangle()
                .fill(WOVPortalStyle.border)
                .frame(height: 1)
        }
    }

    private var shouldShowSetup: Bool {
        showingSetup || !isCaptureReady
    }

    private var isCaptureReady: Bool {
        model.hasPortalSession
    }

    private var connectionSubtitle: String {
        if isCaptureReady {
            "Ready for voice capture"
        } else if !model.hasPortalSession {
            "Portal sign-in required"
        } else {
            "Portal Realtime ready"
        }
    }

    private var portalUserLabel: String {
        let trimmedName = model.currentUserName.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmedName.isEmpty ? "WOV Portal" : trimmedName
    }

    private var headerSubtitle: String {
        let trimmedName = model.currentUserName.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmedName.isEmpty ? "Voice capture for Portal" : "Logged in as \(trimmedName)"
    }

    private var captureIconName: String {
        switch model.recordingState {
        case .idle:
            model.canRecord ? "mic.fill" : "lock.fill"
        case .connecting:
            "dot.radiowaves.left.and.right"
        case .recording:
            "waveform"
        case .finishing:
            "text.badge.checkmark"
        }
    }

    private var captureIconColor: Color {
        switch model.recordingState {
        case .idle:
            model.canRecord ? WOVPortalStyle.primary : WOVPortalStyle.borderStrong
        case .connecting, .finishing:
            Color(red: 0.82, green: 0.55, blue: 0.12)
        case .recording:
            WOVPortalStyle.success
        }
    }

    private var captureTitle: String {
        switch model.recordingState {
        case .idle:
            model.canRecord ? "Voice Note" : "Portal Sign-In"
        case .connecting:
            "Connecting"
        case .recording:
            "Recording"
        case .finishing:
            "Processing"
        }
    }

    private var captureStatus: String {
        switch model.recordingState {
        case .idle:
            model.canRecord ? "Ready" : "Required"
        case .connecting:
            "Opening Portal realtime"
        case .recording:
            "Listening"
        case .finishing:
            "Drafting note"
        }
    }

    private var recordingBadge: some View {
        HStack(spacing: 5) {
            Circle()
                .fill(recordingBadgeColor)
                .frame(width: 7, height: 7)
            Text(recordingBadgeLabel)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(WOVPortalStyle.muted)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(WOVPortalStyle.secondary, in: Capsule())
    }

    private var recordingBadgeLabel: String {
        switch model.recordingState {
        case .idle:
            "Ready"
        case .connecting:
            "Connecting"
        case .recording:
            "Recording"
        case .finishing:
            "Processing"
        }
    }

    private var recordingBadgeColor: Color {
        switch model.recordingState {
        case .recording:
            WOVPortalStyle.primary
        case .connecting, .finishing:
            Color(red: 0.82, green: 0.55, blue: 0.12)
        case .idle:
            model.canRecord ? WOVPortalStyle.success : WOVPortalStyle.borderStrong
        }
    }

    private var statusDotColor: Color {
        if model.statusMessage.localizedCaseInsensitiveContains("failed")
            || model.statusMessage.localizedCaseInsensitiveContains("invalid")
            || model.statusMessage.localizedCaseInsensitiveContains("missing")
            || model.statusMessage.localizedCaseInsensitiveContains("error") {
            return .red
        }
        if model.recordingState == .recording {
            return WOVPortalStyle.primary
        }
        return WOVPortalStyle.success
    }

    private func portalPanel<Accessory: View, Content: View>(
        title: String,
        subtitle: String,
        @ViewBuilder accessory: () -> Accessory,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline, spacing: 10) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(WOVPortalStyle.foreground)
                    Text(subtitle)
                        .font(.system(size: 12))
                        .foregroundStyle(WOVPortalStyle.muted)
                }

                Spacer()

                accessory()
            }

            content()
        }
        .padding(14)
        .background(WOVPortalStyle.surface, in: RoundedRectangle(cornerRadius: WOVPortalStyle.radius, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: WOVPortalStyle.radius, style: .continuous)
                .stroke(WOVPortalStyle.border, lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.05), radius: 8, x: 0, y: 3)
    }

    private func portalTextField(_ title: String, text: Binding<String>) -> some View {
        TextField(title, text: text)
            .textFieldStyle(.plain)
            .font(.system(size: 13))
            .foregroundStyle(WOVPortalStyle.foreground)
            .padding(.horizontal, 10)
            .frame(height: 36)
            .background(WOVPortalStyle.inputBackground, in: RoundedRectangle(cornerRadius: WOVPortalStyle.radius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: WOVPortalStyle.radius, style: .continuous)
                    .stroke(WOVPortalStyle.border, lineWidth: 1)
            )
    }

    private func portalSecureField(_ title: String, text: Binding<String>) -> some View {
        SecureField(title, text: text)
            .textFieldStyle(.plain)
            .font(.system(size: 13))
            .foregroundStyle(WOVPortalStyle.foreground)
            .padding(.horizontal, 10)
            .frame(height: 36)
            .background(WOVPortalStyle.inputBackground, in: RoundedRectangle(cornerRadius: WOVPortalStyle.radius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: WOVPortalStyle.radius, style: .continuous)
                    .stroke(WOVPortalStyle.border, lineWidth: 1)
            )
    }

    private func formLabel(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 12, weight: .semibold))
            .foregroundStyle(WOVPortalStyle.foreground)
    }

    private func statusPill(_ text: String, isGood: Bool) -> some View {
        HStack(spacing: 5) {
            Circle()
                .fill(isGood ? WOVPortalStyle.success : WOVPortalStyle.borderStrong)
                .frame(width: 6, height: 6)
            Text(text)
                .font(.system(size: 11, weight: .semibold))
        }
        .foregroundStyle(isGood ? WOVPortalStyle.success : WOVPortalStyle.muted)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background((isGood ? WOVPortalStyle.success : WOVPortalStyle.muted).opacity(0.12), in: Capsule())
    }

    private var compactDivider: some View {
        Rectangle()
            .fill(WOVPortalStyle.border)
            .frame(width: 1, height: 22)
    }

    private func compactConnectionItem(title: String, value: String, systemImage: String, isGood: Bool) -> some View {
        HStack(spacing: 6) {
            Circle()
                .fill(isGood ? WOVPortalStyle.success : WOVPortalStyle.borderStrong)
                .frame(width: 6, height: 6)

            Image(systemName: systemImage)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(WOVPortalStyle.primary)
                .frame(width: 14)

            Text(title)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(WOVPortalStyle.muted)

            Text(value)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(WOVPortalStyle.foreground)
                .lineLimit(1)
                .truncationMode(.tail)
        }
    }

    private func connectionStatusItem(title: String, value: String, systemImage: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: systemImage)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(WOVPortalStyle.primary)
                .frame(width: 18)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(WOVPortalStyle.muted)
                Text(value)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(WOVPortalStyle.foreground)
                    .lineLimit(1)
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 9)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(WOVPortalStyle.secondary, in: RoundedRectangle(cornerRadius: WOVPortalStyle.radius, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: WOVPortalStyle.radius, style: .continuous)
                .stroke(WOVPortalStyle.border.opacity(0.8), lineWidth: 1)
        )
    }

    private func busyControl(_ text: String) -> some View {
        HStack(spacing: 8) {
            ProgressView()
                .controlSize(.small)
            Text(text)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(WOVPortalStyle.muted)
        }
        .frame(minHeight: 34)
    }

    private func contextLabel(for note: QuickNote) -> String {
        if let property = note.propertyName, !property.isEmpty {
            return property
        }
        if let entity = note.entityName, !entity.isEmpty {
            return entity
        }
        return "Unlinked"
    }
}

private struct SearchablePickerOption: Identifiable, Hashable {
    let id: Int
    let title: String
    var subtitle: String?
}

private struct SearchableRecordPicker: View {
    let selectedID: Int
    let selectedTitle: String
    let searchPrompt: String
    let emptyTitle: String
    let options: [SearchablePickerOption]
    @Binding var isPresented: Bool
    @Binding var searchText: String
    let onSelect: (SearchablePickerOption) -> Void

    @FocusState private var searchIsFocused: Bool

    private var filteredOptions: [SearchablePickerOption] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return options }
        return options.filter { option in
            option.title.localizedCaseInsensitiveContains(query)
                || (option.subtitle?.localizedCaseInsensitiveContains(query) ?? false)
        }
    }

    var body: some View {
        Button {
            isPresented = true
        } label: {
            HStack(spacing: 8) {
                Text(selectedTitle)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(WOVPortalStyle.foreground)
                    .lineLimit(1)
                    .truncationMode(.tail)

                Spacer(minLength: 6)

                Image(systemName: "chevron.up.chevron.down")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(WOVPortalStyle.muted)
            }
            .padding(.horizontal, 10)
            .frame(height: 36)
            .background(WOVPortalStyle.inputBackground, in: RoundedRectangle(cornerRadius: WOVPortalStyle.radius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: WOVPortalStyle.radius, style: .continuous)
                    .stroke(WOVPortalStyle.border, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .popover(isPresented: $isPresented, arrowEdge: .bottom) {
            popoverContent
        }
        .onChange(of: isPresented) { _, newValue in
            if newValue {
                searchText = ""
            }
        }
    }

    private var popoverContent: some View {
        VStack(spacing: 0) {
            HStack(spacing: 7) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(WOVPortalStyle.muted)

                TextField(searchPrompt, text: $searchText)
                    .textFieldStyle(.plain)
                    .font(.system(size: 13))
                    .focused($searchIsFocused)

                if !searchText.isEmpty {
                    Button {
                        searchText = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(WOVPortalStyle.muted)
                    .help("Clear search")
                }
            }
            .padding(.horizontal, 10)
            .frame(height: 36)
            .background(WOVPortalStyle.inputBackground, in: RoundedRectangle(cornerRadius: WOVPortalStyle.radius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: WOVPortalStyle.radius, style: .continuous)
                    .stroke(WOVPortalStyle.border, lineWidth: 1)
            )
            .padding(10)

            Divider()
                .overlay(WOVPortalStyle.border)

            ScrollView {
                LazyVStack(alignment: .leading, spacing: 2) {
                    if filteredOptions.isEmpty {
                        Text(emptyTitle)
                            .font(.system(size: 12))
                            .foregroundStyle(WOVPortalStyle.muted)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 14)
                    } else {
                        ForEach(filteredOptions) { option in
                            optionRow(option)
                        }
                    }
                }
                .padding(6)
            }
            .frame(maxHeight: 260)
        }
        .frame(width: 360)
        .background(WOVPortalStyle.surface)
        .onAppear {
            DispatchQueue.main.async {
                searchIsFocused = true
            }
        }
    }

    private func optionRow(_ option: SearchablePickerOption) -> some View {
        Button {
            onSelect(option)
            isPresented = false
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "checkmark")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(WOVPortalStyle.primary)
                    .frame(width: 16)
                    .opacity(option.id == selectedID ? 1 : 0)

                VStack(alignment: .leading, spacing: 2) {
                    Text(option.title)
                        .font(.system(size: 13, weight: option.id == selectedID ? .semibold : .regular))
                        .foregroundStyle(WOVPortalStyle.foreground)
                        .lineLimit(1)

                    if let subtitle = option.subtitle, !subtitle.isEmpty {
                        Text(subtitle)
                            .font(.system(size: 11))
                            .foregroundStyle(WOVPortalStyle.muted)
                            .lineLimit(1)
                    }
                }

                Spacer(minLength: 0)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, option.subtitle == nil ? 8 : 6)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                option.id == selectedID ? WOVPortalStyle.primarySoft : Color.clear,
                in: RoundedRectangle(cornerRadius: 6, style: .continuous)
            )
            .contentShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
        }
        .buttonStyle(.plain)
    }
}
