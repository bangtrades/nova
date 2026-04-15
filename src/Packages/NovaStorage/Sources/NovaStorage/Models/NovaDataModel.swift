import Foundation
import CoreData

/// Programmatic Core Data model definition for Nova app.
///
/// This creates a complete Core Data model without requiring an .xcdatamodeld file.
/// All entities, attributes, and relationships are defined in code, making the model
/// portable and version-controllable.
public class NovaDataModel {
  /// Shared singleton instance for the Core Data model.
  public static let shared: NSManagedObjectModel = {
    let model = NSManagedObjectModel()

    // MARK: - Create Entities (attributes only first)

    let lessonEntity = NSEntityDescription()
    lessonEntity.name = "CDLesson"
    lessonEntity.managedObjectClassName = "CDLesson"

    let cardEntity = NSEntityDescription()
    cardEntity.name = "CDCard"
    cardEntity.managedObjectClassName = "CDCard"

    let childProfileEntity = NSEntityDescription()
    childProfileEntity.name = "CDChildProfile"
    childProfileEntity.managedObjectClassName = "CDChildProfile"

    let learningPathEntity = NSEntityDescription()
    learningPathEntity.name = "CDLearningPath"
    learningPathEntity.managedObjectClassName = "CDLearningPath"

    let progressEntity = NSEntityDescription()
    progressEntity.name = "CDProgress"
    progressEntity.managedObjectClassName = "CDProgress"

    let learningSessionEntity = NSEntityDescription()
    learningSessionEntity.name = "CDLearningSession"
    learningSessionEntity.managedObjectClassName = "CDLearningSession"

    let badgeEntity = NSEntityDescription()
    badgeEntity.name = "CDBadge"
    badgeEntity.managedObjectClassName = "CDBadge"

    let earnedBadgeEntity = NSEntityDescription()
    earnedBadgeEntity.name = "CDEarnedBadge"
    earnedBadgeEntity.managedObjectClassName = "CDEarnedBadge"

    // MARK: - CDLesson Attributes

    let lessonAttrs: [NSAttributeDescription] = [
      attr("id", .stringAttributeType, optional: false),
      attr("title", .stringAttributeType, optional: false),
      attr("lessonDescription", .stringAttributeType, optional: true),
      attr("thumbnailUrl", .stringAttributeType, optional: true),
      attr("difficulty", .integer16AttributeType, optional: false, defaultValue: 1),
      attr("status", .stringAttributeType, optional: false, defaultValue: "draft"),
      attr("sortOrder", .integer32AttributeType, optional: false, defaultValue: 0),
      attr("sourceUrl", .stringAttributeType, optional: true),
      attr("createdAt", .dateAttributeType, optional: false),
      attr("publishedAt", .dateAttributeType, optional: true),
      attr("pathId", .stringAttributeType, optional: true),
      attr("userId", .stringAttributeType, optional: false),
    ]

    // MARK: - CDCard Attributes

    let cardAttrs: [NSAttributeDescription] = [
      attr("id", .stringAttributeType, optional: false),
      attr("lessonId", .stringAttributeType, optional: false),
      attr("type", .stringAttributeType, optional: false),
      attr("content", .binaryDataAttributeType, optional: false),
      attr("voiceScript", .stringAttributeType, optional: true),
      attr("imageUrl", .stringAttributeType, optional: true),
      attr("audioUrl", .stringAttributeType, optional: true),
      attr("interactionConfig", .binaryDataAttributeType, optional: true),
      attr("sortOrder", .integer32AttributeType, optional: false, defaultValue: 0),
      attr("createdAt", .dateAttributeType, optional: false),
    ]

    // MARK: - CDChildProfile Attributes

    let childProfileAttrs: [NSAttributeDescription] = [
      attr("id", .stringAttributeType, optional: false),
      attr("userId", .stringAttributeType, optional: false),
      attr("name", .stringAttributeType, optional: false),
      attr("birthDate", .dateAttributeType, optional: false),
      attr("currentStage", .integer16AttributeType, optional: false, defaultValue: 1),
      attr("avatarUrl", .stringAttributeType, optional: true),
      attr("createdAt", .dateAttributeType, optional: false),
      attr("updatedAt", .dateAttributeType, optional: false),
    ]

    // MARK: - CDLearningPath Attributes

    let learningPathAttrs: [NSAttributeDescription] = [
      attr("id", .stringAttributeType, optional: false),
      attr("userId", .stringAttributeType, optional: false),
      attr("title", .stringAttributeType, optional: false),
      attr("pathDescription", .stringAttributeType, optional: true),
      attr("color", .stringAttributeType, optional: true),
      attr("icon", .stringAttributeType, optional: true),
      attr("sortOrder", .integer32AttributeType, optional: false, defaultValue: 0),
      attr("stage", .integer16AttributeType, optional: false, defaultValue: 1),
      attr("isPremium", .booleanAttributeType, optional: false, defaultValue: false),
      attr("createdAt", .dateAttributeType, optional: false),
      attr("updatedAt", .dateAttributeType, optional: false),
    ]

    // MARK: - CDProgress Attributes

    let progressAttrs: [NSAttributeDescription] = [
      attr("id", .stringAttributeType, optional: false),
      attr("sessionId", .stringAttributeType, optional: false),
      attr("cardId", .stringAttributeType, optional: false),
      attr("action", .stringAttributeType, optional: false),
      attr("durationMs", .integer32AttributeType, optional: false, defaultValue: 0),
      attr("voiceTranscript", .stringAttributeType, optional: true),
      attr("result", .binaryDataAttributeType, optional: true),
      attr("timestamp", .dateAttributeType, optional: false),
    ]

    // MARK: - CDLearningSession Attributes

    let learningSessionAttrs: [NSAttributeDescription] = [
      attr("id", .stringAttributeType, optional: false),
      attr("childId", .stringAttributeType, optional: false),
      attr("deviceId", .stringAttributeType, optional: true),
      attr("startedAt", .dateAttributeType, optional: false),
      attr("endedAt", .dateAttributeType, optional: true),
    ]

    // MARK: - CDBadge Attributes

    let badgeAttrs: [NSAttributeDescription] = [
      attr("id", .stringAttributeType, optional: false),
      attr("title", .stringAttributeType, optional: false),
      attr("badgeDescription", .stringAttributeType, optional: true),
      attr("icon", .stringAttributeType, optional: true),
      attr("criteria", .binaryDataAttributeType, optional: false),
      attr("createdAt", .dateAttributeType, optional: false),
    ]

    // MARK: - CDEarnedBadge Attributes

    let earnedBadgeAttrs: [NSAttributeDescription] = [
      attr("id", .stringAttributeType, optional: false),
      attr("childId", .stringAttributeType, optional: false),
      attr("badgeId", .stringAttributeType, optional: false),
      attr("earnedAt", .dateAttributeType, optional: false),
    ]

    // MARK: - Relationships

    // Lesson <-> Card (one-to-many)
    let lessonCards = rel("cards", dest: cardEntity, toMany: true)
    let cardLesson = rel("lesson", dest: lessonEntity, toMany: false, deleteRule: .cascadeDeleteRule)
    lessonCards.inverseRelationship = cardLesson
    cardLesson.inverseRelationship = lessonCards

    // LearningPath <-> Lesson (one-to-many)
    let pathLessons = rel("lessons", dest: lessonEntity, toMany: true)
    let lessonPath = rel("path", dest: learningPathEntity, toMany: false)
    pathLessons.inverseRelationship = lessonPath
    lessonPath.inverseRelationship = pathLessons

    // ChildProfile <-> LearningSession (one-to-many)
    let childSessions = rel("learningSessions", dest: learningSessionEntity, toMany: true)
    let sessionChild = rel("child", dest: childProfileEntity, toMany: false, deleteRule: .cascadeDeleteRule)
    childSessions.inverseRelationship = sessionChild
    sessionChild.inverseRelationship = childSessions

    // LearningSession <-> Progress (one-to-many)
    let sessionProgress = rel("progress", dest: progressEntity, toMany: true)
    let progressSession = rel("session", dest: learningSessionEntity, toMany: false)
    sessionProgress.inverseRelationship = progressSession
    progressSession.inverseRelationship = sessionProgress

    // ChildProfile <-> EarnedBadge (one-to-many)
    let childEarnedBadges = rel("earnedBadges", dest: earnedBadgeEntity, toMany: true)
    let earnedBadgeChild = rel("child", dest: childProfileEntity, toMany: false, deleteRule: .cascadeDeleteRule)
    childEarnedBadges.inverseRelationship = earnedBadgeChild
    earnedBadgeChild.inverseRelationship = childEarnedBadges

    // Badge <-> EarnedBadge (one-to-many)
    let badgeEarnedBadges = rel("earnedBadges", dest: earnedBadgeEntity, toMany: true)
    let earnedBadgeBadge = rel("badge", dest: badgeEntity, toMany: false, deleteRule: .cascadeDeleteRule)
    badgeEarnedBadges.inverseRelationship = earnedBadgeBadge
    earnedBadgeBadge.inverseRelationship = badgeEarnedBadges

    // MARK: - Assign properties to entities

    lessonEntity.properties = lessonAttrs + [lessonCards, lessonPath]
    cardEntity.properties = cardAttrs + [cardLesson]
    childProfileEntity.properties = childProfileAttrs + [childSessions, childEarnedBadges]
    learningPathEntity.properties = learningPathAttrs + [pathLessons]
    progressEntity.properties = progressAttrs + [progressSession]
    learningSessionEntity.properties = learningSessionAttrs + [sessionChild, sessionProgress]
    badgeEntity.properties = badgeAttrs + [badgeEarnedBadges]
    earnedBadgeEntity.properties = earnedBadgeAttrs + [earnedBadgeChild, earnedBadgeBadge]

    model.entities = [
      lessonEntity,
      cardEntity,
      childProfileEntity,
      learningPathEntity,
      progressEntity,
      learningSessionEntity,
      badgeEntity,
      earnedBadgeEntity,
    ]

    return model
  }()

