import Foundation
import SwiftGPUI

struct FormView: SwiftGPUI.View {
    let model: FormModel

    func layout(node: YogaNode, constraint: LayoutConstraint) -> LayoutNode {
        Flex(direction: .vertical, gap: 16, padding: 24) {

            // ── Header ────────────────────────────────────────────────
            Text("Component Library Demo", font: .heading, color: .primary)
            Text("All standard form components in one view.", font: .body, color: .onSurface)

            // ── Section 1 — Text inputs ───────────────────────────────
            Card(padding: 20) {
                Text("Personal Info", font: .label, color: .primary)
                Input(label: "Full name", binding: GPUIBinding(model, \.name))
                Input(label: "Email", .email, binding: GPUIBinding(model, \.email))
                Input(label: "Password", .password, binding: GPUIBinding(model, \.password))
            }

            // ── Section 2 — Textarea + Search ────────────────────────
            Card(padding: 20) {
                Text("Bio & Discovery", font: .label, color: .primary)
                TextArea(label: "Short bio", lines: 3, binding: GPUIBinding(model, \.bio))
                SearchBox(placeholder: "Search team members…", binding: GPUIBinding(model, \.searchQuery))
            }

            // ── Section 3 — Select + DatePicker ──────────────────────
            Card(padding: 20) {
                Text("Location & Role", font: .label, color: .primary)
                Select(
                    label: "Country",
                    options: [
                        ("Brazil",        "br"),
                        ("United States", "us"),
                        ("Portugal",      "pt"),
                        ("Germany",       "de"),
                        ("Japan",         "jp"),
                    ],
                    binding: GPUIBinding(model, \.country)
                )
                DatePicker(label: "Birth date", binding: GPUIBinding(model, \.birthDate))
            }

            // ── Section 4 — Radio buttons ─────────────────────────────
            Card(padding: 20) {
                Text("Your role", font: .label, color: .primary)
                RadioGroup(
                    options: [
                        ("Software Engineer", "dev"),
                        ("Product Designer",  "design"),
                        ("Product Manager",   "pm"),
                        ("Other",             "other"),
                    ],
                    binding: GPUIBinding(model, \.role)
                )
            }

            // ── Section 5 — Checkboxes ────────────────────────────────
            Card(padding: 20) {
                Text("Preferences", font: .label, color: .primary)
                Checkbox("Send me the newsletter", binding: GPUIBinding(model, \.newsletter))
                Checkbox("I agree to the Terms of Service", binding: GPUIBinding(model, \.agreeToTerms))
            }

            // ── Section 6 — Submit / feedback ────────────────────────
            Card(padding: 20) {
                Text(
                    model.submitted
                        ? "Welcome, \(model.name)! Your profile was saved."
                        : (model.canSubmit ? "Ready to submit." : "Fill in name, email, and accept terms."),
                    font: .body,
                    color: model.submitted ? .primary : .onSurface
                )
                Button(color: .primary)  { "Submit"    } onClick: { model.submit() }
                Button(color: .default)  { "Reset form" } onClick: { model.reset() }
            }

        }
        .layout(node: node, constraint: constraint)
    }
}
