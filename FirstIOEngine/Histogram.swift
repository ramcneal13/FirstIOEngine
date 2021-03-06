//
//  Histogram.swift
//  FirstIOEngine
//
//  Created by Richard McNeal on 11/2/17.
//  Copyright © 2017 Richard McNeal. All rights reserved.
//

import Foundation

precedencegroup PowerPrecedence { higherThan: MultiplicationPrecedence }
infix operator ^^ : PowerPrecedence
func ^^ (radix: Int, power: Int) -> Int {
	return Int(pow(Double(radix), Double(power)))
}

public class Histogram {
	private var Bins:[Int64]
	
	init() {
		Bins = [Int64](repeating: 0, count: 64)
	}
	
	func tally(t:TimeInterval) {
		var ms = t.microseconds
		for i in 0..<64 {
			ms >>= 1
			if ms == 0 {
				Bins[i] += 1
				return
			}
		}
		Bins[64] += 1
	}
	
	func display() {
		var firstIdx:Int = 0, lastIdx = 0
		var largestCount:Int64 = 0
		for (k, v) in Bins.enumerated() {
			if v != 0 && firstIdx == 0 {
				firstIdx = k
			}
			if v > largestCount {
				largestCount = v
			}
			if v != 0 {
				lastIdx = k
			}
		}
		let winsz = getwinsize()
		var tv:TimeInterval = 0
		tv.microseconds = 2 ^^ lastIdx
		let binColumn = String(format: "%@", tv.stringTime).count
		let countColumn = String(format: "%d", largestCount).count
		let scalerCol = Int(winsz) - binColumn - countColumn - 2
		var scaler = largestCount / Int64(scalerCol)
		if (largestCount / scaler) > scalerCol {
			scaler += 1
		}

		dashLine(count: scalerCol, offset: binColumn)
		for (k, v) in Bins.enumerated() {
			if k >= firstIdx && k <= lastIdx {
				tv.microseconds = 2 ^^ k
				print(String(format: "%*s|", binColumn, strToUnsafe(tv.stringTime)!), terminator: "")
				for _ in 0..<(v/scaler) {
					print("@", terminator: "")
				}
				for _ in 0..<(scalerCol - Int(v/scaler)) {
					print(" ", terminator: "")
				}
				print(String(format: "|%*d", countColumn, v))
			}
		}
		dashLine(count: scalerCol, offset: binColumn)
	}
	
	private func dashLine(count:Int, offset:Int = 0) {
		if offset != 0 {
			print(String(format: "%*s", offset, strToUnsafe(" ")!), terminator: "")
		}
		print("+", terminator: "")
		for _ in 0..<count { print("-", terminator: "") }
		print("+")
	}
}
