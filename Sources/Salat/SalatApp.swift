import SwiftUI
import PrayerKit

@main
enum Entry {
    static func main() {
        if CommandLine.arguments.contains("--snapshot") {
            MainActor.assumeIsolated { Snapshotter.run(arguments: CommandLine.arguments) }
            return
        }
        SalatApp.main()
    }
}

struct SalatApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @State private var model = AppModel.shared

    var body: some Scene {
        MenuBarExtra {
            PopoverView()
                .environment(model)
        } label: {
            MenuBarLabel(model: model)
        }
        .menuBarExtraStyle(.window)

        Window("Salat", id: "settings") {
            SettingsView()
                .environment(model)
                .localized(model)
        }
        .windowResizability(.contentSize)
        .defaultPosition(.center)

        Window("Timetable", id: "timetable") {
            TimetableView()
                .environment(model)
                .localized(model)
        }
        .windowResizability(.contentSize)
        .defaultPosition(.center)

        Window("Welcome", id: "welcome") {
            WelcomeView()
                .environment(model)
                .localized(model)
        }
        .windowStyle(.hiddenTitleBar)
        .windowResizability(.contentSize)
        .defaultPosition(.center)
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        MainActor.assumeIsolated { AppModel.shared.start() }
    }
}

struct MenuBarLabel: View {
    let model: AppModel
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        content
            .onAppear { model.windowOpener = { openWindow(id: $0) } }
    }

    @ViewBuilder private var content: some View {
        let next = model.nextEvent
        let fmt = model.fmt
        let remaining = next.date.timeIntervalSince(model.now)
        let name = model.displayName(next.prayer, on: next.date)
        // Show seconds automatically during the final minute.
        let countdown = fmt.shortCountdown(remaining, seconds: model.settings.menuBarSeconds || remaining < 60)

        if model.azan.isPlaying && !model.azan.isPreview {
            HStack(spacing: 4) {
                Image(systemName: "speaker.wave.2.fill")
                Text(model.displayName(model.azan.playingPrayer ?? next.prayer, on: model.now))
            }
        } else {
            switch model.settings.menuBarStyle {
            case .iconOnly:
                Image(systemName: next.prayer.fillSymbol)
            case .nameAndCountdown:
                HStack(spacing: 4) {
                    Image(systemName: next.prayer.fillSymbol)
                    Text("\(name) \(model.isArabic ? "" : "−")\(countdown)")
                }
            case .nameAndTime:
                HStack(spacing: 4) {
                    Image(systemName: next.prayer.fillSymbol)
                    Text("\(name) \(fmt.time(next.date))")
                }
            case .countdownOnly:
                HStack(spacing: 4) {
                    Image(systemName: next.prayer.fillSymbol)
                    Text(countdown)
                }
            }
        }
    }
}
