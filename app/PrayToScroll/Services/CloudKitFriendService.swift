import CloudKit
import Foundation

/// Usernames and friends on the CloudKit public database (container iCloud.com.amenkeyapp.ios).
///
/// Records (schema in app/CloudKit/schema.ckdb; nothing here is world-queryable, so there is no directory):
/// - `Username`      recordName `<handle>` (lowercase)       memberID, createdAt. Saving a name that exists fails,
///                                                           which makes the claim atomic. World-readable for exact
///                                                           lookup by name only (no queryable fields).
/// - `FriendProfile` recordName `profile-<memberID>`         memberID, handle, displayName, emoji, streak,
///                                                           lastPrayedDay, openCircles, savedRefs, updatedAt
///                                                           (savedRefs: verse references, only when the person
///                                                           turned on "Friends see verses I save")
/// - `FriendRequest` recordName `freq-<from>-<to>`           fromID, toID, fromHandle, toHandle, createdAt
/// - `FriendLink`    recordName `link-<owner>-<friend>`      ownerID, friendID, createdAt. A friendship is a link
///                                                           each way (each side can only write its own records).
/// - `PrayedFor`     recordName `pf-<from>-<to>-<day>`       fromID, toID, fromHandle, day, createdAt
/// - `FriendBlock`   recordName `fblock-<blocker>-<blocked>` blockerID, blockedID, createdAt
/// - reports reuse `CircleReport` with circleCode "friends".
/// Requests, links, prayed-for rows, blocks and profiles are readable by signed-in iCloud users only (not the
/// world) and are fetched by record name or by an exact id match. Member ids are random per install.
final class CloudKitFriendService: FriendService, @unchecked Sendable {
    private let store: SharedStore
    private let lock = NSLock()
    private var cachedContainer: CKContainer?
    static let maxOutgoing = 20
    static let prayedForWindow: TimeInterval = 7 * 86_400

    init(store: SharedStore = .shared) {
        self.store = store
    }

    private func database() throws -> CKDatabase {
        guard FileManager.default.ubiquityIdentityToken != nil else { throw FriendError.noAccount }
        lock.lock()
        defer { lock.unlock() }
        if let cachedContainer { return cachedContainer.publicCloudDatabase }
        let container = CKContainer(identifier: AppConstants.cloudKitContainer)
        cachedContainer = container
        return container.publicCloudDatabase
    }

    private var me: String { store.circleMemberID }

    private func id(_ name: String) -> CKRecord.ID { CKRecord.ID(recordName: name) }
    private func profileID(_ member: String) -> CKRecord.ID { id("profile-\(member)") }
    private func requestID(from: String, to: String) -> CKRecord.ID { id("freq-\(from)-\(to)") }
    private func linkID(owner: String, friend: String) -> CKRecord.ID { id("link-\(owner)-\(friend)") }
    private func blockID(blocker: String, blocked: String) -> CKRecord.ID { id("fblock-\(blocker)-\(blocked)") }

    func availability() async -> CircleAvailability {
        guard FileManager.default.ubiquityIdentityToken != nil else { return .noAccount }
        do {
            _ = try database()
            guard let container = cachedContainer else { return .noAccount }
            switch try await container.accountStatus() {
            case .available: return .available
            case .noAccount: return .noAccount
            case .restricted: return .restricted
            default: return .unavailable("iCloud is temporarily unavailable. Try again in a moment.")
            }
        } catch {
            return .unavailable(Self.map(error).errorDescription ?? "iCloud is unavailable right now.")
        }
    }

    func myHandle() async -> String? { store.username }

    // MARK: Username

