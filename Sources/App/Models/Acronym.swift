import Vapor
import FluentPostgreSQL

final class Acronym: Codable {
    //MARK: - Properteis
    var id: Int?
    var short: String
    var long: String
    
    //MARK: -
    init(short: String, long: String) {
        self.short = short
        self.long = long
    }
}

extension Acronym: PostgreSQLModel {}

extension Acronym: Migration {}

extension Acronym: Content {}

extension Acronym: Parameter {}
