//
//  AnimatableSystemFontModifier.swift
//  EmojiArt
//
//  Created by Sergey Zakharenko on 31.03.2023.
//

import SwiftUI

struct AnimatableSystemFontModifier: ViewModifier, Animatable {
    var size: Double
    
    var animatableData: Double {
        get { size }
        set { size = newValue }
    }
    
    func body(content: Content) -> some View {
        content.font(.system(size: size))
    }
}

extension View {
    func animatableSystemFont(size: Double) -> some View {
        self.modifier(AnimatableSystemFontModifier(size: size))
    }
}
