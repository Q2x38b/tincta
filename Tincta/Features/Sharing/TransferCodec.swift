import Foundation
import SwiftData
import Compression

/// Encodes/decodes `RecipeTransfer` to a URL-safe string token, and imports
/// payloads into a SwiftData context. Pure functions only — no UI here.
enum TransferCodec {

    // MARK: - Encoding

    /// Build a transfer envelope from live SwiftData recipes and serialize it
    /// to a URL-safe base64 token suitable for embedding in a link.
    @MainActor
    static func encode(recipes: [Recipe]) throws -> String {
        let payload = RecipeTransfer(
            recipes: recipes.map(RecipePayload.init(recipe:))
        )
        return try encode(transfer: payload)
    }

    /// Serialize an already-built envelope. Tries to compress the JSON with
    /// zlib first; falls back to raw JSON if compression fails. The result is
    /// URL-safe base64 with a 1-byte version header (`0x01` raw, `0x02` zlib).
    static func encode(transfer: RecipeTransfer) throws -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        let json = try encoder.encode(transfer)

        var bytes: [UInt8]
        if let compressed = zlibCompress(json) {
            bytes = [Header.zlib.rawValue]
            bytes.append(contentsOf: compressed)
        } else {
            bytes = [Header.raw.rawValue]
            bytes.append(contentsOf: json)
        }
        return urlSafeBase64(Data(bytes))
    }

    // MARK: - Decoding

    /// Decode a URL-safe base64 token back into a `RecipeTransfer`. Returns
    /// nil on any malformed input; throws only when the bytes parse cleanly
    /// but the schema version is unsupported.
    static func decode(_ encoded: String) throws -> RecipeTransfer {
        let trimmed = encoded.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, let data = decodeURLSafeBase64(trimmed), !data.isEmpty else {
            throw RecipeTransferError.malformedPayload
        }

        let header = data[data.startIndex]
        let body = data.dropFirst()

        let json: Data
        switch Header(rawValue: header) {
        case .raw:
            json = Data(body)
        case .zlib:
            guard let inflated = zlibDecompress(Data(body)) else {
                throw RecipeTransferError.malformedPayload
            }
            json = inflated
        case nil:
            // No recognized header — treat the whole blob as raw JSON for
            // forward compatibility with older shares that pre-date framing.
            json = data
        }

        let decoder = JSONDecoder()
        let transfer: RecipeTransfer
        do {
            transfer = try decoder.decode(RecipeTransfer.self, from: json)
        } catch {
            throw RecipeTransferError.malformedPayload
        }

        guard transfer.schemaVersion <= RecipeTransfer.currentSchemaVersion else {
            throw RecipeTransferError.unsupportedSchemaVersion(
                found: transfer.schemaVersion,
                supported: RecipeTransfer.currentSchemaVersion
            )
        }
        guard !transfer.recipes.isEmpty else {
            throw RecipeTransferError.emptyPayload
        }
        return transfer
    }

    // MARK: - Import

    /// Insert the transfer's recipes as brand-new entities. Always assigns
    /// fresh UUIDs so multiple imports of the same link never collide. Returns
    /// the inserted recipes (in payload order) so the UI can react.
    @MainActor
    @discardableResult
    static func importPayload(
        _ payload: RecipeTransfer,
        into context: ModelContext
    ) throws -> [Recipe] {
        var inserted: [Recipe] = []
        inserted.reserveCapacity(payload.recipes.count)

        for recipePayload in payload.recipes {
            let recipe = Recipe(
                id: UUID(),
                name: recipePayload.name,
                directions: recipePayload.directions,
                backgroundColorHex: recipePayload.backgroundColorHex,
                credit: recipePayload.credit,
                groupTags: recipePayload.groupTags,
                createdAt: .now,
                updatedAt: .now
            )
            context.insert(recipe)

            // Map source-payload ingredient UUIDs → newly-inserted Ingredient
            // UUIDs so that SizePayload.amounts (which references the source
            // ids) can be re-pointed at the freshly created Ingredient rows.
            var ingredientIDMap: [UUID: UUID] = [:]
            for ingredientPayload in recipePayload.ingredients {
                let newID = UUID()
                ingredientIDMap[ingredientPayload.id] = newID
                let ingredient = Ingredient(
                    id: newID,
                    quantityWhole: ingredientPayload.quantityWhole,
                    fraction: ingredientPayload.fractionRaw.flatMap(Fraction.init(rawValue:)),
                    unit: Unit(rawValue: ingredientPayload.unitRaw) ?? .oz,
                    name: ingredientPayload.name,
                    order: ingredientPayload.order
                )
                ingredient.recipe = recipe
                context.insert(ingredient)
            }

            if let lookPayload = recipePayload.drinkLook {
                let look = DrinkLook(
                    id: UUID(),
                    vessel: Vessel(rawValue: lookPayload.vesselRaw) ?? .rocks,
                    drinkColorHex: lookPayload.drinkColorHex,
                    ice: lookPayload.iceRaw.flatMap(IceType.init(rawValue:)),
                    citrus: lookPayload.citrusRaw.compactMap(Citrus.init(rawValue:)),
                    garnishes: lookPayload.garnishRaw.compactMap(Garnish.init(rawValue:)),
                    extras: lookPayload.extrasRaw.compactMap(Extra.init(rawValue:))
                )
                look.recipe = recipe
                context.insert(look)
            }

            // Sizes — optional in the wire schema, so older payloads will
            // simply skip this loop. Each SizeAmount references an
            // ingredient by its source-payload UUID; remap via the table
            // we just built so the override points at the right row.
            if let sizePayloads = recipePayload.sizes {
                for sizePayload in sizePayloads {
                    let size = RecipeSize(
                        id: UUID(),
                        name: sizePayload.name,
                        sortOrder: sizePayload.sortOrder,
                        isDefault: sizePayload.isDefault
                    )
                    size.recipe = recipe
                    context.insert(size)

                    for amountPayload in sizePayload.amounts {
                        guard let mappedIngredientID = ingredientIDMap[amountPayload.ingredientID] else {
                            // Orphaned override — silently skip rather than
                            // attaching it to a missing ingredient.
                            continue
                        }
                        let amount = SizeAmount(
                            id: UUID(),
                            ingredientID: mappedIngredientID,
                            quantityWhole: amountPayload.quantityWhole,
                            fraction: amountPayload.fractionRaw.flatMap(Fraction.init(rawValue:))
                        )
                        amount.size = size
                        context.insert(amount)
                    }
                }
            }

            inserted.append(recipe)
        }

        try context.save()
        return inserted
    }

    // MARK: - Link helpers

    /// Custom URL scheme owned by the Tincta app via its Info.plist
    /// CFBundleURLTypes. Used for the only deep-link form we generate now —
    /// HTTPS universal links are intentionally not produced since no domain
    /// is owned to back them.
    static let customScheme: String = "tincta"

    /// Builds the only share link form: `tincta://import?data=<token>`.
    /// Other people who have Tincta installed will open it directly; people
    /// without Tincta should be given the raw token to paste in via the
    /// in-app "Paste Code" entry.
    static func customSchemeLink(forToken token: String) -> URL? {
        var components = URLComponents()
        components.scheme = customScheme
        components.host = "import"
        components.queryItems = [URLQueryItem(name: "data", value: token)]
        return components.url
    }

    // MARK: - Framing

    private enum Header: UInt8 {
        case raw  = 0x01
        case zlib = 0x02
    }

    // MARK: - URL-safe base64

    private static func urlSafeBase64(_ data: Data) -> String {
        data.base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }

    private static func decodeURLSafeBase64(_ string: String) -> Data? {
        var s = string
            .replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")
        // Re-pad to a multiple of 4.
        let pad = (4 - s.count % 4) % 4
        s.append(String(repeating: "=", count: pad))
        return Data(base64Encoded: s)
    }

    // MARK: - zlib via Compression framework

    private static func zlibCompress(_ input: Data) -> Data? {
        compressionTransform(input, operation: COMPRESSION_STREAM_ENCODE)
    }

    private static func zlibDecompress(_ input: Data) -> Data? {
        compressionTransform(input, operation: COMPRESSION_STREAM_DECODE)
    }

    private static func compressionTransform(
        _ input: Data,
        operation: compression_stream_operation
    ) -> Data? {
        guard !input.isEmpty else { return Data() }

        let streamPtr = UnsafeMutablePointer<compression_stream>.allocate(capacity: 1)
        defer { streamPtr.deallocate() }
        var status = compression_stream_init(streamPtr, operation, COMPRESSION_ZLIB)
        guard status == COMPRESSION_STATUS_OK else { return nil }
        defer { compression_stream_destroy(streamPtr) }

        let bufferSize = 64 * 1024
        let dstBuffer = UnsafeMutablePointer<UInt8>.allocate(capacity: bufferSize)
        defer { dstBuffer.deallocate() }

        var output = Data()
        let result: Data? = input.withUnsafeBytes { (rawBuf: UnsafeRawBufferPointer) -> Data? in
            guard let baseAddress = rawBuf.baseAddress else { return nil }
            streamPtr.pointee.src_ptr = baseAddress.assumingMemoryBound(to: UInt8.self)
            streamPtr.pointee.src_size = input.count
            streamPtr.pointee.dst_ptr = dstBuffer
            streamPtr.pointee.dst_size = bufferSize

            while true {
                let flags = Int32(COMPRESSION_STREAM_FINALIZE.rawValue)
                status = compression_stream_process(streamPtr, flags)
                switch status {
                case COMPRESSION_STATUS_OK:
                    let produced = bufferSize - streamPtr.pointee.dst_size
                    if produced > 0 {
                        output.append(dstBuffer, count: produced)
                    }
                    streamPtr.pointee.dst_ptr = dstBuffer
                    streamPtr.pointee.dst_size = bufferSize
                case COMPRESSION_STATUS_END:
                    let produced = bufferSize - streamPtr.pointee.dst_size
                    if produced > 0 {
                        output.append(dstBuffer, count: produced)
                    }
                    return output
                default:
                    return nil
                }
            }
        }
        return result
    }
}
