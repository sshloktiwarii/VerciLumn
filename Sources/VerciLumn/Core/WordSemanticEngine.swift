import SwiftUI
import Combine

public enum SemanticMood: String, CaseIterable, Identifiable {
    case fire = "Fire & Heat"
    case speed = "Speed & Velocity"
    case love = "Passion & Love"
    case cold = "Cold & Ice"
    case luxury = "Luxury & Royalty"
    case impact = "Bass Impact"
    case celestial = "Celestial & Dream"
    case defaultHarmonic = "Harmonic Rhythm"
    
    public var id: String { rawValue }
    
    public var icon: String {
        switch self {
        case .fire: return "flame.fill"
        case .speed: return "bolt.horizontal.fill"
        case .love: return "heart.fill"
        case .cold: return "snowflake"
        case .luxury: return "crown.fill"
        case .impact: return "burst.fill"
        case .celestial: return "sparkles"
        case .defaultHarmonic: return "music.note"
        }
    }
}

public struct SemanticStyle: Equatable, @unchecked Sendable {
    public let mood: SemanticMood
    public let fontDesign: Font.Design
    public let fontWeight: Font.Weight
    public let isItalic: Bool
    public let primaryGradient: [Color]
    public let glowColor: Color
    public let particleType: ParticleBurstType
    public let borderType: BadgeBorderType
    public let shakeIntensity: CGFloat
}

public enum ParticleBurstType: Equatable {
    case embers
    case speedStreaks
    case floatingHearts
    case iceCrystals
    case goldDust
    case shockwave
    case starTwinkle
    case subtleRhythm
}

public enum BadgeBorderType: Equatable {
    case blazingGlow
    case kineticStreak
    case softPill
    case frostedGlass
    case metallicGold
    case invertedBlock
    case cosmicAura
    case standardAccent
}

public final class WordSemanticEngine: ObservableObject {
    public static let shared = WordSemanticEngine()
    
    @Published public var isEnabled: Bool = true
    @Published public var intensity: Double = 1.0 // 0.5 (Subtle), 1.0 (Expressive), 1.5 (Extreme)
    
    // Fast O(1) Lexicon Dictionary Mapping word stems to Moods
    private var lexicon: [String: SemanticMood] = [:]
    
    private init() {
        populateLexicon()
    }
    
    public func evaluate(word: String, genreHint: String = "") -> SemanticStyle {
        let cleaned = word.lowercased().trimmingCharacters(in: .punctuationCharacters.union(.whitespaces))
        guard isEnabled, !cleaned.isEmpty else {
            return defaultStyle(for: .defaultHarmonic)
        }
        
        let mood = lexicon[cleaned] ?? findStemMood(for: cleaned) ?? fallbackMood(for: cleaned, genre: genreHint)
        return style(for: mood)
    }
    
    private func findStemMood(for word: String) -> SemanticMood? {
        // Common suffix stripping: -ing, -ed, -es, -s, -er, -est
        let suffixes = ["ing", "est", "er", "ed", "es", "ly", "s"]
        for suffix in suffixes {
            if word.hasSuffix(suffix) && word.count > suffix.count + 2 {
                let stem = String(word.dropLast(suffix.count))
                if let matched = lexicon[stem] {
                    return matched
                }
            }
        }
        return nil
    }
    
    private func fallbackMood(for word: String, genre: String) -> SemanticMood {
        let g = genre.lowercased()
        if g.contains("hip-hop") || g.contains("rap") || g.contains("trap") {
            return (word.count % 5 == 0) ? .impact : .defaultHarmonic
        } else if g.contains("edm") || g.contains("dance") || g.contains("electronic") {
            return (word.count % 4 == 0) ? .speed : .defaultHarmonic
        } else if g.contains("r&b") || g.contains("soul") || g.contains("romance") {
            return (word.count % 4 == 0) ? .love : .defaultHarmonic
        }
        return .defaultHarmonic
    }
    
