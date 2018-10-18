import Vapor
import FluentPostgreSQL

final class Acronym: Codable {
    //MARK: - Properteis
    var id: Int?
    var short: String
    var long: String
    var userID: User.ID
    
    //MARK: -
    init(short: String, long: String, userID: User.ID) {
        self.short = short
        self.long = long
        self.userID = userID
    }
}

extension Acronym {
    
    var user: Parent<Acronym, User> {
        return parent(\.userID)
    }
}

extension Acronym: PostgreSQLModel {}

extension Acronym: Migration {
    
    static func prepare(on connection: PostgreSQLConnection) -> Future<Void> {
        
        return Database.create(self, on: connection) { builder in
            try addProperties(to: builder)
            builder.reference(from: \.userID, to: \User.id)
        }
    }
}

extension Acronym: Content {}

extension Acronym: Parameter {}
