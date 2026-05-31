import Foundation

struct AudioInputDevice: Identifiable, Equatable {
    let id: String
    let name: String
    let isDefault: Bool
}
