import Foundation

@MainActor
class RunClubService: ObservableObject {
    static let shared = RunClubService()

    @Published var clubs: [RunClub] = []
    @Published var selectedClub: RunClub?
    @Published var errorMessage: String? = nil
    @Published var clubMessages: [String: [RunClubMessage]] = [:]

    private let defaults = UserDefaults.standard
    private let clubKey = "run_clubs_v2"

    private init() {
        loadClubs()
    }

    func createClub(name: String, description: String?, city: String?, ownerId: String, ownerName: String) -> RunClub {
        let club = RunClub(
            name: name,
            description: description,
            city: city,
            ownerId: ownerId,
            ownerName: ownerName,
            members: [RunClubMember(userId: ownerId, username: ownerName)]
        )
        clubs.insert(club, at: 0)
        saveClubs()
        return club
    }

    func joinClub(_ clubId: String, userId: String, username: String) {
        guard let index = clubs.firstIndex(where: { $0.id == clubId }) else { return }
        if clubs[index].members.contains(where: { $0.userId == userId }) { return }

        clubs[index].members.append(RunClubMember(userId: userId, username: username))
        saveClubs()
    }

    func leaveClub(_ clubId: String, userId: String) {
        guard let index = clubs.firstIndex(where: { $0.id == clubId }) else { return }
        clubs[index].members.removeAll(where: { $0.userId == userId })
        saveClubs()
    }

    func addEvent(to clubId: String, title: String, details: String?, location: String?, date: Date, createdBy: String) {
        guard let index = clubs.firstIndex(where: { $0.id == clubId }) else { return }
        let event = RunClubEvent(clubId: clubId, title: title, details: details, location: location, date: date, createdBy: createdBy)
        clubs[index].events.insert(event, at: 0)
        saveClubs()
    }

    func getClubs(city: String? = nil) -> [RunClub] {
        guard let city = city, !city.isEmpty else { return clubs }
        return clubs.filter { $0.city?.lowercased() == city.lowercased() }
    }

    func postMessage(clubId: String, senderId: String, senderName: String, message: String) {
        let msg = RunClubMessage(clubId: clubId, senderId: senderId, senderName: senderName, message: message)
        clubMessages[clubId, default: []].insert(msg, at: 0)
    }

    func getMessages(clubId: String) -> [RunClubMessage] {
        clubMessages[clubId] ?? []
    }

    func getClubLeaderboard(clubId: String) -> [(RunClubMember, Int)] {
        guard let club = clubs.first(where: { $0.id == clubId }) else { return [] }

        // Score is (events + members joined)
        var memberScore = [String: Int]()
	for m in club.members {
            memberScore[m.userId] = (memberScore[m.userId] ?? 0) + 1
        }

        for event in club.events {
            guard let userId = club.members.first(where: { $0.username == event.createdBy })?.userId else { continue }
            memberScore[userId, default: 0] += 2
        }

        return club.members
            .map { ($0, memberScore[$0.userId] ?? 0) }
            .sorted { $0.1 > $1.1 }
    }

    private func saveClubs() {
        if let data = try? JSONEncoder().encode(clubs) {
            defaults.set(data, forKey: clubKey)
        }
    }

    private func loadClubs() {
        if let data = defaults.data(forKey: clubKey), let saved = try? JSONDecoder().decode([RunClub].self, from: data) {
            clubs = saved
        }
    }
}
