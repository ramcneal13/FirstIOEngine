//
//  utils.swift
//  FirstIOEngine
//
//  Created by Richard McNeal on 10/29/17.
//  Copyright © 2017 Richard McNeal. All rights reserved.
//

import Foundation

enum ConvertMultiplier {
	case TimeMultiplier(t:TimeInterval)
	case SizeMultiplier(s:Int64)
	case ConvertError
}

public func convertHumanSize(_ sizeStr:String) -> Int64 {
	var size:Int64 = 0
	for multiplier in "kmgtKMGT" {
		if sizeStr.hasSuffix(String(multiplier)) {
			let idx = sizeStr.index(of: multiplier)!
			var sm:ConvertMultiplier
			switch multiplier {
			case "k", "K": sm = .SizeMultiplier(s: 1024)
			case "m", "M": sm = .SizeMultiplier(s: 1024 * 1024)
			case "g", "G": sm = .SizeMultiplier(s: 1024 * 1024 * 1024)
			case "t", "T": sm = .SizeMultiplier(s: 1024 * 1024 * 1024 * 1024)
			default: sm = .ConvertError
			}
			switch sm {
			case .SizeMultiplier(s: let bytes):
				size = Int64(sizeStr.prefix(upTo: idx))! * bytes
			default:
				print("Bad size value '\(sizeStr)'")
			}
			return size
		}
	}
	if let sizeCheck = Int64(sizeStr) {
		size = sizeCheck
	}
	return size
}

public func convertTimeStr(_ runTimeStr:String) -> TimeInterval {
	var runTime:TimeInterval = 0
	for timeChar in "smhd" {
		if runTimeStr.hasSuffix(String(timeChar)) {
			let idx = runTimeStr.index(of: timeChar)!
			var tm:ConvertMultiplier
			switch timeChar {
			case "s": tm = .TimeMultiplier(t: 1)
			case "m": tm = .TimeMultiplier(t: 60)
			case "h": tm = .TimeMultiplier(t: 60 * 60)
			case "d": tm = .TimeMultiplier(t: 3600 * 24)
			default: tm = .ConvertError
			}
			switch tm {
			case .TimeMultiplier(t: let seconds):
				runTime = TimeInterval(runTimeStr.prefix(upTo: idx))! * seconds
			default:
				print("Bad runtime string '\(runTimeStr)'")
			}
			return runTime
		}
	}
	if let timeCheck = TimeInterval(runTimeStr) {
		runTime = timeCheck
	}
	return runTime
}

