import Foundation

struct MathExpressionRenderer {
    private let commands: [String: String] = [
        "alpha": "α", "beta": "β", "gamma": "γ", "delta": "δ",
        "epsilon": "ε", "theta": "θ", "lambda": "λ", "mu": "μ",
        "pi": "π", "sigma": "σ", "phi": "φ", "omega": "ω",
        "infty": "∞", "times": "×", "cdot": "·", "pm": "±",
        "leq": "≤", "geq": "≥", "neq": "≠", "rightarrow": "→",
        "leftarrow": "←", "to": "→", "sum": "∑", "prod": "∏",
        "int": "∫", "sqrt": "√"
    ]

    func displayText(for expression: String) -> String {
        var result = ""
        let characters = Array(expression.trimmingCharacters(in: .whitespacesAndNewlines))
        var index = 0

        while index < characters.count {
            let character = characters[index]
            if character == "\\" {
                index += 1
                let start = index
                while index < characters.count, characters[index].isLetter {
                    index += 1
                }
                let command = String(characters[start..<index])
                if command == "frac" {
                    let numerator = consumeGroup(from: characters, index: &index)
                    let denominator = consumeGroup(from: characters, index: &index)
                    if !numerator.isEmpty || !denominator.isEmpty {
                        result += "(\(displayText(for: numerator))⁄\(displayText(for: denominator)))"
                    }
                } else if command == "left" || command == "right" {
                    continue
                } else if let symbol = commands[command] {
                    result += symbol
                } else {
                    result += command
                }
                continue
            }

            if character == "^" || character == "_" {
                let isSuperscript = character == "^"
                index += 1
                let token = consumeToken(from: characters, index: &index)
                result += isSuperscript ? superscript(token) : subscriptText(token)
                continue
            }

            if character == "{" || character == "}" {
                index += 1
                continue
            }

            result.append(character)
            index += 1
        }
        return result
    }

    private func consumeGroup(from characters: [Character], index: inout Int) -> String {
        while index < characters.count, characters[index].isWhitespace { index += 1 }
        guard index < characters.count, characters[index] == "{" else { return "" }
        index += 1
        let start = index
        var depth = 1
        while index < characters.count, depth > 0 {
            if characters[index] == "{" { depth += 1 }
            if characters[index] == "}" { depth -= 1 }
            index += 1
        }
        let end = max(start, index - 1)
        return String(characters[start..<min(end, characters.count)])
    }

    private func consumeToken(from characters: [Character], index: inout Int) -> String {
        while index < characters.count, characters[index].isWhitespace { index += 1 }
        if index < characters.count, characters[index] == "{" {
            return consumeGroup(from: characters, index: &index)
        }
        guard index < characters.count else { return "" }
        let token = String(characters[index])
        index += 1
        return token
    }

    private func superscript(_ text: String) -> String {
        String(text.map { character -> Character in
            switch character {
            case "0": return "⁰"
            case "1": return "¹"
            case "2": return "²"
            case "3": return "³"
            case "4": return "⁴"
            case "5": return "⁵"
            case "6": return "⁶"
            case "7": return "⁷"
            case "8": return "⁸"
            case "9": return "⁹"
            case "+": return "⁺"
            case "-": return "⁻"
            case "=": return "⁼"
            case "n": return "ⁿ"
            case "i": return "ⁱ"
            default: return character
            }
        })
    }

    private func subscriptText(_ text: String) -> String {
        String(text.map { character -> Character in
            switch character {
            case "0": return "₀"
            case "1": return "₁"
            case "2": return "₂"
            case "3": return "₃"
            case "4": return "₄"
            case "5": return "₅"
            case "6": return "₆"
            case "7": return "₇"
            case "8": return "₈"
            case "9": return "₉"
            case "+": return "₊"
            case "-": return "₋"
            case "=": return "₌"
            default: return character
            }
        })
    }
}