    func claim(handle raw: String, profile: FriendProfile) async throws -> String {
        let handle = UsernameRules.normalize(raw)
        if let problem = UsernameRules.problem(with: handle) { throw FriendError.invalid(problem) }
        let db = try database()
        let old = store.username
        if old == handle { return handle }
        do {
            // One change every 30 days (the old record's createdAt is the server's truth).
            if let old, let record = try? await db.record(for: id(old)),
               let next = UsernameRules.nextChange(after: record["createdAt"] as? Date ?? record.creationDate) {
                throw FriendError.invalid(.tooSoon(next))
            }
            let record = CKRecord(recordType: "Username", recordID: id(handle))
            record["memberID"] = me as CKRecordValue
            record["createdAt"] = Date() as CKRecordValue
            do {
                let (saved, _) = try await db.modifyRecords(saving: [record], deleting: [], savePolicy: .ifServerRecordUnchanged,
                                                            atomically: true)
                if case .failure(let error)? = saved[record.recordID] { throw error }
            } catch let error as CKError where Self.isAlreadyExists(error) {
                // Taken, unless it's mine from an earlier install on this iCloud account.
                let existing = try await db.record(for: id(handle))
                guard existing.creatorUserRecordID?.recordName == CKCurrentUserDefaultName else {
                    throw FriendError.invalid(.taken)
                }
                existing["memberID"] = me as CKRecordValue
                _ = try await db.modifyRecords(saving: [existing], deleting: [], savePolicy: .changedKeys, atomically: true)
            }
            if let old { _ = try? await db.modifyRecords(saving: [], deleting: [id(old)], savePolicy: .allKeys, atomically: false) }
            store.username = handle
            var mine = profile
            mine.handle = handle
            try await publish(mine)
            return handle
        } catch let error as FriendError {
            throw error
        } catch {
            throw Self.map(error)
        }
    }

    func lookup(handle raw: String) async throws -> FriendProfile {
        let handle = UsernameRules.normalize(raw)
        guard UsernameRules.problem(with: handle) == nil || UsernameRules.problem(with: handle) == .reserved else {
            throw FriendError.notFound
        }
        let db = try database()
        do {
            guard let record = try? await db.record(for: id(handle)), let member = record["memberID"] as? String else {
                throw FriendError.notFound
            }
            if member != me {
                // Blocked either way: they simply don't exist for each other.
                if store.blockedFriends.contains(member) { throw FriendError.notFound }
                let blocks = try await db.records(for: [blockID(blocker: member, blocked: me), blockID(blocker: me, blocked: member)])
                if blocks.values.contains(where: { if case .success = $0 { return true } else { return false } }) {
                    throw FriendError.notFound
                }
            }
            if let profileRecord = try? await db.record(for: profileID(member)) {
                var profile = Self.profile(from: profileRecord)
                profile.openCircles = []   // circle codes are for friends, not for anyone who types the name
                return profile
            }
            return FriendProfile(memberID: member, handle: handle, displayName: handle, emoji: "🙂", streak: 0, lastPrayedDay: "")
        } catch let error as FriendError {
            throw error
        } catch {
            throw Self.map(error)
        }
    }

    // MARK: Snapshot

