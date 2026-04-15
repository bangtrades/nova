import Foundation
import NovaCore

/// ViewModel for child profile management with mock data.
public class ChildProfileViewModel: ObservableObject {
    @Published var childProfiles: [ChildProfile] = []

    public init() {
        loadMockData()
    }

    private func loadMockData() {
        childProfiles = [
            ChildProfile(
                userId: UUID(),
                name: "Explorer",
                birthDate: Calendar.current.date(byAdding: .year, value: -4, to: Date()) ?? Date(),
                currentStage: 1
            ),
            ChildProfile(
                userId: UUID(),
                name: "Maker",
                birthDate: Calendar.current.date(byAdding: .year, value: -7, to: Date()) ?? Date(),
                currentStage: 3
            ),
        ]
    }

    func addChild(_ child: ChildProfile) {
        childProfiles.append(child)
    }

    func updateChild(_ child: ChildProfile) {
        if let index = childProfiles.firstIndex(where: { $0.id == child.id }) {
            childProfiles[index] = child
        }
    }

    func deleteChild(_ child: ChildProfile) {
        childProfiles.removeAll { $0.id == child.id }
    }
}
