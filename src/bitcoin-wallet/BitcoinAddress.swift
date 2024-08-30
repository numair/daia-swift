import Foundation
import BitcoinCrypto
import BitcoinBase

public struct BitcoinAddress: CustomStringConvertible {

    public let isMainnet: Bool
    public let isScript: Bool
    public let hash: Data

    public init(_ publicKey: PublicKey, mainnet: Bool = true) {
        isMainnet = mainnet
        isScript = false
        hash = hash160(publicKey.data)
    }

    public init(_ script: BitcoinScript, mainnet: Bool = true) {
        precondition(script.sigVersion == .base)
        isMainnet = mainnet
        isScript = true
        hash = hash160(script.data)
    }

    public init?(_ address: String) {
        // Decode P2PKH address
        guard let data = Base58Decoder().decode(address),
              let versionByte = data.first,
              versionByte == base58VersionMain || versionByte == base58VersionTest || versionByte == base58VersionScriptMain || versionByte == base58VersionScriptTest
        else { return nil }
        isMainnet = versionByte == base58VersionMain || versionByte == base58VersionScriptMain
        isScript = versionByte == base58VersionScriptMain || versionByte == base58VersionScriptTest
        hash = data.dropFirst()
    }

    public var description: String {
        var data = Data()
        if isScript {
            data.appendBytes(isMainnet ? base58VersionScriptMain : base58VersionScriptTest)
        } else {
            data.appendBytes(isMainnet ? base58VersionMain : base58VersionTest)
        }
        data.append(hash)
        return Base58Encoder().encode(data)
    }
}

/// Base58-check version for encoding public keys into addresses.
private let base58VersionMain = UInt8(0x00)
private let base58VersionTest = UInt8(0x6f) // 111

/// BIP13: Base58-check version for encoding scripts into addresses.
private let base58VersionScriptMain = UInt8(0x05)
private let base58VersionScriptTest = UInt8(0xc4) // 196