    func snapshot() async throws -> FriendsSnapshot {
        let db = try database()
        let me = self.me
        do {
            var result = FriendsSnapshot()
            if let mine = try? await db.record(for: profileID(me)) { result.me = Self.profile(from: mine) }
            async let myLinksQ = query(db, "FriendLink", "ownerID", me)
            async let theirLinksQ = query(db, "FriendLink", "friendID", me)
            async let incomingQ = query(db, "FriendRequest", "toID", me)
            async let outgoingQ = query(db, "FriendRequest", "fromID", me)
            async let blockedMeQ = query(db, "FriendBlock", "blockedID", me)
            async let myBlocksQ = query(db, "FriendBlock", "blockerID", me)
            async let prayedQ = query(db, "PrayedFor", "toID", me)
            async let sentQ = query(db, "PrayedFor", "fromID", me)
            let (myLinks, theirLinks, incoming, outgoing) = try await (myLinksQ, theirLinksQ, incomingQ, outgoingQ)
            let (blockedMe, myBlocks, prayed, sent) = try await (blockedMeQ, myBlocksQ, prayedQ, sentQ)

            var blocked = Set(myBlocks.compactMap { $0["blockedID"] as? String })
            store.blockedFriends = blocked
            blocked.formUnion(blockedMe.compactMap { $0["blockerID"] as? String })

            let mineTo = Set(myLinks.compactMap { $0["friendID"] as? String })
            let theirsTo = Set(theirLinks.compactMap { $0["ownerID"] as? String })
            let requests = incoming.compactMap(Self.request(from:)).filter { !blocked.contains($0.fromID) }
            let requested = outgoing.compactMap(Self.request(from:))
            let requestedTo = Set(requested.map(\.toID))
            let askedMe = Set(requests.map(\.fromID))

            // They accepted my request: add my side of the link and drop the request.
            var newLinks: [CKRecord] = []
            var cleanup: [CKRecord.ID] = []
            for friend in theirsTo where !mineTo.contains(friend) && requestedTo.contains(friend) && !blocked.contains(friend) {
                newLinks.append(link(owner: me, friend: friend))
                cleanup.append(requestID(from: me, to: friend))
            }
            // They removed or blocked me (no link back and no request waiting): drop my side.
            for friend in mineTo where !theirsTo.contains(friend) && (!askedMe.contains(friend) || blocked.contains(friend)) {
                cleanup.append(linkID(owner: me, friend: friend))
            }
            // My "prayed for you" rows only show for 7 days: delete older ones.
            let cutoff = Date().addingTimeInterval(-Self.prayedForWindow)
            cleanup += sent.filter { ($0["createdAt"] as? Date ?? $0.creationDate ?? .distantPast) < cutoff }.map(\.recordID)
            if !newLinks.isEmpty || !cleanup.isEmpty {
                _ = try? await db.modifyRecords(saving: newLinks, deleting: cleanup, savePolicy: .allKeys, atomically: false)
            }

            let accepted = Set(newLinks.compactMap { $0["friendID"] as? String })
            let friendIDs = mineTo.intersection(theirsTo).union(accepted)
                .union(mineTo.intersection(askedMe))   // I accepted; they'll add their side on their next open
                .subtracting(blocked)
            let declined = store.declinedFriendRequests
            result.incoming = requests.filter { !friendIDs.contains($0.fromID) && !declined.contains($0.fromID) }
                .sorted { $0.createdAt > $1.createdAt }
            result.outgoing = requested.filter { !friendIDs.contains($0.toID) && !blocked.contains($0.toID) }
                .sorted { $0.createdAt > $1.createdAt }

            if !friendIDs.isEmpty {
                let profiles = try await db.records(for: friendIDs.map(profileID))
                result.friends = profiles.values.compactMap { try? $0.get() }.map(Self.profile(from:))
                    .sorted { $0.handle < $1.handle }
            }
            result.prayedForMe = prayed.compactMap(Self.prayedFor(from:))
                .filter { friendIDs.contains($0.fromID) && $0.createdAt > cutoff }
                .sorted { $0.createdAt > $1.createdAt }
            let today = DayKey(Date()).string
            result.prayedTodayFor = Set(sent.filter { ($0["day"] as? String) == today }.compactMap { $0["toID"] as? String })
            return result
        } catch let error as FriendError {
            throw error
        } catch {
            throw Self.map(error)
        }
    }

    // MARK: Requests and friends

    func sendRequest(to profile: FriendProfile) async throws {
        guard let myHandle = store.username else { throw FriendError.needsUsername }
        guard profile.memberID != me else { throw FriendError.other("That's you!") }
        let db = try database()
        do {
            let outgoing = try await query(db, "FriendRequest", "fromID", me)
            if outgoing.count >= Self.maxOutgoing { throw FriendError.tooManyRequests }
            // They already asked me: that's a yes.
            if (try? await db.record(for: requestID(from: profile.memberID, to: me))) != nil {
                _ = try await db.modifyRecords(saving: [link(owner: me, friend: profile.memberID)], deleting: [],
                                               savePolicy: .allKeys, atomically: false)
                return
            }
            let record = CKRecord(recordType: "FriendRequest", recordID: requestID(from: me, to: profile.memberID))
            record["fromID"] = me as CKRecordValue
            record["toID"] = profile.memberID as CKRecordValue
            record["fromHandle"] = myHandle as CKRecordValue
            record["toHandle"] = profile.handle as CKRecordValue
            record["createdAt"] = Date() as CKRecordValue
            // My side of the link is added once they accept (see snapshot), so a pending request is never a friend.
            _ = try await db.modifyRecords(saving: [record], deleting: [], savePolicy: .allKeys, atomically: false)
        } catch let error as FriendError {
            throw error
        } catch {
            throw Self.map(error)
        }
    }

    func cancelRequest(to memberID: String) async throws {
        try await delete([requestID(from: me, to: memberID), linkID(owner: me, friend: memberID)])
    }

