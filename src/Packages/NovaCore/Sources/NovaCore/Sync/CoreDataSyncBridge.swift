import Foundation
import CoreData

/// Bridge between API responses and Core Data storage.
///
/// Provides thread-safe methods for upserting lessons, cards, learning paths,
/// and progress records into Core Data.
public class CoreDataSyncBridge {
    /// Shared singleton instance.
    public static let shared = CoreDataSyncBridge()

    private init() {}

    // MARK: - Lesson Operations

    /// Saves or updates lessons in Core Data.
    ///
    /// Performs an upsert operation: inserts new lessons or updates existing ones.
    ///
    /// - Parameters:
    ///   - lessons: Array of lessons to save.
    ///   - context: NSManagedObjectContext to use (thread-safe).
    public func saveLessons(
        _ lessons: [Lesson],
        context: NSManagedObjectContext
    ) throws {
        context.perform {
            for lesson in lessons {
                let fetchRequest = NSFetchRequest<NSFetchRequestResult>(entityName: "CDLesson")
                fetchRequest.predicate = NSPredicate(format: "id == %@", lesson.id.uuidString)

                do {
                    let results = try context.fetch(fetchRequest)

                    if let existingLesson = results.first as? NSManagedObject {
                        // Update existing lesson
                        existingLesson.setValue(lesson.title, forKey: "title")
                        existingLesson.setValue(lesson.description, forKey: "description")
                        existingLesson.setValue(lesson.difficulty, forKey: "difficulty")
                        existingLesson.setValue(lesson.status.rawValue, forKey: "status")
                        existingLesson.setValue(lesson.sortOrder, forKey: "sortOrder")
                        existingLesson.setValue(lesson.publishedAt, forKey: "publishedAt")
                    } else {
                        // Create new lesson
                        let newLesson = NSEntityDescription.insertNewObject(
                            forEntityName: "CDLesson",
                            into: context
                        )
                        newLesson.setValue(lesson.id.uuidString, forKey: "id")
                        newLesson.setValue(lesson.pathId?.uuidString, forKey: "pathId")
                        newLesson.setValue(lesson.userId.uuidString, forKey: "userId")
                        newLesson.setValue(lesson.title, forKey: "title")
                        newLesson.setValue(lesson.description, forKey: "description")
                        newLesson.setValue(lesson.difficulty, forKey: "difficulty")
                        newLesson.setValue(lesson.status.rawValue, forKey: "status")
                        newLesson.setValue(lesson.sortOrder, forKey: "sortOrder")
                        newLesson.setValue(lesson.createdAt, forKey: "createdAt")
                        newLesson.setValue(lesson.publishedAt, forKey: "publishedAt")
                    }
                } catch {
                    print("Error upserting lesson \(lesson.id): \(error)")
                }
            }

            do {
                try context.save()
            } catch {
                print("Error saving lessons context: \(error)")
            }
        }
    }

    // MARK: - Card Operations

    /// Saves or updates cards for a lesson in Core Data.
    ///
    /// - Parameters:
    ///   - cards: Array of cards to save.
    ///   - lessonId: The lesson ID these cards belong to.
    ///   - context: NSManagedObjectContext to use.
    public func saveCards(
        _ cards: [Card],
        forLesson lessonId: UUID,
        context: NSManagedObjectContext
    ) throws {
        context.perform {
            for card in cards {
                let fetchRequest = NSFetchRequest<NSFetchRequestResult>(entityName: "CDCard")
                fetchRequest.predicate = NSPredicate(format: "id == %@", card.id.uuidString)

                do {
                    let results = try context.fetch(fetchRequest)

                    if let existingCard = results.first as? NSManagedObject {
                        // Update existing card
                        existingCard.setValue(card.type.rawValue, forKey: "type")
                        existingCard.setValue(card.sortOrder, forKey: "sortOrder")
                        existingCard.setValue(card.voiceScript, forKey: "voiceScript")
                    } else {
                        // Create new card
                        let newCard = NSEntityDescription.insertNewObject(
                            forEntityName: "CDCard",
                            into: context
                        )
                        newCard.setValue(card.id.uuidString, forKey: "id")
                        newCard.setValue(lessonId.uuidString, forKey: "lessonId")
                        newCard.setValue(card.type.rawValue, forKey: "type")
                        newCard.setValue(card.sortOrder, forKey: "sortOrder")
                        newCard.setValue(card.voiceScript, forKey: "voiceScript")
                        newCard.setValue(card.createdAt, forKey: "createdAt")

                        // Save content as JSON
                        if let contentData = try? JSONEncoder().encode(card.content) {
                            newCard.setValue(contentData, forKey: "content")
                        }
                    }
                } catch {
                    print("Error upserting card \(card.id): \(error)")
                }
            }

            do {
                try context.save()
            } catch {
                print("Error saving cards context: \(error)")
            }
        }
    }

    // MARK: - Learning Path Operations

