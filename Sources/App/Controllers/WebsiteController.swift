import Vapor
import Leaf
import Fluent

struct WebsiteController: RouteCollection {
    
    //MARK: Override
    func boot(router: Router) throws {
        router.get(use: indexHandler)
        router.get("acronyms", Acronym.parameter, use: acronymHandler)
        router.get("users", User.parameter, use: userHandler)
        router.get("users", use: allUsersHandler)
        router.get("categories", use: allCategoriesHandler)
        router.get("categories", Category.parameter, use: categoryHandler)
        router.get("acronyms", "create", use: createAcronymHandler)
        router.post(CreateAcronymData.self, at: "acronyms", "create", use: createAcronymPostHandler)
        router.get("acronyms", Acronym.parameter, "edit", use: editAcronymHandler)
        router.post("acronyms", Acronym.parameter, "edit", use: editAcronymPostHandler)
        router.post("acronyms", Acronym.parameter, "delete", use: deleteAcronymHandler)
    }
    
    private func indexHandler(_ request: Request) throws -> Future<View> {
        return Acronym.query(on: request)
            .all()
            .flatMap(to: View.self, { acronyms in
                let acronymsData = acronyms.isEmpty ? nil : acronyms
                let context = IndexContext(title: "Homepage", acronyms: acronymsData)
                return try request.view().render("index", context)
            })
    }
    
    private func acronymHandler(_ req: Request) throws -> Future<View> {
        return try req.parameters.next(Acronym.self)
            .flatMap(to: View.self) { acronym in
                return acronym.user
                    .get(on: req)
                    .flatMap(to: View.self) { user in
                        let categories = try acronym.categories.query(on: req).all()
                        let context = AcronymContext(title: acronym.short, acronym: acronym, user: user, categories: categories)
                        return try req.view().render("acronym", context)
                }
        }
    }
    
    private func userHandler(_ req: Request) throws -> Future<View> {
        return try req.parameters.next(User.self)
            .flatMap(to: View.self) { user in
            return try user.acronyms
                .query(on: req)
                .all()
                .flatMap(to: View.self) { acronyms  in
                    let context = UserContext(title: user.name, user: user, acronyms: acronyms)
                    return try req.view().render("user", context)
                }
        }
    }
    
    private func allUsersHandler(_ req: Request) throws -> Future<View> {
        return User.query(on: req)
            .all()
            .flatMap(to: View.self) { users in
                // 3
                let context = AllUsersContext(title: "All Users", users: users)
                return try req.view().render("allUsers", context)
        }
    }
    
    private func allCategoriesHandler(_ req: Request) throws -> Future<View> {
        let categories = Category.query(on: req).all()
        let context = AllCategoriesContext(categories: categories)
        return try req.view().render("allCategories", context)
    }
    
    private func categoryHandler(_ req: Request) throws -> Future<View> {
        return try req.parameters.next(Category.self).flatMap(to: View.self) { category in
            let acronyms = try category.acronyms.query(on: req).all()
            let context = CategoryContext(title: category.name, category: category, acronyms: acronyms)
            return try req.view().render("category", context)
        }
    }
    
    private func createAcronymHandler(_ req: Request) throws -> Future<View> {
        let context = CreateAcronymContext(users: User.query(on: req).all())
        return try req.view().render("createAcronym", context)
    }
    
    private func createAcronymPostHandler(_ req: Request,
                                          data: CreateAcronymData) throws -> Future<Response> {
        let acronym = Acronym(short: data.short, long: data.long,
                              userID: data.userID)
        return acronym.save(on: req).flatMap(to: Response.self) {
            acronym in
            guard let id = acronym.id else {
                throw Abort(.internalServerError)
            }
            
            var categorySaves: [Future<Void>] = []
            
            for category in data.categories ?? [] {
                try categorySaves.append(
                    Category.addCategory(category, to: acronym, on: req))
            }
            
            let redirect = req.redirect(to: "/acronyms/\(id)")
            return categorySaves.flatten(on: req)
                .transform(to: redirect)
        }
    }
    
    private func editAcronymHandler(_ req: Request) throws -> Future<View> {
        return try req.parameters.next(Acronym.self).flatMap(to: View.self) { acronym in
            let users = User.query(on: req).all()
            let categories = try acronym.categories.query(on: req).all()
            let context = EditAcronymContext(acronym: acronym, users: users, categories: categories)
            return try req.view().render("createAcronym", context)
        }
    }
    
    private func editAcronymPostHandler(_ req: Request) throws -> Future<Response> {
        return try flatMap(
            to: Response.self,
            req.parameters.next(Acronym.self),
            req.content.decode(CreateAcronymData.self)) { acronym, data in
                acronym.short = data.short
                acronym.long = data.long
                acronym.userID = data.userID
                
                return acronym.save(on: req).flatMap(to: Response.self) { savedAcronym in
                    guard let id = savedAcronym.id else {
                        throw Abort(.internalServerError)
                    }
                    
                    return try acronym.categories.query(on: req).all()
                        .flatMap(to: Response.self) { existingCategories in
                            let existingStringArray = existingCategories.map { $0.name }
                            
                            let existingSet = Set<String>(existingStringArray)
                            let newSet = Set<String>(data.categories ?? [])
                            
                            let categoriesToAdd = newSet.subtracting(existingSet)
                            let categoriesToRemove = existingSet.subtracting(newSet)
                            
                            var categoryResults: [Future<Void>] = []
                            
                            for newCategory in categoriesToAdd {
                                categoryResults.append(
                                    try Category.addCategory(newCategory,
                                                             to: acronym,
                                                             on: req))
                            }
                            
                            for categoryNameToRemove in categoriesToRemove {
                                let categoryToRemove = existingCategories.first {
                                    $0.name == categoryNameToRemove
                                }
                                
                                if let category = categoryToRemove {
                                    categoryResults.append(acronym.categories.detach(category, on: req))
                                }
                            }
                            
                            return categoryResults
                                .flatten(on: req)
                                .transform(to: req.redirect(to: "/acronyms/\(id)"))
                    }
                }
        }
    }
    
    private func deleteAcronymHandler(_ req: Request) throws -> Future<Response> {
        return try req.parameters.next(Acronym.self)
            .delete(on: req)
            .transform(to: req.redirect(to: "/"))
    }
}


struct IndexContext: Encodable {
    let title: String
    let acronyms: [Acronym]?
}


struct AcronymContext: Encodable {
    let title: String
    let acronym: Acronym
    let user: User
    let categories: Future<[Category]>
}

struct UserContext: Encodable {
    let title: String
    let user: User
    let acronyms: [Acronym]
}

struct AllUsersContext: Encodable {
    let title: String
    let users: [User]
}

struct AllCategoriesContext: Encodable {
    let title = "All Categories"
    let categories: Future<[Category]>
}

struct CategoryContext: Encodable {
    let title: String
    let category: Category
    let acronyms: Future<[Acronym]>
}

struct CreateAcronymContext: Encodable {
    let title = "Create An Acronym"
    let users: Future<[User]>
}

struct EditAcronymContext: Encodable {
    let title = "Edit Acryonm"
    let acronym: Acronym
    let users: Future<[User]>
    let editing = true
    let categories: Future<[Category]>
}

struct CreateAcronymData: Content {
    let userID: User.ID
    let short: String
    let long: String
    let categories: [String]?
}
