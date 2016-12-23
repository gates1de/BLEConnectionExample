//
//  IMBLEReadResult.swift
//  BLEConnectionExample
//
//  Created by Yu Kadowaki on 12/24/16.
//  Copyright © 2016 gates1de. All rights reserved.
//

import Foundation

extension Data {
    func hexEncodedString() -> String {
        return map { String(format: "%02hhx", $0) }.joined()
    }
}

extension String {
    func index(from: Int) -> Index {
        return self.index(startIndex, offsetBy: from)
    }

    func substring(from: Int) -> String {
        let fromIndex = index(from: from)
        return substring(from: fromIndex)
    }

    func substring(to: Int) -> String {
        let toIndex = index(from: to)
        return substring(to: toIndex)
    }

    func substring(with range: CountableClosedRange<Int>) -> String {
        let startIndex = index(from: range.lowerBound)
        let endIndex = index(from: range.upperBound)
        return substring(with: startIndex..<endIndex)
    }
}

internal struct IMBLEReadResult {

    // MARK: - Private Property

    private var hexString: String?


    // MARK: - Internal Property

    var prefixString: String? {
        guard let hexString = hexString else {
            return nil
        }
        return hexString.substring(to: 8)
    }

    /// BLEモジュールから送信されたテキスト
    var text: String? {
        guard let hexString = hexString else {
            return nil
        }

        let textHexString = hexString.substring(with: 8...24)

        return hexToAscii(NSString(string: textHexString))
    }

    var suffixString: String? {
        guard let hexString = hexString else {
            return nil
        }
        return hexString.substring(from: 24)
    }


    // MARK: - Initializer

    init(data: Data) {
        self.hexString = data.hexEncodedString()
    }


    // MARK: - Private Method

    /// 16進数文字列をASCIIに変換
    private func hexToAscii(_ hexString: NSString) -> String? {
        guard let chars = hexString.utf8String else {
            return nil
        }

        let data = NSMutableData(capacity: hexString.length / 2)

        var i = 0
        while (i < hexString.length) {
            var byteChars: [CChar] = [0, 0]
            byteChars[0] = chars[i]
            byteChars[1] = chars[i + 1]

            var bytes = strtoul(byteChars, nil, 16)
            data?.append(&bytes, length: 1)
            i += 2
        }

        if let data = data {
            return String(bytes: data as Data, encoding: .utf8)?.replacingOccurrences(of: "\0", with: "")
        }

        return nil
    }
}
