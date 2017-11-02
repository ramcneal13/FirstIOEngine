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
	private var reporter:StatReporter?
	/* ---- Number of threads to start for asynchronous I/O ---- */
	var ioDepth = 8
	
	var runTimeStr:String {
		get {return formatter.string(from: runTime)!}
		set(input) { runTime = convertTimeStr(input)}
	}
	private var target:FileTarget
	
	init(_ t:FileTarget, _ verbose:Bool = false) {
		target = t
		formatter.unitsStyle = .full
		formatter.includesApproximationPhrase = true
		formatter.includesTimeRemainingPhrase = false
		formatter.allowedUnits = [.minute, .second, .hour, .day]
		pattern = AccessPattern(size: target.fileSize())
		if verbose {
			reporter = StatReporter()
		}
	}
	deinit {
		reporter?.stop()
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
		let runQ = DispatchQueue(label: "runners", attributes: .concurrent)
		runnerLoop = true
		var jobs = [Runner]()
		let onceASec = SynchronizedArray<Int64>(q: runQ)
		let statSema = DispatchSemaphore(value: 0)
		let throughput = Throughput(ioDepth)
		
		runQ.async {
			while self.runnerLoop {
				// Once a second the Runner's will append a byte count to the 'onceASec'
				// array. Once the samples have been collected (same number of samples
				// as Runners) display the current throughput.
				
				statSema.wait()
				onceASec.remove(at: 0, async: false) { b in throughput.add(count: b) }
			}
		}
		for i in 0..<ioDepth {
			let r = Runner(pattern: self.pattern, target: self.target, id: String(i))
			jobs.append(r)
			runQ.async {
				r.start(array: onceASec, sema: statSema, report: self.reporter)
			}
		}
		let commSema = DispatchSemaphore(value: 0)
		runQ.asyncAfter(deadline: .now() + runTime) {
			self.runnerLoop = false
			commSema.signal()
		}
		commSema.wait()
		print("\nTime expired, waiting for jobs to complete")
		/* ---- give signal to jobs to stop ---- */
		for j in jobs {
			j.stop(sema: commSema)
		}
		/* ---- wait for the jobs to post a signal to the semaphore ---- */
		for _ in jobs {
			commSema.wait()
		}
		reporter?.stop()
		if let r = reporter {
			r.dumpStats(runtime: Int64(runTime))
		} else {
			print("\n")
		}
	}
	
}

class Throughput {
	private var runQ:DispatchQueue
	private var totalBytes:Int64 = 0
	private var runnerCount = 0
	private var runnersSeen = 0
	private let dateFormat = DateFormatter()
	private let startTime:Date = Date()
	
	init(_ r:Int) {
		runQ = DispatchQueue(label: "throughput", attributes: .concurrent)
		runnerCount = r
		dateFormat.dateStyle = .none
		dateFormat.timeStyle = .medium
		print("---- \(startTime) ----")
	}
	func add(count:Int64) {
		totalBytes += count
		runnersSeen += 1
		if runnersSeen == runnerCount {
			runnersSeen = 0
			let message = ByteCountFormatter.string(fromByteCount: totalBytes,
			                                        countStyle: .binary)

			let elapsedTime = Date().timeIntervalSince(startTime)
			print(String(format: "[%@] ", elapsedTime.stringTime), terminator: "")
			print(String(format: "Throughput: %@   ", message), terminator: "\r")
			fflush(stdout)
			totalBytes = 0
		}
	}
}

class Runner {
	private var pattern:AccessPattern
	private var target:FileTarget
	private var runQ:DispatchQueue
	private var runnerLoop = false
	private var idStr:String
	private var bytes:Int64 = 0
	private var sema:DispatchSemaphore?
	
	private var ticker: DispatchSourceTimer?
	private var last:Int64 = 0
	
	init(pattern:AccessPattern, target:FileTarget, id:String) {
		self.pattern = pattern
		runQ = DispatchQueue(label: "Runner", attributes: .concurrent)
		self.target = target
		idStr = id
	}
	
	func startTimer(_ array:SynchronizedArray<Int64>, _ sema:DispatchSemaphore) {
		ticker = DispatchSource.makeTimerSource(flags: [], queue: runQ)
		ticker?.schedule(deadline: .now(), repeating: .seconds(1))
		ticker?.setEventHandler {
			// This is not atomic and could produce unexpected results.
			let b = self.bytes
			array.append(b - self.last)
			self.last = b
			sema.signal()
		}
		ticker?.resume()
	}
	
	func start(array:SynchronizedArray<Int64>, sema:DispatchSemaphore, report:StatReporter?) {
		var last:Int64 = 0
		runnerLoop = true
		startTimer(array, sema)
		while runnerLoop {
			let ior = pattern.gen(lastBlk: last)
			last = ior.block
			var s = Stats(op: .None, latency: 0, block: 0, size: 0)
			do {
				try s.latency = timeBlockWithMachThrow { try target.doOp(request: ior) }
			} catch {
				runnerLoop = false
			}
			s.op = ior.op
			s.block = ior.block
			s.size = ior.size
			report?.sendStat(entry: s)
			bytes += Int64(ior.size)
		}
		self.sema?.signal()
	}
	
	func stop(sema: DispatchSemaphore) {
		self.sema = sema
		runnerLoop = false
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
