//
//  main.swift
//  FirstIOEngine
//
//  Created by Richard McNeal on 10/27/17.
//  Copyright © 2017 Richard McNeal. All rights reserved.
//

import Foundation

func processArg(_ arg:String, complete:((String) -> Void)) {
	let iArg = arg.split(separator: "=")
	if iArg.count != 2 {
		print("Missing '=' for \(arg)")
		exit(1)
	}
	complete(String(iArg[1]))
}

func main() {
	var verbose = false, skipFirst = true
	var timeStr = ""
	var patternStr = ""
	var sizeStr = ""
	var fileStr = ""
	var iodepth:Int = 0
	
	for arg in CommandLine.arguments {
		if skipFirst {
			skipFirst = false
			continue
		}
		switch arg.split(separator: "=")[0] {
		case "-v": verbose = true
		case "-f": processArg(arg) { f in fileStr = f }
		case "-p": processArg(arg) { p in patternStr = p }
		case "-s": processArg(arg) { s in sizeStr = s }
		case "-t": processArg(arg) { t in timeStr = t }
		case "-d":
			processArg(arg) { d in
				if let v = Int(d) {
					iodepth = v
				}
			}
		default:
			print("Unknown argument '\(arg)'")
			exit(1)
		}
	}
	if verbose {
		print("[]---- FirstIOFIle ----[]")
	}
	var f:FileTarget
	do {
		try f = FileTarget(name: fileStr)
	} catch FileErrors.openFailure(let fileName, let e) {
		print("Problems with '\(fileName)', errno=\(e)")
		exit(1)
	} catch {
		print("Unhandled system error")
		exit(1)
	}
	f.sizeStr = sizeStr
	f.prepFile()
	let job = JobAction(f)
	job.setPattern(patternStr)
	job.runTimeStr = timeStr
	job.ioDepth = iodepth
	print(String(format: "Size: %@, Runtime: %@, Pattern: %@, IODepth: %d", f.sizeStr, job.runTimeStr,
	             job.getPattern(), job.ioDepth))
	if job.isValid() {
		job.execute()
	} else {
		print("One of the params is preventing job from starting")
	}
}

main()
