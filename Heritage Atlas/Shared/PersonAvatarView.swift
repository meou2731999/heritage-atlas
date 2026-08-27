import HeritageAtlasCore
import SwiftUI
import UIKit

struct PersonAvatarView: View {
    let name: String
    let gender: Gender
    var photoMediaID: UUID?
    var size: CGFloat = 44

    @Environment(FamilySession.self) private var session
    @State private var imageData: Data?

    private var initials: String { PersonName.initials(from: name) }

    var body: some View {
        Group {
            if let imageData, let image = UIImage(data: imageData) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            } else {
                ZStack {
                    gender.avatarTint
                    Text(initials)
                        .font(.system(size: size * 0.34, weight: .semibold, design: .rounded))
                        .foregroundStyle(.white)
                }
            }
        }
        .frame(width: size, height: size)
        .clipShape(Circle())
        .overlay {
            Circle().strokeBorder(.black.opacity(0.06), lineWidth: 1)
        }
        .task(id: photoMediaID) {
            guard let photoMediaID else {
                imageData = nil
                return
            }
            imageData = await session.photoData(for: photoMediaID)
        }
    }
}

extension PersonAvatarView {
    init(person: Person, size: CGFloat = 44) {
        self.init(
            name: person.displayName,
            gender: person.gender,
            photoMediaID: person.photoMediaID,
            size: size
        )
    }

    init(node: PersonNode, photoMediaID: UUID? = nil, size: CGFloat = 44) {
        self.init(
            name: node.displayName,
            gender: node.gender,
            photoMediaID: photoMediaID,
            size: size
        )
    }
}
