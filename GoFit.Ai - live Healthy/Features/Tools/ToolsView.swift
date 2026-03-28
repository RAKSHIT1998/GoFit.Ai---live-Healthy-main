import SwiftUI

struct ToolsView: View {
    var body: some View {
        NavigationView {
            List {
                NavigationLink(destination: TDEECalculatorView()) {
                    Label("TDEE Calculator", systemImage: "flame")
                }
                NavigationLink(destination: BMICalculatorView()) {
                    Label("BMI Calculator", systemImage: "scalemass")
                }
                NavigationLink(destination: MacroCalculatorView()) {
                    Label("Macro Calculator", systemImage: "leaf")
                }
                NavigationLink(destination: OneRMCalculatorView()) {
                    Label("1RM Calculator", systemImage: "dumbbell")
                }
            }
            .navigationTitle("Tools & Calculators")
        }
    }
}

// Placeholder views for each calculator
struct TDEECalculatorView: View {
    var body: some View {
        Text("TDEE Calculator Coming Soon")
            .font(.title2)
            .padding()
    }
}

struct BMICalculatorView: View {
    var body: some View {
        Text("BMI Calculator Coming Soon")
            .font(.title2)
            .padding()
    }
}

struct MacroCalculatorView: View {
    var body: some View {
        Text("Macro Calculator Coming Soon")
            .font(.title2)
            .padding()
    }
}

struct OneRMCalculatorView: View {
    var body: some View {
        Text("1RM Calculator Coming Soon")
            .font(.title2)
            .padding()
    }
}
