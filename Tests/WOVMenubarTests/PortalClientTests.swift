import Foundation
import XCTest
@testable import WOVMenubarCore

final class PortalClientTests: XCTestCase {
    func testEndpointURLPreservesBasePathAndQuery() throws {
        let url = try PortalClient.endpointURL(
            baseURL: URL(string: "https://portal.walkonvalley.com/app")!,
            path: "/api/quick-notes?page=1&pageSize=10"
        )
        XCTAssertEqual(url.absoluteString, "https://portal.walkonvalley.com/app/api/quick-notes?page=1&pageSize=10")
    }

    func testExtractsWebSessionCookieFromLoginResponse() throws {
        let response = HTTPURLResponse(
            url: URL(string: "https://portal.walkonvalley.com/api/auth/login")!,
            statusCode: 200,
            httpVersion: nil,
            headerFields: ["Set-Cookie": "wov_session=session-value-123; Path=/; HttpOnly; SameSite=Lax"]
        )!

        XCTAssertEqual(PortalClient.webSessionCookieHeader(from: response), "wov_session=session-value-123")
        XCTAssertEqual(PortalClient.webSessionCookieValue(from: "session-value-123"), "wov_session=session-value-123")
    }

    func testQuickNotePayloadMatchesPortalContract() throws {
        let draft = QuickNoteDraft(
            noteText: "  Dock lights are out at Cedar House.  ",
            status: .needToAction,
            entityId: 17,
            propertyId: 44
        )
        let payload = QuickNoteCreatePayload(draft: draft)
        let data = try JSONEncoder.portalEncoder.encode(payload)
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]

        XCTAssertEqual(json?["noteText"] as? String, "Dock lights are out at Cedar House.")
        XCTAssertEqual(json?["status"] as? String, "need_to_action")
        XCTAssertEqual(json?["entityId"] as? Int, 17)
        XCTAssertEqual(json?["propertyId"] as? Int, 44)
    }

    func testDecodesReferenceRowsFromItemsPayload() throws {
        let data = """
        {
          "items": [
            { "id": 10, "name": "Cedar House", "entityId": 3 },
            { "id": 11, "displayName": "Fallback Name" }
          ]
        }
        """.data(using: .utf8)!

        let rows = try PortalClient.decodeReferences(from: data)
        XCTAssertEqual(rows.count, 2)
        XCTAssertEqual(rows[0], PortalReference(id: 10, name: "Cedar House", entityId: 3))
        XCTAssertEqual(rows[1], PortalReference(id: 11, name: "Fallback Name"))
    }

    func testDecodesCurrentUserFromNativeEnvelope() throws {
        let data = """
        {
          "data": {
            "user": {
              "id": 7,
              "email": "bart@example.com",
              "role": "staff",
              "firstName": "Bart",
              "lastName": "McDonough"
            }
          }
        }
        """.data(using: .utf8)!

        let user = try XCTUnwrap(PortalClient.decodeCurrentUser(from: data))
        XCTAssertEqual(user.displayName, "Bart McDonough")
        XCTAssertEqual(user.role, "staff")
    }

    func testDecodesQuickNotesFromNativeEnvelope() throws {
        let data = """
        {
          "data": [
            {
              "id": 31,
              "noteText": "Replace the lockbox batteries.",
              "status": "need_to_action",
              "entityId": null,
              "propertyId": 12,
              "propertyName": "Cedar House"
            }
          ],
          "meta": { "page": 1, "pageSize": 10, "total": 1 }
        }
        """.data(using: .utf8)!

        let notes = try PortalClient.decodeQuickNoteList(from: data)
        XCTAssertEqual(notes.count, 1)
        XCTAssertEqual(notes[0].noteText, "Replace the lockbox batteries.")
        XCTAssertEqual(notes[0].status, .needToAction)
        XCTAssertEqual(notes[0].propertyName, "Cedar House")
    }

    func testDecodesCreatedQuickNoteFromNativeEnvelope() throws {
        let data = """
        {
          "data": {
            "id": 32,
            "noteText": "Guest mentioned the hot tub panel is flickering.",
            "status": "information",
            "entityId": null,
            "propertyId": null
          }
        }
        """.data(using: .utf8)!

        let note = try PortalClient.decodeQuickNote(from: data)
        XCTAssertEqual(note.id, 32)
        XCTAssertEqual(note.status, .information)
    }
}