    func accept(_ request: FriendRequest) async throws {
        let db = try database()
        var declined = store.declinedFriendRequests
        declined.remove(request.fromID)
        store.declinedFriendRequests = declined
        do {
            _ = try await db.modifyRecords(saving: [link(owner: me, friend: request.fromID)], deleting: [],
                                           savePolicy: .allKeys, atomically: false)
        } catch {
            throw Self.map(error)
        }
    }

    func decline(_ request: FriendRequest) async throws {
        var declined = store.declinedFriendRequests
        declined.insert(request.fromID)
        store.declinedFriendRequests = declined
    }

    func remove(friend memberID: String) async throws {
        try await delete([linkID(owner: me, friend: memberID), requestID(from: me, to: memberID)])
    }

    func block(memberID: String, handle: String) async throws {
        let db = try database()
        var blocked = store.blockedFriends
        blocked.insert(memberID)
        store.blockedFriends = blocked
        let record = CKRecord(recordType: "FriendBlock", recordID: blockID(blocker: me, blocked: memberID))
        record["blockerID"] = me as CKRecordValue
        record["blockedID"] = memberID as CKRecordValue
        record["createdAt"] = Date() as CKRecordValue
        do {
            _ = try await db.modifyRecords(saving: [record],
                                           deleting: [linkID(owner: me, friend: memberID), requestID(from: me, to: memberID)],
                                           savePolicy: .allKeys, atomically: false)
        } catch {
            throw Self.map(error)
        }
    }

    func report(memberID: String, handle: String, reason: String) async throws {
        let db = try database()
        let record = CKRecord(recordType: "CircleReport")
        record["circleCode"] = "friends" as CKRecordValue
        record["memberID"] = memberID as CKRecordValue
        record["reason"] = "@\(handle): \(reason)" as CKRecordValue
        record["reporterID"] = me as CKRecordValue
        record["createdAt"] = Date() as CKRecordValue
        do {
            _ = try await db.save(record)
        } catch {
            throw Self.map(error)
        }
        try await block(memberID: memberID, handle: handle)
    }

    func prayedFor(_ friend: FriendProfile) async throws {
        guard let myHandle = store.username else { throw FriendError.needsUsername }
        let db = try database()
        let day = DayKey(Date()).string
        let record = CKRecord(recordType: "PrayedFor", recordID: id("pf-\(me)-\(friend.memberID)-\(day)"))
        record["fromID"] = me as CKRecordValue
        record["toID"] = friend.memberID as CKRecordValue
        record["fromHandle"] = myHandle as CKRecordValue
        record["day"] = day as CKRecordValue
        record["createdAt"] = Date() as CKRecordValue
        do {
            _ = try await db.modifyRecords(saving: [record], deleting: [], savePolicy: .allKeys, atomically: false)
        } catch {
            throw Self.map(error)
        }
    }

    func publish(_ profile: FriendProfile) async throws {
        guard let handle = store.username else { return }   // hidden until a username is chosen
        let db = try database()
        let record = CKRecord(recordType: "FriendProfile", recordID: profileID(me))
        record["memberID"] = me as CKRecordValue
        record["handle"] = handle as CKRecordValue
        record["displayName"] = profile.displayName as CKRecordValue
        record["emoji"] = profile.emoji as CKRecordValue
        record["streak"] = profile.streak as CKRecordValue
        record["lastPrayedDay"] = profile.lastPrayedDay as CKRecordValue
        record["openCircles"] = profile.openCircles.map { "\($0.code)|\($0.name)" } as CKRecordValue
        record["updatedAt"] = Date() as CKRecordValue
        // Always written (an empty list when sharing is off), so turning sharing off clears what friends saw.
        record["savedRefs"] = Array(profile.savedRefs.prefix(FriendProfile.maxSavedRefs)) as CKRecordValue
        do {
            _ = try await db.modifyRecords(saving: [record], deleting: [], savePolicy: .allKeys, atomically: false)
        } catch {
            // A server whose schema predates savedRefs refuses the unknown field: keep the profile (streak, circles)
            // current without it.
            record["savedRefs"] = nil
            do {
                _ = try await db.modifyRecords(saving: [record], deleting: [], savePolicy: .allKeys, atomically: false)
            } catch {
                throw Self.map(error)
            }
        }
    }

