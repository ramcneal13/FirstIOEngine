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

extension TimeInterval{
	var microseconds: Int { return Int((self.truncatingRemainder(dividingBy: 1)) * 1_000_000) }
	var seconds: Int { return Int(self.remainder(dividingBy: 60)) }
	var minutes: Int { return Int((self/60).remainder(dividingBy: 60)) }
	var hours: Int { return Int(self / (60*60)) }
	var stringTime: String {
		if self.hours != 0 {
			return String(format: "%dh%02dm%02ds", self.hours, self.minutes, self.seconds)
		} else if self.minutes != 0 {
			return String(format: "%dm%02ds.%06dus", self.minutes, self.seconds, self.microseconds)
		} else if self.microseconds != 0 {
			if self.microseconds < 1_000 {
				return String(format: "%dus", self.microseconds)
			} else {
				return String(format: "%d.%03dms", self.microseconds / 1_000,
					      self.microseconds % 1_000)
			}
		} else {
			return "\(self.seconds)s"
		}
	}
}

public func stringFromTime(interval: TimeInterval) -> String {
	let ms = Int(interval.truncatingRemainder(dividingBy: 1) * 1000)
	let formatter = DateComponentsFormatter()
	formatter.allowedUnits = [.hour, .minute, .second, .nanosecond]
	return formatter.string(from: interval)! + ".\(ms)"
}

public func timeBlockWithMach(_ block: () -> Void) -> TimeInterval {
	var info = mach_timebase_info()
	guard mach_timebase_info(&info) == KERN_SUCCESS else { return -1 }
	
	let start = mach_absolute_time()
	//Block execution to time!
	block()
	let end = mach_absolute_time()
	
	let elapsed = end - start
	
	let nanos = elapsed * UInt64(info.numer) / UInt64(info.denom)
	return TimeInterval(nanos) / TimeInterval(NSEC_PER_SEC)
}

public func timeBlockWithMachThrow(_ block: () throws -> Void) throws -> TimeInterval {
	var info = mach_timebase_info()
	guard mach_timebase_info(&info) == KERN_SUCCESS else { return -1 }
	
	let start = mach_absolute_time()
	//Block execution to time!
	try block()
	let end = mach_absolute_time()
	
	let elapsed = end - start
	
	let nanos = elapsed * UInt64(info.numer) / UInt64(info.denom)
	return TimeInterval(nanos) / TimeInterval(NSEC_PER_SEC)
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

