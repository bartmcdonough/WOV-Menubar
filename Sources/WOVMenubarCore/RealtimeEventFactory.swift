import Foundation

public enum RealtimeEventFactory {
    public static let model = "gpt-realtime-2"

    public static func sessionStartEvent() -> [String: Any] {
        [
            "type": "quick_note.session.start",
            "session": [
                "type": "realtime",
                "model": model,
                "audio": [
                    "input": [
                        "format": "pcm16",
                        "sampleRate": 24_000
                    ]
                ],
                "response": [
                    "modalities": ["text"]
                ],
                "instructions": """
                You turn spoken field notes for Walk On Valley Properties into concise Portal Quick Notes.
                Return only the note text to save. Preserve owner, property, guest, vendor, task, date,
                and follow-up details that the speaker says. Do not invent missing names, IDs, or commitments.
                """
            ] as [String: Any]
        ]
    }

    public static func appendAudioEvent(base64Audio: String) -> [String: Any] {
        [
            "type": "quick_note.audio.append",
            "audio": base64Audio
        ]
    }

    public static func commitAudioEvent() -> [String: Any] {
        ["type": "quick_note.audio.commit"]
    }

    public static func responseCreateEvent() -> [String: Any] {
        [
            "type": "quick_note.response.create",
            "response": [
                "modalities": ["text"],
                "instructions": "Create the final Quick Note text from the recorded audio. Return only the note text.",
                "max_output_tokens": 800
            ] as [String: Any]
        ]
    }

    public static func cancelResponseEvent() -> [String: Any] {
        ["type": "quick_note.session.cancel"]
    }

    public static func encode(_ event: [String: Any]) throws -> String {
        let data = try JSONSerialization.data(withJSONObject: event, options: [])
        guard let text = String(data: data, encoding: .utf8) else {
            throw WOVMenubarError.invalidResponse
        }
        return text
    }
}
