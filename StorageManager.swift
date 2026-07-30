import Foundation

class StorageManager {
    private static let driverNameKey = "driverName"
    private static let stateCodeKey = "stateCode"
    private static let permitIssueDateKey = "permitIssueDate"

    private init() {}

    static func saveDriverName(_ name: String) {
        UserDefaults.standard.set(name, forKey: driverNameKey)
    }

    static func getDriverName() -> String? {
        return UserDefaults.standard.string(forKey: driverNameKey)
    }

    static func saveStateCode(_ code: String) {
        UserDefaults.standard.set(code, forKey: stateCodeKey)
    }

    static func getStateCode() -> String? {
        return UserDefaults.standard.string(forKey: stateCodeKey)
    }

    static func savePermitIssueDate(_ date: Date) {
        UserDefaults.standard.set(date, forKey: permitIssueDateKey)
    }

    static func getPermitIssueDate() -> Date? {
        return UserDefaults.standard.object(forKey: permitIssueDateKey) as? Date
    }
}
