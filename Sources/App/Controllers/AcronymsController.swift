import Vapor
import Fluent

struct AcronymsController: RouteCollection {
    
    //MARK: - Life cycle
    func boot(router: Router) throws {
        let acronymsRoutes = router.grouped("api", "acronyms")
        acronymsRoutes.post(Acronym.self, use: createHandler)
        acronymsRoutes.post(Acronym.parameter, "categories", Category.parameter, use: addCategoriesHandler)
        acronymsRoutes.get(use: getAllHandler)
        acronymsRoutes.get(Acronym.parameter, use: getHandler)
        acronymsRoutes.get("first", use: getFirstHandler)
        acronymsRoutes.get("sorted", use: getSortedHandler)
        acronymsRoutes.get("search", use: searchHandler)
        acronymsRoutes.get(Acronym.parameter, "user", use: getUserHandler)
        acronymsRoutes.get(Acronym.parameter, "categories", use: getCategoriesHandler)
        acronymsRoutes.put(Acronym.parameter, use: updateHandler)
        acronymsRoutes.delete(Acronym.parameter, use: deleteHandler)
        acronymsRoutes.delete(Acronym.parameter, "categories", Category.parameter, use: removeCategoriesHandler)
    }
    
    // Create
    private func createHandler(_ req: Request, acronym: Acronym) throws -> Future<Acronym> {
        return acronym.save(on: req)
    }
    
    private func addCategoriesHandler(_ req: Request) throws -> Future<HTTPStatus> {
        return try flatMap(to: HTTPStatus.self,
                           req.parameters.next(Acronym.self),
                           req.parameters.next(Category.self)) { acronym, category in
                            return acronym.categories
                                .attach(category, on: req)
                                .transform(to: .created)
        }
    }
    
    // Retrieve
    private func getAllHandler(_ req: Request) throws -> Future<[Acronym]> {
        return Acronym.query(on: req).all()
    }
    
    private func getHandler(_ req: Request) throws -> Future<Acronym> {
        return try req.parameters.next(Acronym.self)
    }
    
    private func getFirstHandler(_ req: Request) throws -> Future<Acronym> {
        return Acronym.query(on: req).first().map(to: Acronym.self) { acronym in
            
            guard let acronym = acronym else {
                throw Abort(.notFound)
            }
            return acronym
        }
    }
    
    private func getSortedHandler(_ req: Request) throws -> Future<[Acronym]> {
        return Acronym.query(on: req).sort(\.short, .ascending).all()
    }
    
    private func getUserHandler(_ req: Request) throws -> Future<User> {
        return try req.parameters.next(Acronym.self).flatMap(to: User.self) { acronym in
            acronym.user.get(on: req)
        }
    }
    
    private func getCategoriesHandler(_ req: Request) throws -> Future<[Category]> {
        return try req.parameters.next(Acronym.self)
            .flatMap(to: [Category].self) { acronym in
                try acronym.categories.query(on: req).all()
        }
    }
    
    // Update
    private func updateHandler(_ req: Request) throws -> Future<Acronym> {
        return try flatMap(to: Acronym.self,
                           req.parameters.next(Acronym.self),
                           req.content.decode(Acronym.self)) {
                            acronym, updatedAcronym in
                            acronym.short = updatedAcronym.short
                            acronym.long = updatedAcronym.long
                            acronym.userID = updatedAcronym.userID
                            return acronym.save(on: req)
        }
    }
    
    // Delete
    private func deleteHandler(_ req: Request) throws -> Future<HTTPStatus> {
        return try req.parameters.next(Acronym.self)
            .delete(on: req)
            .transform(to: HTTPStatus.noContent)
    }
    
    private func removeCategoriesHandler(_ req: Request) throws -> Future<HTTPStatus> {
        return try flatMap(to: HTTPStatus.self,
                           req.parameters.next(Acronym.self),
                           req.parameters.next(Category.self)) { acronym, category in
                            return acronym.categories
                                .detach(category, on: req)
                                .transform(to: .noContent)
        }
    }
    
    // Search
    private func searchHandler(_ req: Request) throws -> Future<[Acronym]> {
        guard let searchTerm = req.query[String.self, at: "term"] else {
            throw Abort(.badRequest)
        }
        
        return Acronym.query(on: req).group(.or) { or in
            or.filter(\.short == searchTerm)
            or.filter(\.long == searchTerm)
            }.all()
    }
}
