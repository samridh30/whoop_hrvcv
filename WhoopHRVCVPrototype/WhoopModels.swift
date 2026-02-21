import Foundation

struct BackendHRVResponse: Decodable {
    let samples: [HRVSample]
}

struct HRVSample: Decodable, Identifiable {
    let cycleID: Int
    let date: Date
    let hrvRMSSDMilli: Double

    var id: Int { cycleID }

    enum CodingKeys: String, CodingKey {
        case cycleID = "cycle_id"
        case date
        case hrvRMSSDMilli = "hrv_rmssd_milli"
    }
}
