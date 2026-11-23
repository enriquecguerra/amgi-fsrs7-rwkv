//
//  RwkvEnvironment.swift
//  AnkiServices
//
//  Where RWKV scheduling (the FSRS7/RWKV Anki fork) finds its model and keeps
//  its state. Shared by every service that asks the bridge for RWKV scores.
//

package import AnkiBackend
import Foundation

public enum RwkvEnvironment {
    /// The bundled SM92 Curve checkpoint. The bridge pairs it with SM98
    /// in the adjacent directory. Previews, tests, and watchOS omit both.
    package static let modelPath: String? = Bundle.main.path(
        forResource: "weights.f32",
        ofType: "bin",
        inDirectory: "sm92"
    )

    /// The Small pair starts with the Windows default on existing installs
    /// and on new installs. The previous Big model used a separate key.
    public static let precisionKey = "rwkvSmallStatePrecision"
    public static let defaultPrecision = "cards_int4_notes_int8"

    package static var precision: String {
        UserDefaults.standard.string(forKey: precisionKey) ?? defaultPrecision
    }

    /// The persisted model state lives beside the collection it describes.
    package static func cacheDir(_ backend: AnkiBackend) -> String? {
        backend.currentCollectionPath.map {
            URL(fileURLWithPath: $0)
                .deletingLastPathComponent()
                .appendingPathComponent("rwkv-state-cache", isDirectory: true)
                .path
        }
    }
}
