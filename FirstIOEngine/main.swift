//
//  main.swift
//  FirstIOEngine
//
//  Created by Richard McNeal on 10/27/17.
//  Copyright © 2017 Richard McNeal. All rights reserved.
//

import Foundation

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
	f.sizeStr = "1g"
	f.prepFile()
	let job = JobAction(f)
	job.setPattern("100:rw:8k")
	job.runTimeStr = "1m"
	print("Size(\(f.sizeStr)), Runtime(\(job.runTimeStr)), Access(\(job.getPattern()))[\(job.isValid())]")
	job.execute()
}

main()
