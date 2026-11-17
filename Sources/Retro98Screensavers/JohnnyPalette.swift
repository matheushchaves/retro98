// MARK: - Palette
//
// Paleta original, inspirada em pixel art VGA do início dos anos 90:
// poucas cores por material, com rampas curtas pensadas para dithering.

enum JohnnyPalette {
    // Céu (do zênite ao horizonte) e nuvens.
    static let sky: [PixelColor] = [
        0xFF2C6CCC, 0xFF3C80D8, 0xFF5498E4, 0xFF74B0EC, 0xFF98C8F4, 0xFFC0E0F8,
    ]
    static let cloudLit: PixelColor = 0xFFFFFFFF
    static let cloudBody: PixelColor = 0xFFE8F0FC
    static let cloudShade: PixelColor = 0xFFB8CCEC
    static let cloudFar: PixelColor = 0xFFDCECFC

    // Mar (do horizonte ao primeiro plano).
    static let sea: [PixelColor] = [
        0xFF3088CC, 0xFF2070BC, 0xFF1458A8, 0xFF0C4490, 0xFF083478,
    ]
    static let horizonLine: PixelColor = 0xFF0C4C94
    static let seaGlint: PixelColor = 0xFF58A8E4
    static let seaGlintBright: PixelColor = 0xFFA8D8F8
    static let seaTrough: PixelColor = 0xFF062C68
    static let lagoon: PixelColor = 0xFF40BCC8
    static let lagoonDeep: PixelColor = 0xFF2C98C8
    static let foam: PixelColor = 0xFFFFFFFF

    // Ilha.
    static let sand: [PixelColor] = [
        0xFFFCE8B0, 0xFFF0D490, 0xFFE0BC74, 0xFFC89C58, 0xFFA87C44,
    ]
    static let sandRim: PixelColor = 0xFFFFF4CC
    static let sandWet: PixelColor = 0xFF8C6838
    static let sandGrain: PixelColor = 0xFFB88C50
    static let sandShadow: PixelColor = 0xFF987040
    static let rock: PixelColor = 0xFF8C8C98
    static let rockLight: PixelColor = 0xFFB8B8C4
    static let rockDark: PixelColor = 0xFF5C5C6C
    static let shell: PixelColor = 0xFFF8A0A8

    // Palmeira.
    static let trunkLight: PixelColor = 0xFFD0A060
    static let trunk: PixelColor = 0xFFA87838
    static let trunkDark: PixelColor = 0xFF784C1C
    static let trunkRing: PixelColor = 0xFF583410
    static let leafLight: PixelColor = 0xFF68D040
    static let leaf: PixelColor = 0xFF30A428
    static let leafDark: PixelColor = 0xFF18741C
    static let leafBack: PixelColor = 0xFF145C18
    static let leafBackDark: PixelColor = 0xFF0C4414
    static let leafOutline: PixelColor = 0xFF08300C
    static let coconut: PixelColor = 0xFF6C4018
    static let coconutLight: PixelColor = 0xFFA06C34

    // Johnny.
    static let outline: PixelColor = 0xFF28140C
    static let skin: PixelColor = 0xFFECAC7C
    static let skinLight: PixelColor = 0xFFFCCC9C
    static let skinShade: PixelColor = 0xFFC48454
    static let hair: PixelColor = 0xFFC05C18
    static let hairLight: PixelColor = 0xFFEC8C34
    static let hairDark: PixelColor = 0xFF843410
    static let nose: PixelColor = 0xFFF08C70
    static let noseLight: PixelColor = 0xFFFCB498
    static let mouth: PixelColor = 0xFF98201C
    static let eyeWhite: PixelColor = 0xFFFFFFFF
    static let pupil: PixelColor = 0xFF101018
    static let shorts: PixelColor = 0xFF5C78B4
    static let shortsLight: PixelColor = 0xFF88A0D0
    static let shortsDark: PixelColor = 0xFF3C5088
    static let rod: PixelColor = 0xFF6C4418
    static let fishingLine: PixelColor = 0xFFE4E4EC
    static let bobber: PixelColor = 0xFFE83828

    // Bichos.
    static let gull: PixelColor = 0xFFFFFFFF
    static let gullShade: PixelColor = 0xFFB4BCCC
    static let gullOutline: PixelColor = 0xFF30384C
    static let beak: PixelColor = 0xFFF8A020
    static let shark: PixelColor = 0xFF586C8C
    static let sharkLight: PixelColor = 0xFF8498B4
    static let sharkOutline: PixelColor = 0xFF1C2840
    static let fish: PixelColor = 0xFFF88C20
    static let fishLight: PixelColor = 0xFFFCD048
    static let snore: PixelColor = 0xFFFFFFFF
}
