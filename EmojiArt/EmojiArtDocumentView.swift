//
//  EmojiArtDocumentView.swift
//  EmojiArt
//
//  Created by CS193p Instructor on 4/26/21.
//  Copyright © 2021 Stanford University. All rights reserved.
//

import SwiftUI

struct EmojiArtDocumentView: View {
    typealias Emoji = EmojiArtModel.Emoji
    
    @ObservedObject var document: EmojiArtDocument
    
    let defaultEmojiFontSize: CGFloat = 40
    
    var body: some View {
        VStack(spacing: 0) {
            documentBody
            palette
        }
    }
    
    var documentBody: some View {
        GeometryReader { geometry in
            if #available(iOS 15.0, *) {
                ZStack {
                    Color.white.overlay(
                        OptionalImage(uiImage: document.backgroundImage)
                            .scaleEffect(zoomScale)
                            .position(convertFromEmojiCoordinates((0,0), in: geometry))
                    )
                    .gesture(doubleTapToZoom(in: geometry.size).exclusively(before: tapToUnselectAllEmojis()))
                    if document.backgroundImageFetchStatus == .fetching {
                        ProgressView().scaleEffect(2)
                    } else {
                        ForEach(document.emojis) { emoji in
                            Text(emoji.text)
//                                .animatableSystemFont(size: fontSize(for: emoji))
                                .font(.system(size: fontSize(for: emoji)))
                                .selectionEffect(for: emoji, in: selectedEmojis)
                                .position(position(for: emoji, in: geometry))
                                .gesture(selectionGesture(on: emoji).simultaneously(with: longPressToDelete(on: emoji).simultaneously(with: panEmojiGesture(for: emoji))))
                        }
                    }
                }
                .clipped()
                .onDrop(of: [.plainText,.url,.image], isTargeted: nil) { providers, location in
                    drop(providers: providers, at: location, in: geometry)
                }
                .gesture(panGesture().simultaneously(with: zoomGesture()))
                .alert("Delete", isPresented: $showDeleteAlert, presenting: deleteEmoji) { deleteEmoji in
                    deleteEmojiOnDemand(for: deleteEmoji)
                }
            } else {
                // Fallback on earlier versions
            }
        }
    }
    
    // MARK: - Drag and Drop
    
    private func drop(providers: [NSItemProvider], at location: CGPoint, in geometry: GeometryProxy) -> Bool {
        var found = providers.loadObjects(ofType: URL.self) { url in
            document.setBackground(.url(url.imageURL))
        }
        if !found {
            found = providers.loadObjects(ofType: UIImage.self) { image in
                if let data = image.jpegData(compressionQuality: 1.0) {
                    document.setBackground(.imageData(data))
                }
            }
        }
        if !found {
            found = providers.loadObjects(ofType: String.self) { string in
                if let emoji = string.first, emoji.isEmoji {
                    document.addEmoji(
                        String(emoji),
                        at: convertToEmojiCoordinates(location, in: geometry),
                        size: defaultEmojiFontSize / zoomScale
                    )
                }
            }
        }
        return found
    }
    
    // MARK: - Positioning/Sizing Emoji
    
    private func position(for emoji: EmojiArtModel.Emoji, in geometry: GeometryProxy) -> CGPoint {
        convertFromEmojiCoordinates((emoji.x, emoji.y), in: geometry) + emojiOffset(for: emoji)
    }
    
    private func fontSize(for emoji: EmojiArtModel.Emoji) -> CGFloat {
        if selectedEmojis.contains(emoji) {
            return CGFloat(emoji.size) * selectionZoomScale
        } else {
            return CGFloat(emoji.size) * zoomScale
        }
    }
    
    private func convertToEmojiCoordinates(_ location: CGPoint, in geometry: GeometryProxy) -> (x: Int, y: Int) {
        let center = geometry.frame(in: .local).center
        let location = CGPoint(
            x: (location.x - panOffset.width - center.x) / zoomScale,
            y: (location.y - panOffset.height - center.y) / zoomScale
        )
        return (Int(location.x), Int(location.y))
    }
    
    private func convertFromEmojiCoordinates(_ location: (x: Int, y: Int), in geometry: GeometryProxy) -> CGPoint {
        let center = geometry.frame(in: .local).center
        return CGPoint(
            x: center.x + CGFloat(location.x) * zoomScale + panOffset.width,
            y: center.y + CGFloat(location.y) * zoomScale + panOffset.height
        )
    }
    
    // MARK: - Zooming
    
    @State private var steadyStateZoomScale: CGFloat = 1
    @GestureState private var gestureZoomScale: (background: CGFloat, selection: CGFloat) = (1,1)
