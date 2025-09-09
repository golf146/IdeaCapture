//
//  BubbleCanvas.swift
//  IdeaCapture
//
//  封装 SwiftUI 气泡渲染与随机布局（与数据层解耦）
//

import SwiftUI

struct BubbleItem: Identifiable, Equatable {
    let id = UUID()
    let idea: Idea
    let fontSize: CGFloat
    let color: Color
    let position: CGPoint
}

struct BubbleCanvas: View {
    let ideas: [Idea]
    @Binding var isEditing: Bool
    var onDelete: (Idea) -> Void

    @State private var items: [BubbleItem] = []

    var body: some View {
        GeometryReader { geo in
            ZStack {
                ForEach(items) { item in
                    BubbleItemView(
                        item: item,
                        isEditing: $isEditing,
                        onDelete: onDelete
                    )
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .onAppear { relayout(in: geo.size) }
            .onChange(of: ideas) { _ in relayout(in: geo.size) }
            .onChange(of: ideas.count) { _ in relayout(in: geo.size) } // 数量变化也触发
            .onChange(of: geo.size) { _ in relayout(in: geo.size) }
        }
        .frame(height: 360)
        .padding(.horizontal)
        .contentShape(Rectangle())
        .onLongPressGesture {
            withAnimation(.easeInOut) { isEditing.toggle() }
        }
    }

    private func relayout(in size: CGSize) {
        items = layoutItems(for: ideas, in: size)
    }

    private func layoutItems(for ideas: [Idea], in size: CGSize) -> [BubbleItem] {
        guard size.width > 0, size.height > 0 else { return [] }

        var positions: [CGPoint] = []
        var result: [BubbleItem] = []
        let minDist: CGFloat = 60

        for idea in ideas {
            let p = randomNonOverlapping(in: size, existing: positions, minDist: minDist)
            positions.append(p)

            let font = CGFloat.random(in: 20...34)
            let color = Color(
                hue: .random(in: 0...1),
                saturation: 0.55,
                brightness: 0.95
            )

            result.append(
                BubbleItem(
                    idea: idea,
                    fontSize: font,
                    color: color,
                    position: p
                )
            )
        }
        return result
    }

    private func randomNonOverlapping(in size: CGSize,
                                      existing: [CGPoint],
                                      minDist: CGFloat) -> CGPoint {
        var tries = 0
        var p = CGPoint(x: size.width / 2, y: size.height / 2)

        let minX: CGFloat = 50
        let maxX: CGFloat = max(size.width - 50, minX)
        let minY: CGFloat = 50
        let maxY: CGFloat = max(size.height - 50, minY)

        repeat {
            p = CGPoint(
                x: CGFloat.random(in: minX...maxX),
                y: CGFloat.random(in: minY...maxY)
            )
            tries += 1
        } while existing.contains(where: { hypot($0.x - p.x, $0.y - p.y) < minDist }) && tries < 100

        return p
    }
}

private struct BubbleItemView: View {
    let item: BubbleItem
    @Binding var isEditing: Bool
    var onDelete: (Idea) -> Void

    var body: some View {
        HStack(spacing: 6) {
            if isEditing {
                Button { onDelete(item.idea) } label: {
                    Image(systemName: "minus.circle.fill")
                        .foregroundStyle(.red)
                }
            }

            Text(item.idea.content)
                .font(.system(size: item.fontSize, weight: .semibold))
                .foregroundStyle(item.color)
                .wobble()
        }
        .padding(8)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(.thinMaterial)
        )
        .shadow(radius: 2, y: 1)
        .position(item.position)
        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: isEditing)
    }
}

struct WobbleEffect: ViewModifier {
    @State private var phase: CGFloat = .random(in: 0...1)

    func body(content: Content) -> some View {
        content
            .offset(
                x: sin(phase * .pi * 2) * 6,
                y: cos(phase * .pi * 2) * 5
            )
            .opacity(0.97)
            .onAppear {
                withAnimation(
                    .easeInOut(duration: Double.random(in: 4.8...6.6))
                    .repeatForever(autoreverses: true)
                ) {
                    phase = 1
                }
            }
    }
}

extension View {
    func wobble() -> some View { modifier(WobbleEffect()) }
}