    private func style(for mood: SemanticMood) -> SemanticStyle {
        switch mood {
        case .fire:
            return SemanticStyle(
                mood: .fire,
                fontDesign: .default,
                fontWeight: .black,
                isItalic: false,
                primaryGradient: [Color(red: 1.0, green: 0.22, blue: 0.05), Color(red: 1.0, green: 0.55, blue: 0.0)],
                glowColor: Color(red: 1.0, green: 0.3, blue: 0.0),
                particleType: .embers,
                borderType: .blazingGlow,
                shakeIntensity: 4.0 * CGFloat(intensity)
            )
            
        case .speed:
            return SemanticStyle(
                mood: .speed,
                fontDesign: .rounded,
                fontWeight: .black,
                isItalic: true,
                primaryGradient: [Color(red: 0.0, green: 0.85, blue: 1.0), Color(red: 0.0, green: 0.5, blue: 1.0)],
                glowColor: Color(red: 0.0, green: 0.8, blue: 1.0),
                particleType: .speedStreaks,
                borderType: .kineticStreak,
                shakeIntensity: 2.0 * CGFloat(intensity)
            )
            
        case .love:
            return SemanticStyle(
                mood: .love,
                fontDesign: .rounded,
                fontWeight: .bold,
                isItalic: false,
                primaryGradient: [Color(red: 1.0, green: 0.28, blue: 0.45), Color(red: 0.95, green: 0.45, blue: 0.65)],
                glowColor: Color(red: 1.0, green: 0.35, blue: 0.55),
                particleType: .floatingHearts,
                borderType: .softPill,
                shakeIntensity: 0.0
            )
            
        case .cold:
            return SemanticStyle(
                mood: .cold,
                fontDesign: .monospaced,
                fontWeight: .heavy,
                isItalic: false,
                primaryGradient: [Color(red: 0.7, green: 0.92, blue: 1.0), Color(red: 0.3, green: 0.6, blue: 0.95)],
                glowColor: Color(red: 0.6, green: 0.85, blue: 1.0),
                particleType: .iceCrystals,
                borderType: .frostedGlass,
                shakeIntensity: 1.0 * CGFloat(intensity)
            )
            
        case .luxury:
            return SemanticStyle(
                mood: .luxury,
                fontDesign: .serif,
                fontWeight: .black,
                isItalic: false,
                primaryGradient: [Color(red: 1.0, green: 0.84, blue: 0.0), Color(red: 0.85, green: 0.65, blue: 0.12)],
                glowColor: Color(red: 1.0, green: 0.82, blue: 0.2),
                particleType: .goldDust,
                borderType: .metallicGold,
                shakeIntensity: 0.0
            )
            
        case .impact:
            return SemanticStyle(
                mood: .impact,
                fontDesign: .monospaced,
                fontWeight: .black,
                isItalic: false,
                primaryGradient: [Color.white, Color(white: 0.85)],
                glowColor: Color.white,
                particleType: .shockwave,
                borderType: .invertedBlock,
                shakeIntensity: 7.0 * CGFloat(intensity)
            )
            
        case .celestial:
            return SemanticStyle(
                mood: .celestial,
                fontDesign: .rounded,
                fontWeight: .semibold,
                isItalic: false,
                primaryGradient: [Color(red: 0.6, green: 0.3, blue: 1.0), Color(red: 0.3, green: 0.4, blue: 0.95)],
                glowColor: Color(red: 0.65, green: 0.35, blue: 1.0),
                particleType: .starTwinkle,
                borderType: .cosmicAura,
                shakeIntensity: 0.0
            )
            
        case .defaultHarmonic:
            return defaultStyle(for: .defaultHarmonic)
        }
    }
    
    private func defaultStyle(for mood: SemanticMood) -> SemanticStyle {
        return SemanticStyle(
            mood: .defaultHarmonic,
            fontDesign: .rounded,
            fontWeight: .black,
            isItalic: false,
            primaryGradient: [Color.white, Color.white.opacity(0.85)],
            glowColor: Color.accentColor,
            particleType: .subtleRhythm,
            borderType: .standardAccent,
            shakeIntensity: 0.0
        )
    }
    
    private func populateLexicon() {
        // 1. FIRE & HEAT
        let fireWords = [
            "fire", "burn", "hot", "flame", "blaze", "smoke", "fever", "lit", "spark", "ember",
            "heat", "hell", "wildfire", "ignite", "torch", "ash", "ashes", "lava", "red", "warm",
            "sizzle", "cook", "glow", "pyro", "blast", "combust", "flare", "roast", "flaming", "burning"
        ]
        for w in fireWords { lexicon[w] = .fire }
        
        // 2. SPEED & VELOCITY
        let speedWords = [
            "swish", "fly", "drive", "fast", "run", "rush", "speed", "race", "zoom", "dash",
            "drift", "quick", "turbo", "car", "ride", "motion", "jet", "plane", "chase", "flash",
            "hyper", "warp", "escape", "cruise", "accelerate", "skate", "roller", "swift", "flying", "running"
        ]
        for w in speedWords { lexicon[w] = .speed }
        
        // 3. PASSION & LOVE
        let loveWords = [
            "love", "heart", "kiss", "baby", "feel", "touch", "hold", "sweet", "romance", "angel",
            "darling", "honey", "beautiful", "pretty", "hug", "lips", "cuddle", "forever", "mine", "crush",
            "desire", "passion", "soulmate", "babe", "girl", "boy", "queen", "lover", "loving", "tender"
        ]
        for w in loveWords { lexicon[w] = .love }
        
        // 4. COLD & ICE
        let coldWords = [
            "cold", "ice", "freeze", "snow", "chill", "dark", "winter", "frost", "zero", "stone",
            "numb", "frozen", "polar", "glacier", "cool", "cry", "tear", "tears", "shiver", "pale",
            "bleak", "lonely", "shadow", "icey", "freezing", "chilly", "arctic"
        ]
        for w in coldWords { lexicon[w] = .cold }
        
        // 5. LUXURY & ROYALTY
        let luxuryWords = [
            "rich", "money", "gold", "diamond", "crown", "king", "boss", "cash", "benz", "rolex",
            "shining", "million", "billion", "gucci", "prada", "porsche", "lambo", "wealth", "palace", "royalty",
            "jewel", "chain", "chains", "bands", "racks", "stack", "stacks", "expensive", "vip", "luxury"
        ]
        for w in luxuryWords { lexicon[w] = .luxury }
        
        // 6. BASS IMPACT & DROPS
        let impactWords = [
            "bomb", "drop", "bass", "beat", "boom", "hit", "loud", "shock", "shake", "bang",
            "strike", "smash", "pop", "heavy", "clap", "smack", "thunder", "quake", "crash", "stomp",
            "snap", "kick", "punch", "drum", "explosive", "dynamite", "impact", "slam"
        ]
        for w in impactWords { lexicon[w] = .impact }
        
        // 7. CELESTIAL & DREAM
        let celestialWords = [
            "sky", "star", "night", "moon", "dream", "space", "universe", "high", "cloud", "heaven",
            "paradise", "blue", "sun", "sunrise", "sunset", "galaxy", "orbit", "infinite", "magic", "spirit",
            "floating", "float", "cosmic", "aura", "stars", "clouds", "dreaming", "eyes"
        ]
        for w in celestialWords { lexicon[w] = .celestial }
    }
}

