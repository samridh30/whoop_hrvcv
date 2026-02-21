import Foundation

struct RecoveryCollectionResponse: Decodable {
    let records: [RecoveryRecord]
    let nextToken: String?

    enum CodingKeys: String, CodingKey {
        case records
        case nextToken = "next_token"
    }
}

struct RecoveryRecord: Decodable, Identifiable {
    let cycleID: Int
    let createdAt: Date
    let scoreState: String
    let score: RecoveryScore?

    var id: Int { cycleID }

    enum CodingKeys: String, CodingKey {
        case cycleID = "cycle_id"
        case createdAt = "created_at"
        case scoreState = "score_state"
        case score
    }
}

struct RecoveryScore: Decodable {
    let hrvRMSSDMilli: Double?

    enum CodingKeys: String, CodingKey {
        case hrvRMSSDMilli = "hrv_rmssd_milli"
    }
}

struct HRVSample: Identifiable {
    let cycleID: Int
    let date: Date
    let hrvRMSSDMilli: Double

    var id: Int { cycleID }
}