  // MARK: - Helper Methods

  /// Creates an attribute description.
  private static func attr(
    _ name: String,
    _ type: NSAttributeType,
    optional: Bool = true,
    defaultValue: Any? = nil
  ) -> NSAttributeDescription {
    let a = NSAttributeDescription()
    a.name = name
    a.attributeType = type
    a.isOptional = optional
    a.defaultValue = defaultValue
    return a
  }

  /// Creates a relationship description.
  private static func rel(
    _ name: String,
    dest: NSEntityDescription,
    toMany: Bool,
    deleteRule: NSDeleteRule = .nullifyDeleteRule
  ) -> NSRelationshipDescription {
    let r = NSRelationshipDescription()
    r.name = name
    r.destinationEntity = dest
    r.maxCount = toMany ? 0 : 1
    r.minCount = 0
    r.deleteRule = deleteRule
    r.isOptional = true
    return r
  }
}

// MARK: - JSON Value Transformer

/// Custom transformer for storing Codable objects as JSON in Core Data.
@objc(JSONValueTransformer)
public class JSONValueTransformer: NSSecureUnarchiveFromDataTransformer {
  public override static var allowedTopLevelClasses: [AnyClass] {
    return [NSString.self, NSNumber.self, NSArray.self, NSDictionary.self, NSData.self]
  }

  public override func transformedValue(_ value: Any?) -> Any? {
    guard let value = value else { return nil }
    if let data = value as? Data { return data }
    if JSONSerialization.isValidJSONObject(value) {
      do {
        return try JSONSerialization.data(withJSONObject: value, options: [.sortedKeys])
      } catch {
        print("Error encoding JSON: \(error)")
        return nil
      }
    }
    return nil
  }

  public override func reverseTransformedValue(_ value: Any?) -> Any? {
    guard let data = value as? Data else { return nil }
    do {
      return try JSONSerialization.jsonObject(with: data, options: [.fragmentsAllowed])
    } catch {
      print("Error decoding JSON: \(error)")
      return nil
    }
  }

  public static func register() {
    ValueTransformer.setValueTransformer(
      JSONValueTransformer(),
      forName: NSValueTransformerName("JSONValueTransformer")
    )
  }
}
