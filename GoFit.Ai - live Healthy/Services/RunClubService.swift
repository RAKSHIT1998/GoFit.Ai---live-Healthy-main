import Foundation

@MainActor
class RunClubService: ObservableObject {
    static let shared = RunClubService()

    @Published var clubs: [RunClub] = []
    @Published var selectedClub: RunClub?
    @Published var errorMessage: String? = nil

    private let defaults = UserDefaults.standard
    private let clubKey = "run_clubs_v2"

    private init() {
        loadClubs()
    }

    func createClub(name: String, description: String?, city: String?, ownerId: String, ownerName: String) -> RunClub {
        var club = RunClub(
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
