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
	private var pattern:AccessPattern
	private var runnerLoop = false
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
		pattern = AccessPattern(size: target.fileSize())
	}
	func setPattern(_ s:String) {
		pattern.text = s
	}
	func getPattern() -> String {
		return pattern.text
	}
	/* ---- test for anything that might prevent JobAction from starting ---- */
	func isValid() -> Bool { return pattern.isValid() }
	func execute() {
		target.prepBuffers(max: pattern.getMaxBlockSize())
		var queues = [DispatchQueue]()
		for idx in 0..<ioDepth {
			queues.append(DispatchQueue(label: "runner-" + String(idx), attributes: .concurrent))
		}
		runnerLoop = true
		for q in queues {
			q.async {
				self.runner(q.label)
			}
		}
		let pauseSema = DispatchSemaphore(value: 0)
		/*
		 * For some reason DispatchQueue.main.asyncAfter(.now() + runTime) { } isn't working.
		 * I checked this out in the Sandbox and saw the same issue. The event never fires.
		 * Yet creating my own queue and using the asyncAfter work which is what I'm doing
		 * here.
		 */
		let runTimeQ = DispatchQueue(label: "Runtime")
		runTimeQ.asyncAfter(deadline: .now() + runTime) {
			self.runnerLoop = false
			pauseSema.signal()
		}
		pauseSema.wait()
		print("Finished")
	}
	
	func reschedQ(_ id:String) {
		let statQ = DispatchQueue(label: "Stats-" + id)
		statQ.asyncAfter(deadline: .now() + 5.0) {
			print("Tick-" + id)
			self.reschedQ(id)
		}
	}
	func runner(_ id:String) {
		var last:Int64 = 0
		var bytes:Int64 = 0
		reschedQ(id)
		while runnerLoop {
			let ior = pattern.gen(lastBlk: last)
			last = ior.block
			do {
				try target.doOp(request: ior)
			} catch {
				runnerLoop = false
			}
			bytes += Int64(ior.size)
		}
	}
}

public enum OpType {
	case RandRead
	case RandWrite
	case RandRW
	case SeqRead
	case SeqWrite
	case None
	case FileRead
	case FileWrite
}

struct accessEntry {
	var percentage:Int = 0
	var op:OpType = .None
	var blockSize:Int = 0
	var start:Int64 = 0
	var len:Int64 = 0
}

enum AccessEntryError: Error {
	case InvalidPatternCount
	case InvalidPercentage
	case InvalidOp
	case InvalidBlock
	case Over100Percent
}

public struct ioRequest {
	var op:OpType
	var size:Int
	var block:Int64
}

class AccessPattern {
	var rawPattern:String = ""
	let fileSize:Int64
	var valid:Bool = false
	var largestBlockRequest = 0
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
	
	init(size s:Int64) {
		accessArray = [accessEntry]()
		fileSize = s
	}

	func isValid() -> Bool { return valid }
	func gen(lastBlk last:Int64) -> ioRequest {
		var r = Int(arc4random_uniform(100))
		for entry in accessArray {
			if r < entry.percentage {
				var newOp:OpType
				switch entry.op {
				case .RandRead, .SeqRead: newOp = .FileRead
				case .RandWrite, .SeqWrite: newOp = .FileWrite
				case .RandRW:
					switch arc4random_uniform(2) {
					case 0: newOp = .FileRead
					case 1: newOp = .FileWrite
					default: newOp = .None
					}
				default: newOp = .None
				}
				var blk:Int64
				switch entry.op {
				case .RandRead, .RandWrite, .RandRW:
					blk = Int64(arc4random_uniform(UInt32(entry.len) / UInt32(entry.blockSize))) *
						Int64(entry.blockSize)
				case .SeqRead, .SeqWrite: blk = last + 1
				default: blk = 0
				}
				return ioRequest(op: newOp, size: entry.blockSize, block: blk)
			}
			r -= entry.percentage
		}
		return ioRequest(op: .None, size: 0, block: 0)
	}
	
	func getMaxBlockSize() -> Int { return largestBlockRequest }
	private func decodePattern() throws {
		/* --- Start over each time ---- */
		accessArray.removeAll()

		let perSize = fileSize / 100
		var startBlock:Int64 = 0
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
			case "seqread": ae.op = .SeqRead
			case "seqwrite": ae.op = .SeqWrite
			default: throw AccessEntryError.InvalidOp
			}
			ae.blockSize = Int(convertHumanSize(String(tuple[2])))
			if largestBlockRequest < ae.blockSize {
				largestBlockRequest = ae.blockSize
			}
			ae.start = startBlock
			ae.len = perSize * Int64(ae.percentage)
			startBlock += ae.len
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