//    @GestureState private var gestureZoomScale: CGFloat = 1

    private var zoomScale: CGFloat {
        steadyStateZoomScale * gestureZoomScale.background
    }
    
    private var selectionZoomScale: CGFloat {
        steadyStateZoomScale * gestureZoomScale.selection
    }
    
    private func zoomGesture() -> some Gesture {
        MagnificationGesture()
            .updating($gestureZoomScale) { latestGestureScale, gestureZoomScale, _ in
                if selectedEmojis.isEmpty {
                    gestureZoomScale.background = latestGestureScale
                } else {
                    gestureZoomScale.selection = latestGestureScale
                }
            }
            .onEnded { gestureScaleAtEnd in
                if selectedEmojis.isEmpty {
                    steadyStateZoomScale *= gestureScaleAtEnd
                } else {
                    for emoji in selectedEmojis {
                        document.scaleEmoji(emoji, by: gestureScaleAtEnd)
                    }
                }
            }
    }
    
    private func doubleTapToZoom(in size: CGSize) -> some Gesture {
        TapGesture(count: 2)
            .onEnded {
                withAnimation {
                    zoomToFit(document.backgroundImage, in: size)
                }
            }
    }
    
    private func zoomToFit(_ image: UIImage?, in size: CGSize) {
        if let image = image, image.size.width > 0, image.size.height > 0, size.width > 0, size.height > 0  {
            let hZoom = size.width / image.size.width
            let vZoom = size.height / image.size.height
            steadyStatePanOffset = .zero
            steadyStateZoomScale = min(hZoom, vZoom)
        }
    }
    
    // MARK: - Panning
    
    @State private var steadyStatePanOffset: CGSize = CGSize.zero
    @GestureState private var gesturePanOffset: CGSize = CGSize.zero
    @GestureState private var gestureEmojiPanOffset: [Int:CGSize] = [:]

    private var panOffset: CGSize {
        (steadyStatePanOffset + gesturePanOffset) * zoomScale
    }
    
    private func panGesture() -> some Gesture {
        DragGesture()
            .updating($gesturePanOffset) { latestDragGestureValue, gesturePanOffset, _ in
                gesturePanOffset = latestDragGestureValue.translation / zoomScale
            }
            .onEnded { finalDragGestureValue in
                steadyStatePanOffset = steadyStatePanOffset + (finalDragGestureValue.translation / zoomScale)
            }
    }

    private func emojiOffset(for emoji: EmojiArtModel.Emoji) -> CGSize {
      if let offset = gestureEmojiPanOffset[emoji.id] {
        return offset * zoomScale
      }
      return .zero
    }

    private func panEmojiGesture(for emoji: EmojiArtModel.Emoji) -> some Gesture {
        DragGesture()
            .updating($gestureEmojiPanOffset) { latestDragGestureValue, gestureEmojiDragOffset, _ in
                if selectedEmojis.index(matching: emoji) != nil {
                    for emoji in selectedEmojis {
                        gestureEmojiDragOffset[emoji.id] = latestDragGestureValue.translation / zoomScale
                    }
                } else {
                    gestureEmojiDragOffset[emoji.id] = latestDragGestureValue.translation / zoomScale
                }
            }
            .onEnded { finalDragGesture in
                if selectedEmojis.index(matching: emoji) != nil {
                    for emoji in selectedEmojis {
                        document.moveEmoji(emoji, by: finalDragGesture.translation / zoomScale)
                    }
                } else
                {
                    document.moveEmoji(emoji, by: finalDragGesture.translation / zoomScale)
                }
            }
    }
    
    // MARK: - Selecting/Unselecting Emojis
    
    @State private var selectedEmojis = Set<EmojiArtModel.Emoji>()
    
    private func selectionGesture(on emoji: EmojiArtModel.Emoji) -> some Gesture {
        TapGesture()
            .onEnded {
                withAnimation {
                    selectedEmojis.toggleMembership(of: emoji)
                }
            }
    }
    
    private func tapToUnselectAllEmojis() -> some Gesture {
        TapGesture()
            .onEnded {
                withAnimation {
                    selectedEmojis = []
                }
            }
    }
    
    // MARK: - Deleting Emojis
    
    @State var showDeleteAlert: Bool = false
    @State var deleteEmoji: EmojiArtModel.Emoji?
    
    private func longPressToDelete(on emoji: EmojiArtModel.Emoji) -> some Gesture {
        LongPressGesture(minimumDuration: 1.5)
            .onEnded { LongPressStateAtEnd in
                if LongPressStateAtEnd
                {
                    showDeleteAlert.toggle()
                    deleteEmoji =  emoji
                } else {
                    deleteEmoji = nil
                }
            }
    }
    
    @available(iOS 15.0, *)
    private func deleteEmojiOnDemand(for emoji: EmojiArtModel.Emoji) -> some View {
        Button(role: .destructive) {
            if selectedEmojis.contains(emoji) {
                selectedEmojis.remove(emoji)
            }
            document.removeEmoji(emoji)
        } label: { Text("Yes") }
    }
    
    // MARK: - Palette
    
    var palette: some View {
        ScrollingEmojisView(emojis: testEmojis)
            .font(.system(size: defaultEmojiFontSize))
    }
    
    let testEmojis = "😀😷🦠💉👻👀🐶🌲🌎🌞🔥🍎⚽️🚗🚓🚲🛩🚁🚀🛸🏠⌚️🎁🗝🔐❤️⛔️❌❓✅⚠️🎶➕➖🏳️"
}

struct ScrollingEmojisView: View {
    let emojis: String

    var body: some View {
        ScrollView(.horizontal) {
            HStack {
                ForEach(emojis.map { String($0) }, id: \.self) { emoji in
                    Text(emoji)
                        .onDrag { NSItemProvider(object: emoji as NSString) }
                }
            }
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        EmojiArtDocumentView(document: EmojiArtDocument())
    }
}
