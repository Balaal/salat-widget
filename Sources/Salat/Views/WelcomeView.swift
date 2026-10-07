import SwiftUI
import PrayerKit

/// First-run setup: language, location, method and notification permission on a single page.
struct WelcomeView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismissWindow) private var dismissWindow
    @State private var query = ""
    @State private var results: [SavedLocation] = []
    @State private var openAtLogin = true

    var body: some View {
        @Bindable var model = model
        let L = model.L

        VStack(spacing: 0) {
            ZStack {
                SkyBackground(phase: .dusk)
                VStack(spacing: 6) {
                    Image(systemName: "moon.stars.fill")
                        .font(.system(size: 40))
                        .foregroundStyle(Color.salatGold)
                        .shadow(color: .salatGold.opacity(0.6), radius: 12)
                    Text(L.t("welcome.title")).font(.system(size: 26, weight: .bold, design: .rounded))
                    Text(L.t("welcome.subtitle")).font(.system(size: 13)).opacity(0.8)
                }
                .foregroundStyle(.white)
                .padding(.top, 20)
            }
            .frame(height: 170)

            Form {
                Picker(L.t("general.language"), selection: $model.settings.language) {
                    Text(L.t("language.system")).tag(AppLanguage.system)
                    Text("English").tag(AppLanguage.english)
                    Text("العربية").tag(AppLanguage.arabic)
                }
                .pickerStyle(.segmented)

                Section(L.t("tab.location")) {
                    HStack {
                        Image(systemName: "location.fill").foregroundStyle(Color.accentColor)
                        Text(model.settings.location?.displayName ?? L.t("location.none"))
                        Spacer()
                        if model.locationState == .locating { ProgressView().controlSize(.small) }
                        Button(L.t("welcome.detect")) {
                            model.settings.locationMode = .automatic
                            model.refreshLocation()
                        }
                    }
                    if model.locationState == .denied || model.locationState == .failed {
                        Text(L.t("welcome.searchInstead")).font(.caption).foregroundStyle(.secondary)
                    }
                    TextField(L.t("location.searchPlaceholder"), text: $query)
                        .onSubmit {
                            Task { results = await LocationService.search(query) }
                        }
                    ForEach(results.prefix(4), id: \.self) { r in
                        Button {
                            model.settings.locationMode = .manual
                            model.settings.location = r
                            results = []
                            query = ""
                        } label: {
                            HStack {
                                Text(r.name)
                                Text(r.country ?? "").foregroundStyle(.secondary)
                                Spacer()
                            }.contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                }

                Section(L.t("calc.method")) {
                    Picker(L.t("calc.method"), selection: Binding(
                        get: { model.settings.method },
                        set: { model.settings.autoMethod = false; model.settings.method = $0 })) {
                        ForEach(CalculationMethod.allCases.filter { $0 != .custom }) { m in
                            Text(L.t("method.\(m.rawValue)")).tag(m)
                        }
                    }
                    Picker(L.t("calc.asr"), selection: $model.settings.madhab) {
                        Text(L.t("madhab.standard")).tag(Madhab.standard)
                        Text(L.t("madhab.hanafi")).tag(Madhab.hanafi)
                    }
                }

                Section {
                    Toggle(L.t("general.launchAtLogin"), isOn: $openAtLogin)
                    Text(L.t("welcome.loginHelp")).font(.caption).foregroundStyle(.secondary)
                }
            }
            .formStyle(.grouped)

            HStack {
                Text(L.t("welcome.footer")).font(.caption).foregroundStyle(.secondary)
                Spacer()
                Button(L.t("welcome.start")) {
                    model.settings.hasCompletedOnboarding = true
                    if model.launchAtLogin != openAtLogin { model.launchAtLogin = openAtLogin }
                    Task {
                        await model.refreshNotificationAuthorization(request: true)
                        model.rescheduleNotifications()
                    }
                    dismissWindow(id: "welcome")
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .keyboardShortcut(.defaultAction)
                .disabled(model.settings.location == nil)
            }
            .padding(16)
        }
        .frame(width: 480, height: 720)
        .navigationTitle(L.t("app.name"))
    }
}
