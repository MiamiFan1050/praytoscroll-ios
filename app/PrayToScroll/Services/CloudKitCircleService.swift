import CloudKit
import Foundation

/// Prayer Circles on the CloudKit public database (container iCloud.com.amenkeyapp.ios).
///
/// Records (schema in app/CloudKit/schema.ckdb):
/// - `Circle`        recordName `circle-<CODE>`               code, name, createdAt, ownerID
/// - `CircleMember`  recordName `member-<CODE>-<memberID>`    circleCode (queryable), memberID, displayName,
///                                                           emoji, prayersThisWeek, weekKey, streak, hidden, updatedAt
/// - `CircleReport`  (auto id)                                circleCode, memberID, reason, reporterID, createdAt
/// - `CirclePrayerRequest` recordName `request-<CODE>-<uuid>`  circleCode, requestID, memberID, displayName, emoji,
///                                                           topic, note, createdAt
/// - `CirclePrayed`  recordName `prayed-<requestID>-<memberID>` circleCode, requestID, memberID, createdAt
///                   (one per member per request, so the "I prayed 🙏" count can't be inflated)
/// Member ids are random per install, never the Apple ID.
final class CloudKitCircleService: CircleService, @unchecked Sendable {
    private let store: SharedStore
    private let lock = NSLock()
    private var cachedContainer: CKContainer?

    init(store: SharedStore = .shared) {
        self.store = store
    }

    /// Only touch CloudKit once we know an iCloud account exists, so a signed-out device never trips over it.
    private func database() throws -> CKDatabase {
        guard FileManager.default.ubiquityIdentityToken != nil else { throw CircleError.noAccount }
        lock.lock()
        defer { lock.unlock() }
        if let cachedContainer { return cachedContainer.publicCloudDatabase }
        let container = CKContainer(identifier: AppConstants.cloudKitContainer)
        cachedContainer = container
        return container.publicCloudDatabase
    }

    func availability() async -> CircleAvailability {
        guard FileManager.default.ubiquityIdentityToken != nil else { return .noAccount }
        do {
            _ = try database()
            guard let container = cachedContainer else { return .noAccount }
            let status = try await container.accountStatus()
            switch status {
            case .available: return .available
            case .noAccount: return .noAccount
            case .restricted: return .restricted
            case .couldNotDetermine, .temporarilyUnavailable:
                return .unavailable("iCloud is temporarily unavailable. Try again in a moment.")
            @unknown default:
                return .unavailable("iCloud is unavailable right now.")
            }
        } catch {
            return .unavailable(Self.map(error).errorDescription ?? "iCloud is unavailable right now.")
        }
    }

    private var memberID: String { store.circleMemberID }

    private func circleID(_ code: String) -> CKRecord.ID { CKRecord.ID(recordName: "circle-\(code)") }
    private func memberRecordID(_ code: String, _ member: String) -> CKRecord.ID { CKRecord.ID(recordName: "member-\(code)-\(member)") }

    func myCircles() async throws -> [PrayerCircle] {
        let codes = store.circleCodes
        guard !codes.isEmpty else { return [] }
        let db = try database()
        do {
            let results = try await db.records(for: codes.map(circleID))
            var circles: [PrayerCircle] = []
            for code in codes {
                if case .success(let record)? = results[circleID(code)] {
                    circles.append(Self.circle(from: record))
                }
            }
            return circles
        } catch {
            throw Self.map(error)
        }
    }

    func create(name: String, displayName: String, emoji: String) async throws -> PrayerCircle {
        let cleanName = NameFilter.clean(name)
        guard NameFilter.isAllowed(cleanName), NameFilter.isAllowed(displayName) else { throw CircleError.nameNotAllowed }
        let db = try database()
        do {
            var code = CircleCode.generate()
            for _ in 0..<5 {
                let existing = try? await db.record(for: circleID(code))
                if existing == nil { break }
                code = CircleCode.generate()
            }
            let record = CKRecord(recordType: "Circle", recordID: circleID(code))
            record["code"] = code as CKRecordValue
            record["name"] = cleanName as CKRecordValue
            record["createdAt"] = Date() as CKRecordValue
            record["ownerID"] = memberID as CKRecordValue
            let saved = try await db.save(record)
            try await saveMember(code: code, displayName: displayName, emoji: emoji, prayers: 0, streak: 0, hidden: false, in: db)
            addCode(code)
            return Self.circle(from: saved)
        } catch let error as CircleError {
            throw error
        } catch {
            throw Self.map(error)
        }
    }

