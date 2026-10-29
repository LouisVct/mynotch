//
//  MediaRemoteArtworkFetcher.swift
//  boringNotch
//
//  Apple Music refuses to give the artwork of streamed tracks through AppleScript. macOS itself
//  knows it (MediaRemote), so we ask the bundled adapter for the current item's artwork once.
//

import Foundation

enum MediaRemoteArtworkFetcher {
    /// Returns the artwork macOS reports for the track with this title, or nil after ~3 s.
    static func fetchArtwork(forTitle title: String) async -> Data? {
        await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .utility).async {
                continuation.resume(returning: run(title: title))
            }
        }
    }

    private static func run(title: String) -> Data? {
        guard
            let scriptURL = Bundle.main.url(forResource: "mediaremote-adapter", withExtension: "pl"),
            let frameworkPath = Bundle.main.privateFrameworksPath?.appending("/MediaRemoteAdapter.framework")
        else { return nil }

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/perl")
        process.arguments = [scriptURL.path, frameworkPath, "stream", "--no-diff"]
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = FileHandle.nullDevice

        do { try process.run() } catch { return nil }

        // The stream never ends on its own: stop it after a few seconds so the read below returns
        DispatchQueue.global().asyncAfter(deadline: .now() + 3) {
            if process.isRunning { process.terminate() }
        }
        defer { if process.isRunning { process.terminate() } }

        let handle = pipe.fileHandleForReading
        var buffer = Data()
        while true {
            let chunk = handle.availableData
            if chunk.isEmpty { return nil }
            buffer.append(chunk)

            while let newline = buffer.firstIndex(of: 0x0A) {
                let line = buffer[buffer.startIndex..<newline]
                buffer.removeSubrange(buffer.startIndex...newline)

                guard let object = try? JSONSerialization.jsonObject(with: line) as? [String: Any],
                      let payload = object["payload"] as? [String: Any],
                      payload["title"] as? String == title,
                      let base64 = payload["artworkData"] as? String,
                      let data = Data(base64Encoded: base64.trimmingCharacters(in: .whitespacesAndNewlines)),
                      data.count > 64
                else { continue }
                return data
            }
        }
    }
}
