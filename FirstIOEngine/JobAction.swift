//
//  JobAction.swift
//  FirstIOEngine
//
//  Created by Richard McNeal on 10/29/17.
//  Copyright © 2017 Richard McNeal. All rights reserved.
//

import Foundation

public class JobAction {
	private var runTime:TimeInterval = 0.0
	private let formatter = DateComponentsFormatter()
	private var pattern = AccessPattern()
	/* ---- Number of threads to start for asynchronous I/O ---- */
	var ioDepth = 8
	
	var runTimeStr:String {
		get {return formatter.string(from: runTime)!}
		set(input) { runTime = convertTimeStr(input)}
	}
	private var target:FileTarget
	
	init(_ t:FileTarget) {
		target = t
		formatter.unitsStyle = .full
		formatter.includesApproximationPhrase = false
		formatter.includesTimeRemainingPhrase = false
		formatter.allowedUnits = [.minute]
	}
	func setPattern(_ s:String) {
		pattern.text = s
	}
	func getPattern() -> String {
		return pattern.text
	}
	/* ---- test for anything that might prevent JobAction from starting ---- */
	func isValid() -> Bool { return pattern.isValid() }
}

enum OpType {
	case RandRead
	case RandWrite
	case RandRW
	case None
}

struct accessEntry {
	var percentage:Int = 0
	var op:OpType = .None
	var blockSize:Int64 = 0
}

enum AccessEntryError: Error {
	case InvalidPatternCount
	case InvalidPercentage
	case InvalidOp
	case InvalidBlock
	case Over100Percent
}

class AccessPattern {
	var rawPattern:String = ""
	var valid:Bool = false
	var text:String {
		get {return rawPattern}
		set(newValue) {
			rawPattern = newValue
			do {
				try decodePattern()
				valid = true
			} catch {
				rawPattern = "Invalid Pattern"
				valid = false
			}
		}
	}
	var accessArray:[accessEntry]
	
	init() {
		accessArray = [accessEntry]()
	}

	func isValid() -> Bool { return valid }
	
	private func decodePattern() throws {
		/* --- Start over each time ---- */
		accessArray.removeAll()
		
		let totalPatterns = rawPattern.split(separator: ",")
		for pattern in totalPatterns {
			let tuple = pattern.split(separator: ":")
			var ae = accessEntry()
			if tuple.count != 3 {
				print("Invalid pattern \(pattern)")
				throw AccessEntryError.InvalidPatternCount
			}
			guard let per = Int(tuple[0]) else {
				throw AccessEntryError.InvalidPercentage
			}
			ae.percentage = per
			switch tuple[1] {
			case "randread": ae.op = .RandRead
			case "randwrite": ae.op = .RandWrite
			case "rw": ae.op = .RandRW
			default: throw AccessEntryError.InvalidOp
			}
			ae.blockSize = convertHumanSize(String(tuple[2]))
			accessArray.append(ae)
		}
		
		/* ---- Make sure total of patterns doesn't go over 100% ---- */
		var totalPer = 0
		for ae in accessArray {
			totalPer += ae.percentage
		}
		if totalPer > 100 {
			throw AccessEntryError.Over100Percent
		} else if totalPer < 100 {
			var ae = accessEntry()
			ae.percentage = 100 - totalPer
			ae.op = .None
			ae.blockSize = 0
			accessArray.append(ae)
		}
	}
}