    func join(code rawCode: String, displayName: String, emoji: String) async throws -> PrayerCircle {
        guard let code = CircleCode.normalize(rawCode) else { throw CircleError.invalidCode }
        guard NameFilter.isAllowed(displayName) else { throw CircleError.nameNotAllowed }
        let db = try database()
        do {
            let record = try await db.record(for: circleID(code))
            try await saveMember(code: code, displayName: displayName, emoji: emoji, prayers: 0, streak: 0, hidden: false, in: db)
            addCode(code)
            return Self.circle(from: record)
        } catch let error as CircleError {
            throw error
        } catch {
            throw Self.map(error)
        }
    }

    func leave(code: String) async throws {
        let db = try database()
        let mine = await myRequestRecordIDs(in: db, code: code)
        do {
            _ = try await db.modifyRecords(saving: [], deleting: [memberRecordID(code, memberID)] + mine,
                                           savePolicy: .allKeys, atomically: false)
        } catch {
            let mapped = Self.map(error)
            if mapped != .notFound { throw mapped }
        }
        store.circleCodes = store.circleCodes.filter { $0 != code }
    }

    func members(code: String) async throws -> [CircleMember] {
        let db = try database()
        let query = CKQuery(recordType: "CircleMember", predicate: NSPredicate(format: "circleCode == %@", code))
        do {
            let (results, _) = try await db.records(matching: query, resultsLimit: 200)
            let me = memberID
            return results.compactMap { _, result in
                guard case .success(let record) = result else { return nil }
                return Self.member(from: record, me: me)
            }
        } catch {
            throw Self.map(error)
        }
    }

    func reportProgress(displayName: String, emoji: String, prayersThisWeek: Int, streak: Int) async throws {
        let codes = store.circleCodes
        guard !codes.isEmpty, FileManager.default.ubiquityIdentityToken != nil else { return }
        let db = try database()
        for code in codes {
            let hidden = (try? await db.record(for: memberRecordID(code, memberID)))?["hidden"] as? Int ?? 0
            try? await saveMember(code: code, displayName: displayName, emoji: emoji, prayers: prayersThisWeek,
                                  streak: streak, hidden: hidden == 1, in: db)
        }
    }

    func setHidden(_ hidden: Bool, code: String) async throws {
        let db = try database()
        do {
            let record = try await db.record(for: memberRecordID(code, memberID))
            record["hidden"] = (hidden ? 1 : 0) as CKRecordValue
            record["updatedAt"] = Date() as CKRecordValue
            _ = try await db.save(record)
        } catch {
            throw Self.map(error)
        }
    }

    func report(memberID reported: String, code: String, reason: String) async throws {
        CircleBlockList.block(reported)
        let db = try database()
        let record = CKRecord(recordType: "CircleReport")
        record["circleCode"] = code as CKRecordValue
        record["memberID"] = reported as CKRecordValue
        record["reason"] = String(reason.prefix(200)) as CKRecordValue
        record["reporterID"] = memberID as CKRecordValue
        record["createdAt"] = Date() as CKRecordValue
        do {
            _ = try await db.save(record)
        } catch {
            throw Self.map(error)
        }
    }

    func deleteMyData(codes: [String]) async throws {
        guard !codes.isEmpty, FileManager.default.ubiquityIdentityToken != nil else { return }
        let db = try database()
        var toDelete = codes.map { memberRecordID($0, memberID) }
        toDelete += await myRequestRecordIDs(in: db)
        // Circles I created go too (other members' rows remain theirs to delete).
        if let results = try? await db.records(for: codes.map(circleID)) {
            for (id, result) in results {
                if case .success(let record) = result, record["ownerID"] as? String == memberID { toDelete.append(id) }
            }
        }
        do {
            _ = try await db.modifyRecords(saving: [], deleting: toDelete, savePolicy: .allKeys, atomically: false)
        } catch {
            let mapped = Self.map(error)
            if mapped != .notFound { throw mapped }
        }
        store.circleCodes = []
    }

    // MARK: Prayer requests

    private func prayedRecordID(_ requestID: String, _ member: String) -> CKRecord.ID {
        CKRecord.ID(recordName: "prayed-\(requestID)-\(member)")
    }

