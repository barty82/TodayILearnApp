 @testable import App
 import Vapor
 import XCTest
 import FluentPostgreSQL

 final class CategoryTests: XCTestCase {

   let categoriesURI = "/api/categories/"
   let categoryName = "Teenager"
   var app: Application!
   var conn: PostgreSQLConnection!

   override func setUp() {
     try! Application.reset()
     app = try! Application.testable()
     conn = try! app.newConnection(to: .psql).wait()
   }

   override func tearDown() {
     conn.close()
   }

   func testCategoriesCanBeRetrievedFromAPI() throws {
     let category = try Category.create(name: categoryName, on: conn)
     _ = try Category.create(on: conn)

     let categories = try app.getResponse(to: categoriesURI, decodeTo: [App.Category].self)

     XCTAssertEqual(categories.count, 2)
     XCTAssertEqual(categories[0].name, categoryName)
     XCTAssertEqual(categories[0].id, category.id)
   }

   func testCategoryCanBeSavedWithAPI() throws {
     let category = Category(name: categoryName)
     let receivedCategory = try app.getResponse(to: categoriesURI, method: .POST, headers: ["Content-Type": "application/json"], data: category, decodeTo: Category.self)

     XCTAssertEqual(receivedCategory.name, categoryName)
     XCTAssertNotNil(receivedCategory.id)

     let categories = try app.getResponse(to: categoriesURI, decodeTo: [App.Category].self)

     XCTAssertEqual(categories.count, 1)
     XCTAssertEqual(categories[0].name, categoryName)
     XCTAssertEqual(categories[0].id, receivedCategory.id)
   }

   func testGettingASingleCategoryFromTheAPI() throws {
     let category = try Category.create(name: categoryName, on: conn)
     let returnedCategory = try app.getResponse(to: "\(categoriesURI)\(category.id!)", decodeTo: Category.self)

     XCTAssertEqual(returnedCategory.name, categoryName)
     XCTAssertEqual(returnedCategory.id, category.id)
   }

    static let allTests = [("testCategoriesCanBeRetrievedFromAPI", testCategoriesCanBeRetrievedFromAPI),
                           ("testCategoryCanBeSavedWithAPI", testCategoryCanBeSavedWithAPI),
                           ("testGettingASingleCategoryFromTheAPI", testGettingASingleCategoryFromTheAPI),
                           ]
 }
