import Foundation
import CoreData

final class RunHistoryStore {
    static let shared = RunHistoryStore()
    private(set) var persistentContainer: NSPersistentCloudKitContainer

    private init() {
        let model = Self.makeManagedObjectModel()

        persistentContainer = NSPersistentCloudKitContainer(name: "RunHistoryContainer", managedObjectModel: model)

        let description = persistentContainer.persistentStoreDescriptions.first ?? NSPersistentStoreDescription()
        description.configuration = nil
        description.cloudKitContainerOptions = NSPersistentCloudKitContainerOptions(containerIdentifier: "iCloud.com.yourcompany.GoFit")
        description.setOption(true as NSNumber, forKey: NSPersistentHistoryTrackingKey)
        description.setOption(true as NSNumber, forKey: NSPersistentStoreRemoteChangeNotificationPostOptionKey)

        persistentContainer.persistentStoreDescriptions = [description]

        persistentContainer.loadPersistentStores { storeDescription, error in
            if let error = error {
                print("⚠️ RunHistoryStore CoreData load failed: \(error)")
            } else {
                print("✅ RunHistoryStore loaded at \(storeDescription.url?.path ?? "unknown")")
            }
        }

        persistentContainer.viewContext.automaticallyMergesChangesFromParent = true
    }

    private static func makeManagedObjectModel() -> NSManagedObjectModel {
        let model = NSManagedObjectModel()
        let runEntity = NSEntityDescription()
        runEntity.name = "RunHistory"
        runEntity.managedObjectClassName = NSStringFromClass(NSManagedObject.self)

        let idAttr = NSAttributeDescription()
        idAttr.name = "id"
        idAttr.attributeType = .stringAttributeType
        idAttr.isOptional = false

        let dateAttr = NSAttributeDescription()
        dateAttr.name = "date"
        dateAttr.attributeType = .dateAttributeType
        dateAttr.isOptional = false

        let distAttr = NSAttributeDescription()
        distAttr.name = "distanceKm"
        distAttr.attributeType = .doubleAttributeType
        distAttr.isOptional = false

        let durationAttr = NSAttributeDescription()
        durationAttr.name = "durationSeconds"
        durationAttr.attributeType = .doubleAttributeType
        durationAttr.isOptional = false

        let caloriesAttr = NSAttributeDescription()
        caloriesAttr.name = "calories"
        caloriesAttr.attributeType = .doubleAttributeType
        caloriesAttr.isOptional = false

        let ascentAttr = NSAttributeDescription()
        ascentAttr.name = "ascentMeters"
        ascentAttr.attributeType = .doubleAttributeType
        ascentAttr.isOptional = false

        let descentAttr = NSAttributeDescription()
        descentAttr.name = "descentMeters"
        descentAttr.attributeType = .doubleAttributeType
        descentAttr.isOptional = false

        let paceAttr = NSAttributeDescription()
        paceAttr.name = "paceMinPerKm"
        paceAttr.attributeType = .doubleAttributeType
        paceAttr.isOptional = false

        let routeAttr = NSAttributeDescription()
        routeAttr.name = "routeData"
        routeAttr.attributeType = .binaryDataAttributeType
        routeAttr.isOptional = true

        runEntity.properties = [idAttr, dateAttr, distAttr, durationAttr, caloriesAttr, ascentAttr, descentAttr, paceAttr, routeAttr]
        model.entities = [runEntity]

        return model
    }

    private var context: NSManagedObjectContext {
        persistentContainer.viewContext
    }

    func fetchRuns(limit: Int? = nil) -> [RunSession] {
        let request = NSFetchRequest<NSManagedObject>(entityName: "RunHistory")
        request.sortDescriptors = [NSSortDescriptor(key: "date", ascending: false)]
        if let limit = limit { request.fetchLimit = limit }

        do {
            let items = try context.fetch(request)
            return items.compactMap { storeObject in
                guard
                    let id = storeObject.value(forKey: "id") as? String,
                    let date = storeObject.value(forKey: "date") as? Date,
                    let distanceKm = storeObject.value(forKey: "distanceKm") as? Double,
                    let durationSeconds = storeObject.value(forKey: "durationSeconds") as? Double,
                    let calories = storeObject.value(forKey: "calories") as? Double,
                    let ascentMeters = storeObject.value(forKey: "ascentMeters") as? Double,
                    let descentMeters = storeObject.value(forKey: "descentMeters") as? Double,
                    let paceMinPerKm = storeObject.value(forKey: "paceMinPerKm") as? Double
                else { return nil }

                var route: [RunPoint] = []
                if
                    let routeData = storeObject.value(forKey: "routeData") as? Data,
                    let decoded = try? JSONDecoder().decode([RunPoint].self, from: routeData)
                {
                    route = decoded
                }

                return RunSession(
                    id: id,
                    date: date,
                    distanceKm: distanceKm,
                    durationSeconds: durationSeconds,
                    calories: calories,
                    ascentMeters: ascentMeters,
                    descentMeters: descentMeters,
                    paceMinPerKm: paceMinPerKm,
                    route: route
                )
            }
        } catch {
            print("⚠️ RunHistoryStore fetch failed: \(error)")
            return []
        }
    }

    func storeRun(_ session: RunSession) {
        let entityName = "RunHistory"
        let runObject = NSEntityDescription.insertNewObject(forEntityName: entityName, into: context)

        runObject.setValue(session.id, forKey: "id")
        runObject.setValue(session.date, forKey: "date")
        runObject.setValue(session.distanceKm, forKey: "distanceKm")
        runObject.setValue(session.durationSeconds, forKey: "durationSeconds")
        runObject.setValue(session.calories, forKey: "calories")
        runObject.setValue(session.ascentMeters, forKey: "ascentMeters")
        runObject.setValue(session.descentMeters, forKey: "descentMeters")
        runObject.setValue(session.paceMinPerKm, forKey: "paceMinPerKm")

        if let routeData = try? JSONEncoder().encode(session.route) {
            runObject.setValue(routeData, forKey: "routeData")
        }

        do {
            try context.save()
            print("✅ RunHistoryStore saved run \(session.id)")
        } catch {
            print("⚠️ RunHistoryStore save error: \(error)")
            // fallback to existing UserDefaults persistence
            let fallbackKey = "run_sessions"
            var existing = runSessionsFromUserDefaults()
            existing.insert(session, at: 0)
            if let data = try? JSONEncoder().encode(existing) {
                UserDefaults.standard.set(data, forKey: fallbackKey)
            }
        }
    }

    private func runSessionsFromUserDefaults() -> [RunSession] {
        guard let data = UserDefaults.standard.data(forKey: "run_sessions"),
              let saved = try? JSONDecoder().decode([RunSession].self, from: data) else {
            return []
        }
        return saved
    }
}