    func requests(code: String) async throws -> [CirclePrayerRequest] {
        let db = try database()
        let since = Date().addingTimeInterval(-CirclePrayerRequest.lifetime) as NSDate
        let me = memberID
        do {
            let requestQuery = CKQuery(recordType: "CirclePrayerRequest",
                                       predicate: NSPredicate(format: "circleCode == %@ AND createdAt > %@", code, since))
            requestQuery.sortDescriptors = [NSSortDescriptor(key: "createdAt", ascending: false)]
            let (requestResults, _) = try await db.records(matching: requestQuery, resultsLimit: 100)
            let prayedQuery = CKQuery(recordType: "CirclePrayed",
                                      predicate: NSPredicate(format: "circleCode == %@ AND createdAt > %@", code, since))
            let (prayedResults, _) = try await db.records(matching: prayedQuery, resultsLimit: 400)
            // One count per iCloud account per request (not per member id), so reinstalls can't inflate it.
            var people: [String: Set<String>] = [:]
            var mine = Set<String>()
            for (_, result) in prayedResults {
                guard case .success(let record) = result, let requestID = record["requestID"] as? String else { continue }
                let person = record.creatorUserRecordID?.recordName ?? (record["memberID"] as? String ?? "")
                people[requestID, default: []].insert(person)
                if record["memberID"] as? String == me { mine.insert(requestID) }
            }
            let counts = people.mapValues(\.count)
            return requestResults.compactMap { _, result in
                guard case .success(let record) = result else { return nil }
                return Self.request(from: record, me: me, counts: counts, mine: mine)
            }
        } catch {
            throw Self.map(error)
        }
    }

    func postRequest(code: String, topic: PrayerTopic, note: String, displayName: String, emoji: String) async throws -> CirclePrayerRequest {
        let clean = RequestNoteFilter.clean(note)
        guard RequestNoteFilter.problem(with: clean) == nil, NameFilter.isAllowed(displayName) else { throw CircleError.nameNotAllowed }
        let open = try await requests(code: code).filter { $0.isMine }
        guard open.count < CirclePrayerRequest.maxOpenPerMember else { throw CircleError.tooManyRequests }
        let db = try database()
        let requestID = "request-\(code)-\(UUID().uuidString.lowercased())"
        let record = CKRecord(recordType: "CirclePrayerRequest", recordID: CKRecord.ID(recordName: requestID))
        let now = Date()
        record["circleCode"] = code as CKRecordValue
        record["requestID"] = requestID as CKRecordValue
        record["memberID"] = memberID as CKRecordValue
        record["displayName"] = NameFilter.clean(displayName) as CKRecordValue
        record["emoji"] = emoji as CKRecordValue
        record["topic"] = topic.rawValue as CKRecordValue
        record["note"] = clean as CKRecordValue
        record["createdAt"] = now as CKRecordValue
        do {
            _ = try await db.save(record)
        } catch {
            throw Self.map(error)
        }
        return CirclePrayerRequest(id: requestID, circleCode: code, memberID: memberID, displayName: NameFilter.clean(displayName),
                                   emoji: emoji, topic: topic, note: clean, createdAt: now, prayedCount: 0, iPrayed: false, isMine: true)
    }

    func deleteRequest(_ request: CirclePrayerRequest) async throws {
        guard request.isMine else { return }
        let db = try database()
        do {
            _ = try await db.modifyRecords(saving: [], deleting: [CKRecord.ID(recordName: request.id)])
        } catch {
            let mapped = Self.map(error)
            if mapped != .notFound { throw mapped }
        }
    }

    func prayed(for request: CirclePrayerRequest) async throws {
        let db = try database()
        let record = CKRecord(recordType: "CirclePrayed", recordID: prayedRecordID(request.id, memberID))
        record["circleCode"] = request.circleCode as CKRecordValue
        record["requestID"] = request.id as CKRecordValue
        record["memberID"] = memberID as CKRecordValue
        record["createdAt"] = Date() as CKRecordValue
        do {
            // .allKeys: praying again just refreshes my own row; it never adds a second one.
            let (saved, _) = try await db.modifyRecords(saving: [record], deleting: [], savePolicy: .allKeys, atomically: false)
            if case .failure(let error)? = saved[record.recordID] { throw error }
        } catch {
            throw Self.map(error)
        }
    }

    func reportRequest(_ request: CirclePrayerRequest, reason: String) async throws {
        try await report(memberID: request.memberID, code: request.circleCode,
                         reason: "Prayer request \(request.id): \(reason) | \(request.summary)")
    }

