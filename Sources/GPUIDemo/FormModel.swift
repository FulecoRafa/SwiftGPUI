import Observation

@Observable
class FormModel {
    var name: String = ""
    var occupation: String = ""

    var submitted = false

    var greeting: String {
        guard submitted else { return name.isEmpty ? "Type your name above…" : "Hello, \(name)!" }
        return "Welcome, \(name)!"
    }

    var subtitle: String {
        guard submitted else { return occupation.isEmpty ? "And your occupation" : "\(occupation) @ SwiftGPUI" }
        return "\(occupation) — form submitted!"
    }

    func submit() {
        guard !name.isEmpty else { return }
        submitted = true
    }
}
