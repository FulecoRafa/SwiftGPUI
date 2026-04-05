import Foundation
import Observation

@Observable
class FormModel {
    // Personal info
    var name: String = ""
    var email: String = ""
    var password: String = ""
    var birthDate: Date = Date()
    var bio: String = ""

    // Preferences
    var country: String = "br"
    var role: String = "dev"
    var searchQuery: String = ""
    var newsletter: Bool = false
    var agreeToTerms: Bool = false

    // Submission
    var submitted: Bool = false

    var canSubmit: Bool { !name.isEmpty && !email.isEmpty && agreeToTerms }

    func submit() {
        guard canSubmit else { return }
        submitted = true
    }

    func reset() {
        name = ""
        email = ""
        password = ""
        bio = ""
        searchQuery = ""
        newsletter = false
        agreeToTerms = false
        submitted = false
    }
}