    /// My requests and my "I prayed" rows (in one circle, or all), for Leave and Erase all.
    private func myRequestRecordIDs(in db: CKDatabase, code: String? = nil) async -> [CKRecord.ID] {
        var ids: [CKRecord.ID] = []
        let predicate = code.map { NSPredicate(format: "memberID == %@ AND circleCode == %@", memberID, $0) }
            ?? NSPredicate(format: "memberID == %@", memberID)
        for type in ["CirclePrayerRequest", "CirclePrayed"] {
            let query = CKQuery(recordType: type, predicate: predicate)
            if let (results, _) = try? await db.records(matching: query, resultsLimit: 400) {
                ids += results.compactMap { id, result in if case .success = result { return id } else { return nil } }
            }
        }
        return ids
    }

    private static func request(from record: CKRecord, me: String, counts: [String: Int], mine: Set<String>) -> CirclePrayerRequest? {
        guard let code = record["circleCode"] as? String, let member = record["memberID"] as? String,
              let topic = (record["topic"] as? String).flatMap(PrayerTopic.init(rawValue:)) else { return nil }
        let id = record.recordID.recordName
        return CirclePrayerRequest(id: id, circleCode: code, memberID: member,
                                   displayName: record["displayName"] as? String ?? "friend",
                                   emoji: record["emoji"] as? String ?? "🙏", topic: topic,
                                   note: record["note"] as? String ?? "",
                                   createdAt: record["createdAt"] as? Date ?? record.creationDate ?? Date(),
                                   prayedCount: counts[id] ?? 0, iPrayed: mine.contains(id), isMine: member == me)
    }

    // MARK: Helpers

    private func addCode(_ code: String) {
        var codes = store.circleCodes
        if !codes.contains(code) { codes.append(code) }
        store.circleCodes = codes
    }

    private func saveMember(code: String, displayName: String, emoji: String, prayers: Int, streak: Int,
                            hidden: Bool, in db: CKDatabase) async throws {
        let record = CKRecord(recordType: "CircleMember", recordID: memberRecordID(code, memberID))
        record["circleCode"] = code as CKRecordValue
        record["memberID"] = memberID as CKRecordValue
        record["displayName"] = NameFilter.clean(displayName) as CKRecordValue
        record["emoji"] = emoji as CKRecordValue
        record["prayersThisWeek"] = prayers as CKRecordValue
        record["weekKey"] = CircleWeek.key() as CKRecordValue
        record["streak"] = streak as CKRecordValue
        record["hidden"] = (hidden ? 1 : 0) as CKRecordValue
        record["updatedAt"] = Date() as CKRecordValue
        // .allKeys overwrites my own row without a change tag. Per-record failures come back in the results, not as a throw.
        let (saved, _) = try await db.modifyRecords(saving: [record], deleting: [], savePolicy: .allKeys, atomically: false)
        if case .failure(let error)? = saved[record.recordID] { throw error }
    }

    private static func circle(from record: CKRecord) -> PrayerCircle {
        PrayerCircle(code: record["code"] as? String ?? String(record.recordID.recordName.dropFirst("circle-".count)),
                     name: record["name"] as? String ?? "Prayer Circle",
                     createdAt: record["createdAt"] as? Date ?? record.creationDate ?? Date(),
                     ownerID: record["ownerID"] as? String ?? "")
    }

    private static func member(from record: CKRecord, me: String) -> CircleMember {
        let id = record["memberID"] as? String ?? record.recordID.recordName
        return CircleMember(id: id,
                            displayName: record["displayName"] as? String ?? "Friend",
                            emoji: record["emoji"] as? String ?? "🕊️",
                            prayersThisWeek: record["prayersThisWeek"] as? Int ?? 0,
                            streak: record["streak"] as? Int ?? 0,
                            weekKey: record["weekKey"] as? String ?? "",
                            updatedAt: record["updatedAt"] as? Date ?? Date(),
                            isMe: id == me,
                            isHidden: (record["hidden"] as? Int ?? 0) == 1)
    }

    static func map(_ error: Error) -> CircleError {
        if let circle = error as? CircleError { return circle }
        guard let ck = error as? CKError else { return .other(error.localizedDescription) }
        switch ck.code {
        case .unknownItem: return .notFound
        case .notAuthenticated, .permissionFailure: return .noAccount
        case .networkUnavailable, .networkFailure, .serviceUnavailable, .requestRateLimited, .zoneBusy: return .network
        case .partialFailure:
            if let partial = ck.partialErrorsByItemID?.values.first { return map(partial) }
            return .other(ck.localizedDescription)
        default: return .other("Circles hit a snag (\(ck.code.rawValue)). Please try again.")
        }
    }
}
