//
//  main.swift
//  FirstIOEngine
//
//  Created by Richard McNeal on 10/27/17.
//  Copyright © 2017 Richard McNeal. All rights reserved.
//

import Foundation

enum ConvertMultiplier {
	case TimeMultiplier(t:TimeInterval)
	case SizeMultiplier(s:Int64)
	case ConvertError
}
func convertHumanSize(from sizeStr:String) -> Int64 {
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

func convertTimeStr(from runTimeStr:String) -> TimeInterval {
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

enum FileErrors: Error {
	case openFailure(name:String, error_num:Int32)
	case statFailure(error_num:Int32)
	case invalidType
}

let formatter = DateComponentsFormatter()
formatter.unitsStyle = .full
formatter.includesApproximationPhrase = false
formatter.includesTimeRemainingPhrase = false
formatter.allowedUnits = [.minute]

enum FileMode {
	case RegFile
	case Dir
	case Block
	case Char
	case Link
	case Unknown
}

class FileTarget {
	private var fileName:String
	private var fileFD:Int32 = 0
	private var statData:stat

	private var runTime:TimeInterval = 0.0
	var runTimeStr:String {
		get {return formatter.string(from: runTime)!}
		set(input) { runTime = convertTimeStr(from: input)}
	}

	private var size:Int64 = 0
	var sizeStr:String {
		get {return ByteCountFormatter.string(fromByteCount: size, countStyle: .binary)}
		set(input) { size = convertHumanSize(from: input)}
	}
	
	init(name:String) throws {
		fileName = name
		fileFD = open(fileName, O_RDWR | O_CREAT, 0o666)
		if fileFD < 0 {
			throw FileErrors.openFailure(name: fileName, error_num: errno)
		}
		statData = stat()
		guard fstat(fileFD, &statData) == 0 else {
			throw FileErrors.statFailure(error_num: errno)
		}
		switch mode() {
		case .RegFile:
			print("Input is normal file")
		default:
			print("Invalid file")
			throw FileErrors.invalidType
		}
	}
	deinit {
		close(fileFD)
	}
	
	func mode() -> FileMode {
		let m = Int32(statData.st_mode) & Int32(S_IFMT)
		switch m {
		case Int32(S_IFREG): return .RegFile
		case Int32(S_IFDIR): return .Dir
		case Int32(S_IFBLK): return .Block
		case Int32(S_IFCHR): return .Char
		case Int32(S_IFLNK): return .Link
		default: return .Unknown
		}
	}
	
	func prep() {
		if mode() == .RegFile {
			if statData.st_size > size {
				/* --- File exists and is larger than we need, we're done ---- */
				size = statData.st_size
				return
			}
			let bufWrite = FileHandle(fileDescriptor: fileFD)
			let bufSize = 1024
			var buf = Data(capacity: bufSize)
			print("buf.count(\(buf.count))")
			for pos in 0..<bufSize {
				buf.append(UInt8(pos&0xff))
			}
			for _ in stride(from: 0, to: size, by: 1024) {
				bufWrite.write(buf)
			}
		}
	}
}

func main() {
	var f:FileTarget
	do {
		try f = FileTarget(name: "bohica")
	} catch FileErrors.openFailure(let fileName, let e) {
		print("Problems with '\(fileName)', errno=\(e)")
		return
	} catch {
		print("Unhandled system error")
		return
	}
	f.sizeStr = "1m"
	f.runTimeStr = "1h"
	f.prep()
	print("Size(\(f.sizeStr)), Runtime(\(f.runTimeStr))")
}

main()
