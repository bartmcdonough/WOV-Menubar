import Foundation
import XCTest
@testable import WOVMenubarCore

final class RealtimeEventFactoryTests: XCTestCase {
    func testSessionStartRequestsPortalRealtimeQuickNoteSession() throws {
        let event = RealtimeEventFactory.sessionStartEvent()
        XCTAssertEqual(event["type"] as? String, "quick_note.session.start")

        let session = try XCTUnwrap(event["session"] as? [String: Any])
        XCTAssertEqual(session["type"] as? String, "realtime")
        XCTAssertEqual(session["model"] as? String, "gpt-realtime-2")

        let audio = try XCTUnwrap(session["audio"] as? [String: Any])
        let input = try XCTUnwrap(audio["input"] as? [String: Any])
        XCTAssertEqual(input["format"] as? String, "pcm16")
        XCTAssertEqual(input["sampleRate"] as? Int, 24_000)

        let response = try XCTUnwrap(session["response"] as? [String: Any])
        XCTAssertEqual(response["modalities"] as? [String], ["text"])
    }

    func testAudioAppendEventUsesPortalRealtimeContract() throws {
        let event = RealtimeEventFactory.appendAudioEvent(base64Audio: "abc123")
        XCTAssertEqual(event["type"] as? String, "quick_note.audio.append")
        XCTAssertEqual(event["audio"] as? String, "abc123")
    }

    func testResponseCreateRequestsFinalQuickNoteText() throws {
        let event = RealtimeEventFactory.responseCreateEvent()
        XCTAssertEqual(event["type"] as? String, "quick_note.response.create")
        let response = try XCTUnwrap(event["response"] as? [String: Any])
        XCTAssertEqual(response["modalities"] as? [String], ["text"])
        XCTAssertEqual(response["max_output_tokens"] as? Int, 800)
    }

    func testPortalRealtimeWebSocketURLUsesPortalBaseURL() throws {
        let productionURL = try RealtimeNoteClient.webSocketURL(
            baseURL: URL(string: "https://portal.walkonvalley.com")!
        )
        XCTAssertEqual(productionURL.absoluteString, "wss://portal.walkonvalley.com/api/native/quick-notes/realtime")

        let localURL = try RealtimeNoteClient.webSocketURL(
            baseURL: URL(string: "http://localhost:5000/app")!
        )
        XCTAssertEqual(localURL.absoluteString, "ws://localhost:5000/app/api/native/quick-notes/realtime")
    }

    func testRealtimeClientEmitsAccumulatedTranscriptUpdates() async throws {
        let client = RealtimeNoteClient(
            settings: PortalSettings(),
            sessionCookie: "wov_session=test-session"
        )
        let updates = await client.updates()
        let collector = Task {
            var received: [RealtimeNoteLiveUpdate] = []
            for await update in updates {
                received.append(update)
                if received.count == 2 { break }
            }
            return received
        }

        await client.handleServerEvent(#"{"type":"quick_note.transcript.delta","delta":"Garage "}"#)
        await client.handleServerEvent(#"{"type":"quick_note.transcript.delta","delta":"cleanout"}"#)

        let received = await collector.value
        XCTAssertEqual(received, [
            .transcript("Garage "),
            .transcript("Garage cleanout")
        ])
    }

    func testRealtimeClientEmitsCompletedNoteUpdate() async throws {
        let client = RealtimeNoteClient(
            settings: PortalSettings(),
            sessionCookie: "wov_session=test-session"
        )
        let updates = await client.updates()
        let collector = Task {
            var received: [RealtimeNoteLiveUpdate] = []
            for await update in updates {
                received.append(update)
            }
            return received
        }

        await client.handleServerEvent("""
        {
          "type": "quick_note.note.done",
          "noteText": "Garage cleanout took three hours.",
          "transcript": "I spent three hours cleaning out the garage."
        }
        """)

        let received = await collector.value
        XCTAssertEqual(received, [
            .completed(RealtimeNoteResult(
                noteText: "Garage cleanout took three hours.",
                transcript: "I spent three hours cleaning out the garage."
            ))
        ])
    }
}
