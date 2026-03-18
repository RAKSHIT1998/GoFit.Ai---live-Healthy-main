import AppIntents

// MARK: - App Shortcuts Provider
/// Registers Siri phrases so users can say things like:
///   "Hey Siri, log water in GoFit"
///   "Hey Siri, I had 30ml whiskey with GoFit"
///   "Hey Siri, I ate a banana with GoFit"
///   "Hey Siri, GoFit progress"
///
/// Works WITHOUT opening the app — Siri handles everything inline.
struct GoFitShortcuts: AppShortcutsProvider {
    
    static var appShortcuts: [AppShortcut] {
        
        // MARK: - Water & Drink Logging (including alcohol)
        AppShortcut(
            intent: LogWaterIntent(),
            phrases: [
                "Log water in \(.applicationName)",
                "I had a glass of water with \(.applicationName)",
                "I drank water with \(.applicationName)",
                "Add water in \(.applicationName)",
                "Log \(\.$amountML) ml of water in \(.applicationName)",
                "I drank \(\.$amountML) ml with \(.applicationName)",
                "Log \(\.$drinkType) in \(.applicationName)",
                "I had \(\.$drinkType) with \(.applicationName)",
            ],
            shortTitle: "Log Water or Drink",
            systemImageName: "drop.fill"
        )
        
        // MARK: - Quick Meal Logging
        AppShortcut(
            intent: LogQuickMealIntent(),
            phrases: [
                "Log a meal in \(.applicationName)",
                "I ate \(\.$foodName) with \(.applicationName)",
                "I had \(\.$foodName) with \(.applicationName)",
                "Log \(\.$foodName) in \(.applicationName)",
                "Add \(\.$foodName) to \(.applicationName)",
            ],
            shortTitle: "Log Meal",
            systemImageName: "fork.knife"
        )
        
        // MARK: - Check Progress
        AppShortcut(
            intent: CheckProgressIntent(),
            phrases: [
                "How's my progress in \(.applicationName)",
                "Check my \(.applicationName) progress",
                "\(.applicationName) status",
                "How much water did I drink with \(.applicationName)",
                "What did I eat today with \(.applicationName)",
            ],
            shortTitle: "Check Progress",
            systemImageName: "chart.bar.fill"
        )
    }
}
