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
	var latency:UInt64
	var block:Int64
	var size:Int
}


class StatReporter {
	private var commChannel:SynchronizedArray<Stats>
	private var commSemq:DispatchSemaphore
	private var statQ:DispatchQueue
	private var doLoop = true
	
	private var ioReads:Int64 = 0
	private var ioWrites:Int64 = 0
	private var bytesRead:Int64 = 0
	private var bytesWrite:Int64 = 0
	private var lowLatRead:UInt64 = 0xbad_cafe_dead_beef
	private var avgLatRead:UInt64 = 0
	private var highLatRead:UInt64 = 0
	private var lowLatWrite:UInt64 = 0xbad_cafe_dead_beef
	private var avgLatWrite:UInt64 = 0
	private var highLatWrite:UInt64 = 0
	
	init() {
		statQ = DispatchQueue(label: "Stat Information", attributes: .concurrent)
		commSemq = DispatchSemaphore(value: 0)
		commChannel = SynchronizedArray<Stats>(q: statQ)
		statQ.async {
			while self.doLoop {
				self.commSemq.wait()
				self.commChannel.remove(at: 0, completion: self.gatherStats)
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
		statQ.async(flags: .barrier) {
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
				return
			}
		}
	}
	
	func dumpStats() {
		print(String(format: "Channel: count=%d, capacity=%d", commChannel.count, commChannel.capacity))
		var msg = String(format: "Read: low=%d/avg=%d/high=%d", lowLatRead, avgLatRead / UInt64(ioReads),
		                 highLatRead)
		print(msg)
		msg = String(format: "Write: low=%d/avg=%d/high=%d", lowLatWrite, avgLatWrite / UInt64(ioWrites),
		             highLatWrite)
		print(msg)
	}
}
