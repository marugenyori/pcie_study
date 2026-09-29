import Foundation

enum PCIeGen: Int, CaseIterable, Identifiable {
    case gen1 = 1, gen2, gen3, gen4, gen5, gen6, gen7

    var id: Int { rawValue }
    var name: String { "Gen\(rawValue)" }

    /// GT/s
    var rate: Double {
        switch self {
        case .gen1: return 2.5
        case .gen2: return 5
        case .gen3: return 8
        case .gen4: return 16
        case .gen5: return 32
        case .gen6: return 64
        case .gen7: return 128
        }
    }

    var encoding: String {
        switch self {
        case .gen1, .gen2: return "8b/10b"
        case .gen3, .gen4, .gen5: return "128b/130b"
        case .gen6, .gen7: return "1b/1b（PAM4 + FLIT）"
        }
    }

    var encodingEfficiency: Double {
        switch self {
        case .gen1, .gen2: return 8.0 / 10.0
        case .gen3, .gen4, .gen5: return 128.0 / 130.0
        case .gen6, .gen7: return 1.0
        }
    }

    var isFlit: Bool { self == .gen6 || self == .gen7 }

    /// FLIT 256B のうち TLP に使える割合（236/256）
    static let flitTLPRatio = 236.0 / 256.0
}

enum PCIeCalc {
    /// 片方向の帯域（GB/s）。符号化オーバーヘッドのみ考慮
    static func bandwidthGBps(gen: PCIeGen, lanes: Int) -> Double {
        gen.rate * gen.encodingEfficiency * Double(lanes) / 8.0
    }

    /// FLITのTLP領域まで考慮した片方向帯域（Gen6以降）
    static func flitTLPBandwidthGBps(gen: PCIeGen, lanes: Int) -> Double {
        bandwidthGBps(gen: gen, lanes: lanes) * (gen.isFlit ? PCIeGen.flitTLPRatio : 1)
    }

    /// 非FLITモードでの1 TLPあたりのオーバーヘッド（フレーミング + Seq# + LCRC）
    /// Gen1/2: STP(1) + Seq(2) + LCRC(4) + END(1) = 8
    /// Gen3-5: STPトークン(4, Seq#含む) + LCRC(4) = 8
    static let tlpFramingOverhead = 8

    /// TLPの転送効率（ペイロード / 総バイト）
    static func tlpEfficiency(payload: Int, headerBytes: Int, ecrc: Bool) -> Double {
        let total = payload + headerBytes + (ecrc ? 4 : 0) + tlpFramingOverhead
        return total == 0 ? 0 : Double(payload) / Double(total)
    }

    /// ECAMアドレス
    static func ecamAddress(base: UInt64, bus: Int, device: Int, function: Int, offset: Int) -> UInt64 {
        base
            + (UInt64(bus & 0xFF) << 20)
            + (UInt64(device & 0x1F) << 15)
            + (UInt64(function & 0x7) << 12)
            + UInt64(offset & 0xFFF)
    }

    /// ECAMオフセット（Base からの差分）を BDF + レジスタオフセットに分解
    static func decodeECAM(offset: UInt64) -> (bus: Int, device: Int, function: Int, register: Int) {
        (Int((offset >> 20) & 0xFF), Int((offset >> 15) & 0x1F), Int((offset >> 12) & 0x7), Int(offset & 0xFFF))
    }

    struct BARInfo {
        let isIO: Bool
        let is64Bit: Bool
        let prefetchable: Bool
        let size: UInt64
    }

    /// BARに全1を書いて読み戻した値からサイズと属性を求める（32ビットBAR/64ビットBARの下位）
    /// upper: 64ビットBARの場合の上位DWの読み戻し値（全1書き込み後）
    static func decodeBAR(readBack: UInt32, upper: UInt32? = nil) -> BARInfo? {
        if readBack & 0x1 == 1 {
            // I/O BAR：下位2ビットが属性
            let mask = readBack & 0xFFFF_FFFC
            guard mask != 0 else { return nil }
            let size = UInt64((~mask &+ 1) & 0xFFFF_FFFF)
            return BARInfo(isIO: true, is64Bit: false, prefetchable: false, size: size)
        }
        let type = (readBack >> 1) & 0x3
        let prefetch = (readBack >> 3) & 0x1 == 1
        let is64 = type == 0b10
        let lowMask = UInt64(readBack & 0xFFFF_FFF0)
        let combined: UInt64
        if is64 {
            let hi = UInt64(upper ?? 0xFFFF_FFFF)
            combined = (hi << 32) | lowMask
        } else {
            combined = 0xFFFF_FFFF_0000_0000 | lowMask
        }
        guard combined != 0xFFFF_FFFF_0000_0000, combined != 0 else { return nil }
        let size = ~combined &+ 1
        return BARInfo(isIO: false, is64Bit: is64, prefetchable: prefetch, size: size)
    }

    static func formatBytes(_ bytes: UInt64) -> String {
        let units: [(UInt64, String)] = [(1 << 40, "TB"), (1 << 30, "GB"), (1 << 20, "MB"), (1 << 10, "KB")]
        for (unit, name) in units where bytes >= unit {
            let v = Double(bytes) / Double(unit)
            return v == v.rounded() ? "\(Int(v)) \(name)" : String(format: "%.2f", v) + " " + name
        }
        return "\(bytes) B"
    }

    static func formatGBps(_ v: Double) -> String {
        if v < 1 { return String(format: "%.0f MB/s", v * 1000) }
        return String(format: "%.2f GB/s", v)
    }
}
