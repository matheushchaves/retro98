// MARK: - Sprites
//
// Arte original desenhada à mão (1 caractere = 1 pixel, "." = transparente).
// Todos os sprites olham para a direita; a cena espelha quando precisa.

enum CastawayHead {
    case normal, blink, asleep, surprised, yawn
}

enum JohnnySprites {
    private static let headPalette: [Character: PixelColor] = [
        "X": JohnnyPalette.outline,
        "h": JohnnyPalette.hair, "H": JohnnyPalette.hairLight, "b": JohnnyPalette.hairDark,
        "s": JohnnyPalette.skin, "S": JohnnyPalette.skinLight,
        "n": JohnnyPalette.nose, "N": JohnnyPalette.noseLight,
        "w": JohnnyPalette.eyeWhite, "k": JohnnyPalette.pupil, "r": JohnnyPalette.mouth,
    ]

    /// Ponto do sprite da cabeça que encaixa no pescoço do boneco.
    static let headNeckAnchor = PixelPoint(x: 7, y: 15)

    // Cabelo espetado, olho arregalado, narigão e barba ruiva até o peito.
    private static let headRows: [String] = [
        "......X..X......",  //  0 pontas do cabelo
        "...X.XhXXhX.X...",  //  1
        "..XhXhHhhHhXhX..",  //  2
        "..XhhHhhhhHhhX..",  //  3
        ".XhhHhhhhhhhhX..",  //  4
        ".XhhhhsSSSSshX..",  //  5 testa
        ".XbhhsSSwwSsX...",  //  6 olho
        ".XbhhsSSwkSSXX..",  //  7
        "..XhhsSSSSnnnnX.",  //  8 nariz
        "..XbhsssSnnNNnX.",  //  9
        "..XbhhhsshnnnX..",  // 10 bigode
        "..XhhHhhhhhXX...",  // 11
        "..XhHhhXXXhhX...",  // 12 boca
        "...XhhhhhhhHX...",  // 13 barba
        "...XbhhhhhhX....",  // 14
        "....XbhHhhX.....",  // 15
        ".....XbhhX......",  // 16
        "......XXX.......",  // 17
    ]

    private static let eyesClosed: [Int: String] = [
        6: ".XbhhsSSSSSsX...",
        7: ".XbhhsSXXXSSXX..",
    ]

    private static let headOverrides: [CastawayHead: [Int: String]] = [
        .normal: [:],
        .blink: eyesClosed,
        .asleep: eyesClosed.merging([12: "..XhHhhXrXhhX..."]) { $1 },
        .surprised: [
            5: ".XhhhhsSwwwshX..",
            6: ".XbhhsSwwwwsX...",
            7: ".XbhhsSwkwwSXX..",
            12: "..XhHhXrrXhhX...",
            13: "...XhhXrrXhHX...",
        ],
        .yawn: eyesClosed.merging([
            11: "..XhhHhXXXhXX...",
            12: "..XhHhXrrrXhX...",
            13: "...XhhXrrrXHX...",
            14: "...XbhhXXXhX....",
        ]) { $1 },
    ]

    static func head(_ kind: CastawayHead) -> PixelSprite {
        let overrides = headOverrides[kind] ?? [:]
        let rows = headRows.enumerated().map { overrides[$0.offset] ?? $0.element }
        return PixelSprite(rows, palette: headPalette)
    }

    // MARK: Gaivota

    private static let gullPalette: [Character: PixelColor] = [
        "X": JohnnyPalette.gullOutline, "w": JohnnyPalette.gull, "g": JohnnyPalette.gullShade,
        "k": JohnnyPalette.pupil, "o": JohnnyPalette.beak,
    ]

    /// Ciclo de voo: asa para cima, estendida, para baixo, estendida.
    static let gullCycle: [PixelSprite] = [gullWingUp, gullWingFlat, gullWingDown, gullWingFlat]

    private static let gullWingUp = PixelSprite([
        "....XX..........",
        "...XwgX.........",
        "...XwwgX........",
        "....XwwgX.......",
        ".XXXXXwwwXXX....",
        "XwwwwwwwwwwkXoo.",
        ".XXgwwwwwwwwXX..",
        "...XXXXXXXXX....",
    ], palette: gullPalette)

    private static let gullWingFlat = PixelSprite([
        "................",
        "................",
        "................",
        "..XXXXXXX.......",
        ".XXgggwwwXXX....",
        "XwwwwwwwwwwkXoo.",
        ".XXgwwwwwwwwXX..",
        "...XXXXXXXXX....",
    ], palette: gullPalette)

    private static let gullWingDown = PixelSprite([
        "................",
        "................",
        "................",
        "................",
        ".XXXXXXXXXXX....",
        "XwwwwwwwwwwkXoo.",
        ".XXgwwgwwwwwXX..",
        "...XXwwgXXXX....",
        "....XwwgX.......",
        ".....XwgX.......",
        "......XX........",
    ], palette: gullPalette)

    // MARK: Tubarão, peixe, boia

    static let sharkFin = PixelSprite([
        "..XX........",
        "..XfX.......",
        "..XLfX......",
        "..XLffX.....",
        "..XLfffXX...",
        ".XLLfffffX..",
        ".XLfffffffX.",
        "XLLffffffffX",
    ], palette: [
        "X": JohnnyPalette.sharkOutline, "f": JohnnyPalette.shark, "L": JohnnyPalette.sharkLight,
    ])

    /// Peixinho pendurado no anzol (cabeça para cima).
    static let hookedFish = PixelSprite([
        "..X..",
        ".XfX.",
        "XfLfX",
        "XkLfX",
        "XfLfX",
        ".XfX.",
        "XfXfX",
        "XX.XX",
    ], palette: [
        "X": JohnnyPalette.outline, "f": JohnnyPalette.fish, "L": JohnnyPalette.fishLight,
        "k": JohnnyPalette.pupil,
    ])

    static let bobber = PixelSprite([
        ".X.",
        "XwX",
        "XrX",
    ], palette: ["X": JohnnyPalette.outline, "w": JohnnyPalette.eyeWhite, "r": JohnnyPalette.bobber])

    // MARK: Ronco

    private static let snorePalette: [Character: PixelColor] = ["Z": JohnnyPalette.snore]

    /// "z" pequeno, médio e grande, na ordem em que sobem.
    static let snoreGlyphs: [PixelSprite] = [
        PixelSprite(["ZZZZ", "..Z.", ".Z..", "ZZZZ"], palette: snorePalette),
        PixelSprite(["ZZZZZ", "...Z.", "..Z..", ".Z...", "ZZZZZ"], palette: snorePalette),
        PixelSprite(["ZZZZZZ", "ZZZZZZ", "...ZZ.", "..ZZ..", ".ZZ...", "ZZZZZZ", "ZZZZZZ"], palette: snorePalette),
    ]
}
