import HeritageAtlasCore
import SwiftUI

struct FamilyTreeCanvasView: View {
    let layout: TreeLayout
    let focusID: UUID
    let photoIDs: [UUID: UUID]
    var onFocus: (UUID) -> Void
    var onOpenProfile: (UUID) -> Void
    var onToggleCollapse: (UUID) -> Void

    @State private var scale: CGFloat = 1
    @State private var pan: CGSize = .zero
    @GestureState private var pinch: CGFloat = 1
    @GestureState private var drag: CGSize = .zero

    private var liveScale: CGFloat {
        min(max(scale * pinch, 0.32), 2.6)
    }

    private var livePan: CGSize {
        CGSize(width: pan.width + drag.width, height: pan.height + drag.height)
    }

    var body: some View {
        GeometryReader { geo in
            let focusPoint = layout.nodes[focusID]?.center ?? CGPoint(x: layout.bounds.midX, y: layout.bounds.midY)
            ZStack {
                Color(.systemGroupedBackground)
                Canvas { context, size in
                    drawEdges(
                        context: context,
                        size: size,
                        focusPoint: focusPoint
                    )
                }
                ForEach(layout.nodeList) { node in
                    let point = viewPoint(node.center, in: geo.size, focus: focusPoint)
                    PersonTreeCard(
                        node: node,
                        photoMediaID: photoIDs[node.id],
                        scale: liveScale
                    ) {
                        onFocus(node.id)
                    } onOpenProfile: {
                        onOpenProfile(node.id)
                    } onToggleCollapse: {
                        onToggleCollapse(node.id)
                    }
                    .position(point)
                }
            }
            .contentShape(Rectangle())
            .gesture(dragGesture)
            .simultaneousGesture(magnifyGesture)
            .onTapGesture(count: 2) {
                resetCamera()
            }
            .onChange(of: focusID) { _, _ in
                withAnimation(.easeInOut(duration: 0.25)) {
                    pan = .zero
                }
            }
            .clipped()
        }
    }

    private func resetCamera() {
        withAnimation(.easeInOut(duration: 0.2)) {
            scale = 1
            pan = .zero
        }
    }

    private var dragGesture: some Gesture {
        DragGesture()
            .updating($drag) { value, state, _ in
                state = value.translation
            }
            .onEnded { value in
                pan = CGSize(
                    width: pan.width + value.translation.width,
                    height: pan.height + value.translation.height
                )
            }
    }

    private var magnifyGesture: some Gesture {
        MagnifyGesture()
            .updating($pinch) { value, state, _ in
                state = value.magnification
            }
            .onEnded { value in
                scale = min(max(scale * value.magnification, 0.32), 2.6)
            }
    }

    private func viewPoint(_ treePoint: CGPoint, in size: CGSize, focus: CGPoint) -> CGPoint {
        CGPoint(
            x: size.width / 2 + (treePoint.x - focus.x) * liveScale + livePan.width,
            y: size.height / 2 + (treePoint.y - focus.y) * liveScale + livePan.height
        )
    }

    private func drawEdges(context: GraphicsContext, size: CGSize, focusPoint: CGPoint) {
        let card = TreeLayoutEngine.cardSize
        let halfH = card.height / 2 * liveScale
        let halfW = card.width / 2 * liveScale

        for edge in layout.edges {
            guard let from = layout.nodes[edge.from], let to = layout.nodes[edge.to] else { continue }
            let start = viewPoint(from.center, in: size, focus: focusPoint)
            let end = viewPoint(to.center, in: size, focus: focusPoint)
            var path = Path()
            let dashed = edge.hop == .adoptedChild || edge.hop == .stepChild
                || edge.hop == .adoptiveParent || edge.hop == .stepParent
            let color = Color.secondary.opacity(0.72)

            if edge.hop == .spouse || edge.hop == .partner {
                let left = start.x <= end.x ? start : end
                let right = start.x <= end.x ? end : start
                path.move(to: CGPoint(x: left.x + halfW, y: left.y))
                path.addLine(to: CGPoint(x: right.x - halfW, y: right.y))
            } else {
                let top = start.y <= end.y ? start : end
                let bottom = start.y <= end.y ? end : start
                let fromBottom = CGPoint(x: top.x, y: top.y + halfH)
                let toTop = CGPoint(x: bottom.x, y: bottom.y - halfH)
                let midY = (fromBottom.y + toTop.y) / 2
                path.move(to: fromBottom)
                path.addLine(to: CGPoint(x: fromBottom.x, y: midY))
                path.addLine(to: CGPoint(x: toTop.x, y: midY))
                path.addLine(to: toTop)
            }

            var stroke = StrokeStyle(lineWidth: max(1, 1.4 * liveScale), lineCap: .round, lineJoin: .round)
            if dashed {
                stroke.dash = [6 * liveScale, 4 * liveScale]
            }
            if edge.hop == .partner {
                stroke.dash = [3 * liveScale, 4 * liveScale]
            }
            context.stroke(path, with: .color(color), style: stroke)
        }
    }
}

private struct PersonTreeCard: View {
    let node: TreeNodeFrame
    var photoMediaID: UUID?
    var scale: CGFloat
    var onFocus: () -> Void
    var onOpenProfile: () -> Void
    var onToggleCollapse: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            Button(action: onFocus) {
                HStack(spacing: 8) {
                    PersonAvatarView(node: node.person, photoMediaID: photoMediaID, size: 36)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(node.person.displayName)
                            .font(.caption.weight(.semibold))
                            .lineLimit(2)
                            .multilineTextAlignment(.leading)
                        let years = PersonLifeSpan.format(birth: node.person.birthDate, death: node.person.deathDate)
                        if !years.isEmpty {
                            Text(years)
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                    Spacer(minLength: 0)
                    Button(action: onOpenProfile) {
                        Image(systemName: "info.circle")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 8)
            }
            .buttonStyle(.plain)

            if node.canCollapse {
                Button(action: onToggleCollapse) {
                    Image(systemName: node.isCollapsed ? "chevron.down.circle.fill" : "chevron.up.circle")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .padding(.bottom, 6)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(node.isCollapsed ? LocalizedStringKey("Expand branch") : LocalizedStringKey("Collapse branch"))
            }
        }
        .frame(width: TreeLayoutEngine.cardSize.width, height: TreeLayoutEngine.cardSize.height)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color(.secondarySystemGroupedBackground))
        )
        .overlay {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(node.isFocus ? Color.accentColor : Color.primary.opacity(0.06), lineWidth: node.isFocus ? 2 : 1)
        }
        .shadow(color: .black.opacity(0.06), radius: 6, y: 2)
        .scaleEffect(scale)
    }
}
