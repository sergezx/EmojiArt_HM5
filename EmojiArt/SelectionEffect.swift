//
//  SelectionEffect.swift
//  EmojiArt
//
//  Created by Sergey Zakharenko on 01.03.2023.
//

import SwiftUI

struct SelectionEffect: ViewModifier {
    var emoji: EmojiArtModel.Emoji
    var selectedEmoji: Set<EmojiArtModel.Emoji>
    
    func body(content: Content) -> some View {
        content
            .overlay(
                selectedEmoji.contains(emoji) ?
                RoundedRectangle(cornerRadius: DrawingConstants.cornerRadius)
                    .strokeBorder(lineWidth: DrawingConstants.lineWidth)
                    .foregroundColor(DrawingConstants.foregroundColor)
                : nil
            )
    }
    
    private struct DrawingConstants {
        static let cornerRadius: CGFloat = 0
        static let lineWidth: CGFloat = 1.3
        static let foregroundColor: Color = .black
    }
}


extension View {
    func selectionEffect(for emoji: EmojiArtModel.Emoji, in selectedEmoji: Set<EmojiArtModel.Emoji>) -> some View {
        modifier(SelectionEffect(emoji: emoji, selectedEmoji: selectedEmoji))
    }
}
