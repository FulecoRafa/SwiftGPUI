import Testing
import GPUIDraw

@Suite("Color")
struct ColorTests {
    @Test("skColor encoding")
    func skColorEncoding() {
        let white = Color(r: 1, g: 1, b: 1, a: 1)
        #expect(white.skColor == 0xFFFFFFFF)

        let black = Color(r: 0, g: 0, b: 0, a: 1)
        #expect(black.skColor == 0xFF000000)

        let transparent = Color(r: 1, g: 0, b: 0, a: 0)
        #expect(transparent.skColor == 0x00FF0000)
    }
}

@Suite("Rect")
struct RectTests {
    @Test("maxX / maxY")
    func maxXY() {
        let r = Rect(x: 10, y: 20, width: 100, height: 50)
        #expect(r.maxX == 110)
        #expect(r.maxY == 70)
    }
}
