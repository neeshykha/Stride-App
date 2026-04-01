import SwiftUI

struct ConfettiPiece: Identifiable {
    let id = UUID()
    var x: CGFloat
    var y: CGFloat
    let color: Color
    let size: CGFloat
    let rotation: Double
    let velocity: CGFloat
    let horizontalDrift: CGFloat
}

struct ConfettiOverlay: View {
    let trigger: Int
    @State private var pieces: [ConfettiPiece] = []
    @State private var animating = false

    private let colors: [Color] = [
        Color(red: 0.231, green: 0.510, blue: 0.965), // blue
        Color(red: 0.961, green: 0.620, blue: 0.043), // gold
        Color(red: 0.976, green: 0.451, blue: 0.086), // orange
        Color(red: 0.388, green: 0.400, blue: 0.945), // indigo
        .green, .pink, .mint
    ]

    var body: some View {
        GeometryReader { geo in
            ZStack {
                ForEach(pieces) { piece in
                    RoundedRectangle(cornerRadius: 2)
                        .fill(piece.color)
                        .frame(width: piece.size, height: piece.size * 0.6)
                        .rotationEffect(.degrees(piece.rotation))
                        .position(x: piece.x, y: piece.y)
                }
            }
            .allowsHitTesting(false)
            .onChange(of: trigger) { _, _ in
                spawnConfetti(in: geo.size)
            }
        }
    }

    private func spawnConfetti(in size: CGSize) {
        let newPieces = (0..<40).map { _ in
            ConfettiPiece(
                x: size.width / 2 + CGFloat.random(in: -50...50),
                y: size.height / 2,
                color: colors.randomElement()!,
                size: CGFloat.random(in: 6...12),
                rotation: Double.random(in: 0...360),
                velocity: CGFloat.random(in: 200...500),
                horizontalDrift: CGFloat.random(in: -200...200)
            )
        }
        pieces = newPieces

        withAnimation(.easeOut(duration: 1.5)) {
            pieces = pieces.map { piece in
                var p = piece
                p.y = -50
                p.x = piece.x + piece.horizontalDrift
                return p
            }
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 1.6) {
            pieces = []
        }
    }
}