    /// Saves or updates learning paths in Core Data.
    ///
    /// - Parameters:
    ///   - paths: Array of learning paths to save.
    ///   - context: NSManagedObjectContext to use.
    public func saveLearningPaths(
        _ paths: [LearningPath],
        context: NSManagedObjectContext
    ) throws {
        context.perform {
            for path in paths {
                let fetchRequest = NSFetchRequest<NSFetchRequestResult>(entityName: "CDLearningPath")
                fetchRequest.predicate = NSPredicate(format: "id == %@", path.id.uuidString)

                do {
                    let results = try context.fetch(fetchRequest)

                    if let existingPath = results.first as? NSManagedObject {
                        // Update existing path
                        existingPath.setValue(path.title, forKey: "title")
                        existingPath.setValue(path.description, forKey: "description")
                        existingPath.setValue(path.sortOrder, forKey: "sortOrder")
                        existingPath.setValue(path.updatedAt, forKey: "updatedAt")
                    } else {
                        // Create new path
                        let newPath = NSEntityDescription.insertNewObject(
                            forEntityName: "CDLearningPath",
                            into: context
                        )
                        newPath.setValue(path.id.uuidString, forKey: "id")
                        newPath.setValue(path.userId.uuidString, forKey: "userId")
                        newPath.setValue(path.title, forKey: "title")
                        newPath.setValue(path.description, forKey: "description")
                        newPath.setValue(path.sortOrder, forKey: "sortOrder")
                        newPath.setValue(path.createdAt, forKey: "createdAt")
                        newPath.setValue(path.updatedAt, forKey: "updatedAt")
                    }
                } catch {
                    print("Error upserting learning path \(path.id): \(error)")
                }
            }

            do {
                try context.save()
            } catch {
                print("Error saving learning paths context: \(error)")
            }
        }
    }

    // MARK: - Progress Operations

    /// Fetches unsynced progress records from Core Data.
    ///
    /// - Parameters:
    ///   - context: NSManagedObjectContext to use.
    /// - Returns: Array of unsynced progress records.
    public func fetchPendingProgress(context: NSManagedObjectContext) -> [Progress] {
        var pendingProgress: [Progress] = []

        context.performAndWait {
            let fetchRequest = NSFetchRequest<NSFetchRequestResult>(entityName: "CDProgress")
            // Predicate for unsynced records would go here (e.g., synced == false)
            // For now, fetch all progress records

            do {
                if let results = try context.fetch(fetchRequest) as? [NSManagedObject] {
                    for result in results {
                        if let id = result.value(forKey: "id") as? String,
                           let cardId = result.value(forKey: "cardId") as? String,
                           let sessionId = result.value(forKey: "sessionId") as? String,
                           let action = result.value(forKey: "action") as? String,
                           let timestamp = result.value(forKey: "timestamp") as? Date {
                            let durationMs = result.value(forKey: "durationMs") as? Int32 ?? 0
                            let voiceTranscript = result.value(forKey: "voiceTranscript") as? String

                            let progress = Progress(
                                id: UUID(uuidString: id) ?? UUID(),
                                sessionId: UUID(uuidString: sessionId) ?? UUID(),
                                cardId: UUID(uuidString: cardId) ?? UUID(),
                                action: action,
                                durationMs: Int(durationMs),
                                voiceTranscript: voiceTranscript,
                                timestamp: timestamp
                            )
                            pendingProgress.append(progress)
                        }
                    }
                }
            } catch {
                print("Error fetching pending progress: \(error)")
            }
        }

        return pendingProgress
    }

    /// Marks progress records as synced.
    ///
    /// - Parameters:
    ///   - ids: Array of progress record IDs to mark as synced.
    ///   - context: NSManagedObjectContext to use.
    public func markProgressSynced(_ ids: [String], context: NSManagedObjectContext) throws {
        context.perform {
            for id in ids {
                let fetchRequest = NSFetchRequest<NSFetchRequestResult>(entityName: "CDProgress")
                fetchRequest.predicate = NSPredicate(format: "id == %@", id)

                do {
                    let results = try context.fetch(fetchRequest)

                    if let existingProgress = results.first as? NSManagedObject {
                        existingProgress.setValue(true, forKey: "synced")
                    }
                } catch {
                    print("Error marking progress as synced: \(error)")
                }
            }

            do {
                try context.save()
            } catch {
                print("Error saving synced progress: \(error)")
            }
        }
    }
}

// MARK: - Helper Models

/// Represents a progress record for syncing.
public struct Progress {
    public let id: UUID
    public let sessionId: UUID
    public let cardId: UUID
    public let action: String
    public let durationMs: Int
    public let voiceTranscript: String?
    public let timestamp: Date

    public init(
        id: UUID,
        sessionId: UUID,
        cardId: UUID,
        action: String,
        durationMs: Int,
        voiceTranscript: String?,
        timestamp: Date
    ) {
        self.id = id
        self.sessionId = sessionId
        self.cardId = cardId
        self.action = action
        self.durationMs = durationMs
        self.voiceTranscript = voiceTranscript
        self.timestamp = timestamp
    }
}
