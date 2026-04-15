import Foundation
import CoreData
import NovaCore

/// Sets up and manages the Core Data stack for Nova.
///
/// This class initializes the NSPersistentContainer and provides access to
/// the main view context and background contexts.
///
/// The Core Data model is defined programmatically in NovaDataModel.swift,
/// eliminating the need for an .xcdatamodeld file while maintaining full
/// type safety and version control.
public class CoreDataStack {
    /// Shared singleton instance.
    public static let shared = CoreDataStack()

    /// The persistent container for the app.
    private let container: NSPersistentContainer

    /// The main view context (UI thread).
    public var viewContext: NSManagedObjectContext {
        container.viewContext
    }

    /// Initialize the Core Data stack.
    ///
    /// This method:
    /// 1. Uses the programmatic Core Data model
    /// 2. Creates the persistent container
    /// 3. Loads the persistent stores
    /// 4. Configures the context settings
    private init() {
        // Register the JSON value transformer
        JSONValueTransformer.register()

        // Use the programmatic Core Data model
        let model = NovaDataModel.shared

        // Create the persistent container
        container = NSPersistentContainer(name: "Nova", managedObjectModel: model)

        // Configure the persistent store description
        if let storeDescription = container.persistentStoreDescriptions.first {
            // Enable automatic lightweight migrations
            storeDescription.shouldMigrateStoreAutomatically = true
            storeDescription.shouldInferMappingModelAutomatically = true
        }

        // Load persistent stores
        container.loadPersistentStores { _, error in
            if let error = error as NSError? {
                fatalError(
                    "Failed to load persistent stores: \(error), \(error.userInfo)"
                )
            }
        }

        // Configure the view context
        viewContext.automaticallyMergesChangesFromParent = true
        viewContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy

        // Enable additional debugging in development
        #if DEBUG
        viewContext.shouldDeleteInaccessibleFaults = true
        #endif
    }

    /// Creates a new background context for off-main-thread operations.
    ///
    /// Use this for background sync operations, imports, etc.
    ///
    /// - Returns: A new NSManagedObjectContext on a private queue.
    public func newBackgroundContext() -> NSManagedObjectContext {
        let context = container.newBackgroundContext()
        context.automaticallyMergesChangesFromParent = true
        context.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
        return context
    }

    /// Saves changes in a managed object context.
    ///
    /// - Parameters:
    ///   - context: The context to save (defaults to viewContext).
    /// - Throws: NSError if the save fails.
    public func save(context: NSManagedObjectContext = CoreDataStack.shared.viewContext) throws {
        if context.hasChanges {
            try context.save()
        }
    }

    /// Deletes all data from all entities (for testing or user request).
    ///
    /// - Throws: NSError if deletion fails.
    public func deleteAllData() throws {
        let context = viewContext

        // Get all entity names from the model
        guard let model = container.managedObjectModel.entities as [NSEntityDescription]? else {
            return
        }

        for entity in model {
            let fetchRequest = NSFetchRequest<NSFetchRequestResult>(entityName: entity.name ?? "")
            let deleteRequest = NSBatchDeleteRequest(fetchRequest: fetchRequest)

            try context.execute(deleteRequest)
        }

        try save(context: context)
    }
}