    func deleteMyData(handle: String?) async throws {
        let db = try database()
        let me = self.me
        var ids: [CKRecord.ID] = [profileID(me)]
        if let handle = handle ?? store.username { ids.append(id(UsernameRules.normalize(handle))) }
        for (type, field) in [("FriendLink", "ownerID"), ("FriendRequest", "fromID"), ("PrayedFor", "fromID"), ("FriendBlock", "blockerID")] {
            ids += ((try? await query(db, type, field, me)) ?? []).map(\.recordID)
        }
        do {
            _ = try await db.modifyRecords(saving: [], deleting: ids, savePolicy: .allKeys, atomically: false)
        } catch {
            let mapped = Self.map(error)
            if mapped != .notFound { throw mapped }
        }
        store.username = nil
    }

    // MARK: Helpers

    private func link(owner: String, friend: String) -> CKRecord {
        let record = CKRecord(recordType: "FriendLink", recordID: linkID(owner: owner, friend: friend))
        record["ownerID"] = owner as CKRecordValue
        record["friendID"] = friend as CKRecordValue
        record["createdAt"] = Date() as CKRecordValue
        return record
    }

    private func delete(_ ids: [CKRecord.ID]) async throws {
        let db = try database()
        do {
            _ = try await db.modifyRecords(saving: [], deleting: ids, savePolicy: .allKeys, atomically: false)
        } catch {
            let mapped = Self.map(error)
            if mapped != .notFound { throw mapped }
        }
    }

    /// Exact match on one id field (never a listing).
    private func query(_ db: CKDatabase, _ type: String, _ field: String, _ value: String) async throws -> [CKRecord] {
        let query = CKQuery(recordType: type, predicate: NSPredicate(format: "%K == %@", field, value))
        let (results, _) = try await db.records(matching: query, resultsLimit: 200)
        return results.compactMap { try? $0.1.get() }
    }

    private static func isAlreadyExists(_ error: CKError) -> Bool {
        if error.code == .serverRecordChanged { return true }
        if error.code == .partialFailure, let partial = error.partialErrorsByItemID?.values.first as? CKError {
            return partial.code == .serverRecordChanged
        }
        return false
    }

    static func profile(from record: CKRecord) -> FriendProfile {
        let circles = (record["openCircles"] as? [String] ?? []).compactMap { entry -> FriendProfile.OpenCircle? in
            let parts = entry.split(separator: "|", maxSplits: 1).map(String.init)
            guard parts.count == 2, CircleCode.isValid(parts[0]) else { return nil }
            return FriendProfile.OpenCircle(code: parts[0], name: parts[1])
        }
        return FriendProfile(memberID: record["memberID"] as? String ?? "",
                             handle: record["handle"] as? String ?? "",
                             displayName: record["displayName"] as? String ?? "",
                             emoji: record["emoji"] as? String ?? "🙂",
                             streak: record["streak"] as? Int ?? 0,
                             lastPrayedDay: record["lastPrayedDay"] as? String ?? "",
                             openCircles: circles,
                             savedRefs: record["savedRefs"] as? [String] ?? [])
    }

    private static func request(from record: CKRecord) -> FriendRequest? {
        guard let from = record["fromID"] as? String, let to = record["toID"] as? String else { return nil }
        return FriendRequest(fromID: from, toID: to, fromHandle: record["fromHandle"] as? String ?? "",
                             toHandle: record["toHandle"] as? String ?? "", createdAt: record["createdAt"] as? Date ?? Date())
    }

    private static func prayedFor(from record: CKRecord) -> PrayedForItem? {
        guard let from = record["fromID"] as? String else { return nil }
        return PrayedForItem(id: record.recordID.recordName, fromID: from, fromHandle: record["fromHandle"] as? String ?? "",
                             createdAt: record["createdAt"] as? Date ?? Date())
    }

    static func map(_ error: Error) -> FriendError {
        if let friend = error as? FriendError { return friend }
        guard let ck = error as? CKError else { return .other(error.localizedDescription) }
        switch ck.code {
        case .unknownItem: return .notFound
        case .notAuthenticated, .permissionFailure: return .noAccount
        case .networkUnavailable, .networkFailure, .serviceUnavailable, .requestRateLimited, .zoneBusy: return .network
        case .partialFailure:
            if let partial = ck.partialErrorsByItemID?.values.first { return map(partial) }
            return .other(ck.localizedDescription)
        default: return .other("Friends hit a snag (\(ck.code.rawValue)). Please try again.")
        }
    }
}
