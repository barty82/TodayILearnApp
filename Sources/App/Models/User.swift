import Foundation
import Vapor
import FluentPostgreSQL

final class User: Codable {
    
    //MARK: Properties
    var id: UUID?
    var name: String
    var username: String
    
    //MARK:
    init(name: String, username: String) {
        self.name = name
        self.username = username
    }
}

extension User {
    
    var acronyms: Children<User, Acronym> {
        return children(\.userID)
    }
}

extension User: PostgreSQLUUIDModel {}
extension User: Content {}
extension User: Migration {}
extension User: Parameter {}
