//
//  TeamIdentity.swift
//  TourOps
//
//  How a team looks across the app: a tint color and a monogram avatar.
//  Teams have no stored color, so the tint is derived from the team's id. It
//  is stable across launches and devices, and nothing is persisted.
//

import SwiftUI
import UIKit

// MARK: - Tint

struct TeamTint {
    let background: Color
    let foreground: Color
}

enum TeamTints {

    private static let all: [TeamTint] = [
        // Ink in Light Mode, cream in Dark Mode.
        TeamTint(background: Palette.accent, foreground: Palette.onAccent),
        TeamTint(background: Color(light: 0x8C7B6B, dark: 0x8C7B6B), foreground: .white),
        TeamTint(background: Color(light: 0xC79A62, dark: 0xC79A62), foreground: .white),
        TeamTint(background: Color(light: 0xB0644A, dark: 0xC9785C), foreground: .white),
        TeamTint(background: Color(light: 0x6F7A5C, dark: 0x8E9A78), foreground: .white),
        TeamTint(background: Color(light: 0x7A5C6E, dark: 0xA47E92), foreground: .white)
    ]

    /// A stable tint for a team. Sums the id's bytes rather than using
    /// `hashValue`, which changes between launches.
    static func tint(for teamID: UUID) -> TeamTint {
        let sum = withUnsafeBytes(of: teamID.uuid) { bytes in
            bytes.reduce(0) { $0 &+ Int($1) }
        }

        return all[sum % all.count]
    }
}

// MARK: - Initials

extension String {

    /// Up to `maxLetters` initials: "Midnight Parade" is "MP", "Cher" is "C"
    /// (or "CH" when two letters are allowed). Returns "?" for blank text.
    func monogram(maxLetters: Int = 1) -> String {
        let words = split(whereSeparator: { $0.isWhitespace })

        guard !words.isEmpty else {
            return "?"
        }

        if words.count == 1 {
            return String(words[0].prefix(maxLetters)).uppercased()
        }

        return words
            .prefix(maxLetters)
            .map { String($0.prefix(1)) }
            .joined()
            .uppercased()
    }
}

// MARK: - Monogram

/// A tinted tile with initials. `cornerRadius == nil` draws a circle.
struct Monogram: View {

    let initials: String
    let tint: TeamTint
    let size: CGFloat
    var cornerRadius: CGFloat? = nil

    var body: some View {
        Text(initials)
            .font(.system(size: size * 0.42, weight: .bold))
            .foregroundStyle(tint.foreground)
            .minimumScaleFactor(0.6)
            .lineLimit(1)
            .frame(width: size, height: size)
            .background { shape.fill(tint.background) }
            .accessibilityHidden(true)
    }

    private var shape: AnyShape {
        if let cornerRadius {
            AnyShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        } else {
            AnyShape(Circle())
        }
    }
}

// MARK: - Avatar

/// The team's artwork when it has any, otherwise its monogram.
struct TeamAvatar: View {

    let team: Team
    let size: CGFloat
    var cornerRadius: CGFloat = Radius.field

    var body: some View {
        if let imageData = team.imageData, let image = UIImage(data: imageData) {
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
                .frame(width: size, height: size)
                .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .strokeBorder(Palette.hairline, lineWidth: 0.8)
                }
                .accessibilityHidden(true)
        } else {
            Monogram(
                initials: team.name.monogram(),
                tint: TeamTints.tint(for: team.id),
                size: size,
                cornerRadius: cornerRadius
            )
        }
    }
}
