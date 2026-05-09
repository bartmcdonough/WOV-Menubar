# WOV Menubar

Native macOS menu bar app for recording Walk On Valley Quick Notes by voice and saving them to WOV-Portal.

The app is grounded in the current WOV-Portal Quick Notes API:

- `POST /api/auth/login` returns a `wov_session` cookie after username/password sign-in.
- `POST /api/quick-notes` accepts `noteText`, `status`, and optional `entityId` / `propertyId`.
- `GET /api/quick-notes`, `GET /api/entities`, and `GET /api/properties` populate the menu bar context.

Voice notes are mediated by Portal. The app captures microphone audio as PCM16 mono at 24 kHz and streams it to `wss://<portal-host>/api/native/quick-notes/realtime` with the existing `wov_session` cookie and `x-client-platform: macos`. Portal owns `OPENAI_API_KEY`, opens the OpenAI Realtime connection server-side, streams transcript deltas while recording, and returns the final Quick Note draft text after Stop.

## Portal Realtime API Contract

The menubar app expects a WebSocket endpoint at `/api/native/quick-notes/realtime`.

Handshake requirements:

- Authenticate with the `wov_session` cookie.
- Require `x-client-platform: macos`.
- Restrict access to `platform_admin` and `staff`, matching `/api/quick-notes`.
- Return a WebSocket close or `quick_note.error` event for missing auth, wrong role, missing `OPENAI_API_KEY`, or unavailable Realtime service.

Client events:

```json
{ "type": "quick_note.session.start", "session": { "type": "realtime", "model": "gpt-realtime-2", "audio": { "input": { "format": "pcm16", "sampleRate": 24000 } }, "response": { "modalities": ["text"] }, "instructions": "..." } }
{ "type": "quick_note.audio.append", "audio": "<base64 pcm16 chunk>" }
{ "type": "quick_note.audio.commit" }
{ "type": "quick_note.response.create", "response": { "modalities": ["text"], "instructions": "Create the final Quick Note text from the recorded audio. Return only the note text.", "max_output_tokens": 800 } }
{ "type": "quick_note.session.cancel" }
```

Server events:

```json
{ "type": "quick_note.note.delta", "delta": "partial note text" }
{ "type": "quick_note.transcript.delta", "delta": "partial transcript" }
{ "type": "quick_note.note.done", "noteText": "final note text", "transcript": "optional final transcript", "model": "gpt-realtime-2" }
{ "type": "quick_note.error", "message": "human-readable error" }
```

The app writes accumulated `quick_note.transcript.delta` text into the note editor while recording. After `quick_note.note.done`, it replaces the rough transcript with the final cleaned-up Quick Note draft. `quick_note.note.delta` is also supported for Portal implementations that stream a draft during finalization.

The app also tolerates raw forwarded OpenAI Realtime events such as `response.output_text.delta`, `response.output_text.done`, `conversation.item.input_audio_transcription.completed`, `response.done`, and `error`, but the normalized `quick_note.*` events above are preferred.

## Run

```bash
./script/build_and_run.sh
```

Useful modes:

```bash
./script/build_and_run.sh --verify
./script/build_and_run.sh --logs
./script/build_and_run.sh --telemetry
```

Portal sessions are stored in Keychain. The macOS app does not need or store an OpenAI API key.

## Release

Release builds use Developer ID signing, Apple notarization, and Sparkle EdDSA update signatures. The release machine needs:

- `DEVELOPER_ID_APPLICATION`: Developer ID Application signing identity.
- `NOTARYTOOL_PROFILE`: keychain profile for `xcrun notarytool` (defaults to `wov-portal-notary`).
- `SPARKLE_PUBLIC_ED_KEY`: public Sparkle EdDSA key embedded in `Info.plist`.
- Sparkle private key in Keychain, or `SPARKLE_PRIVATE_KEY_FILE` pointing to the private key file.

Create a release package:

```bash
./script/package_release.sh \
  --version 0.1.0 \
  --build 1 \
  --release-notes "Initial WOV Quick Notes release"
```

For local packaging checks without Developer ID credentials:

```bash
./script/package_release.sh \
  --version 0.1.0 \
  --build 1 \
  --sparkle-public-ed-key <public-key> \
  --ad-hoc \
  --no-notarize
```

The script emits `WOVQuickNotes-<version>.dmg`, `WOVQuickNotes-<version>.zip`, and `release-manifest.json` under `dist/releases/<version>/`. Upload those three files to the Portal Mac App page. The DMG is for the authenticated Portal download, and the ZIP is the Sparkle update archive.
