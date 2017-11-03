//
//  Stats.swift
//  FirstIOEngine
//
//  Created by Richard McNeal on 10/31/17.
//  Copyright © 2017 Richard McNeal. All rights reserved.
//

import Foundation

public struct Stats {
	var op:OpType
	var latency:TimeInterval
	var block:Int64
	var size:Int
}


class StatReporter {
	private var commChannel:SynchronizedArray<Stats>
	private var commSemq:DispatchSemaphore
	private var statQ:DispatchQueue
	private var doLoop = true
	private let histo:Histogram = Histogram()
	
	private var ioReads:Int64 = 0
	private var ioWrites:Int64 = 0
	private var bytesRead:Int64 = 0
	private var bytesWrite:Int64 = 0
	private var lowLatRead:TimeInterval = 1000.0
	private var avgLatRead:TimeInterval = 0.0
	private var highLatRead:TimeInterval = 0.0
	private var lowLatWrite:TimeInterval = 1000.0
	private var avgLatWrite:TimeInterval = 0.0
	private var highLatWrite:TimeInterval = 0.0
	
	init() {
		statQ = DispatchQueue(label: "Stat Information", attributes: .concurrent)
		commSemq = DispatchSemaphore(value: 0)
		commChannel = SynchronizedArray<Stats>(q: statQ)
		statQ.async {
			while self.doLoop {
				self.commSemq.wait()
				self.commChannel.remove(at: 0, async: true, completion: self.gatherStats)
			}
		}
	}
	
	func stop() { doLoop = false }
	func sendStat(entry e:Stats) {
		commChannel.append(e)
		commSemq.signal()
	}
	
	// Going with this for now, but there's a problem here which needs to
	// to be solved. This method is run asynchronously on the statQ. While
	// the SynchronizedArray protects access/modification to the array with
	// a .barrier directive. It doesn't provide barrier protection for the
	// closure.
	private func gatherStats(_ stat:Stats) {
		switch stat.op {
		case .FileRead:
			self.ioReads += 1
			self.bytesRead += Int64(stat.size)
			if self.lowLatRead > stat.latency {
				self.lowLatRead = stat.latency
			}
			if self.highLatRead < stat.latency {
				self.highLatRead = stat.latency
			}
			self.avgLatRead += stat.latency
		case .FileWrite:
			self.ioWrites += 1
			self.bytesWrite += Int64(stat.size)
			if self.lowLatWrite > stat.latency {
				self.lowLatWrite = stat.latency
			}
			if self.highLatWrite < stat.latency {
				self.highLatWrite = stat.latency
			}
			self.avgLatWrite += stat.latency
		default:
			print("Unknown op(\(stat.op))")
			return
		}
		histo.tally(t: stat.latency)
	}

	func dumpStats(runtime runTimeSeconds:Int64) {
		print("Summary:")
		/* ---- Prevent possible divide by zero ---- */
		if ioReads == 0 {
			ioReads = 1
		}
		let avgStr = "Avg throughput"
		let maxLabel = avgStr.count
		print(String(format: "  %*s: %@", maxLabel, strToUnsafe(avgStr)!,
			     ByteCountFormatter.string(fromByteCount: (bytesRead + bytesWrite) / runTimeSeconds,
						       countStyle: .binary)))

		var msg = String(format: "  %*s: low=%@/avg=%@/high=%@", maxLabel, strToUnsafe("Read")!,
				 lowLatRead.stringTime,
				TimeInterval(avgLatRead / TimeInterval(ioReads)).stringTime,
				highLatRead.stringTime)

		print(msg)
		
		if ioWrites == 0 {
			ioWrites = 1
		}
		msg = String(format: "  %*s: low=%@/avg=%@/high=%@", maxLabel, strToUnsafe("Write")!,
			     lowLatWrite.stringTime,
			     TimeInterval(avgLatWrite / TimeInterval(ioWrites)).stringTime,
		             highLatWrite.stringTime)
		print(msg)
		histo.display()
	}
}
