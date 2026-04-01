import Testing
import GPUIDraw
import GPUILayout
import GPUIInterpret
@testable import SwiftGPUI

@Suite("Interpreter")
struct InterpreterTests {

    @Test("login form produz pelo menos 5 comandos")
    func loginFormCommandCount() {
        let form = Card {
            Input(label: "usuário", value: "exemplo@email.com")
            Input(.password)
            Flex(direction: .horizontal) {
                Button { "Cancel" }
                Button(color: .primary) { "Login" }
            }
        }

        let commands = Interpreter().interpret(
            view: form,
            constraint: .loose(Size(width: 360, height: 800))
        )

        // Card + 2 inputs + flex container + 2 buttons = ≥ 5
        #expect(commands.count >= 5)
    }

    @Test("todos os frames têm dimensões positivas")
    func allFramesPositive() {
        let form = Card {
            Input(label: "email")
            Button { "OK" }
        }

        let commands = Interpreter().interpret(
            view: form,
            constraint: .loose(Size(width: 360, height: 800))
        )

        for (frame, _) in commands {
            #expect(frame.width > 0)
            #expect(frame.height > 0)
        }
    }
}
