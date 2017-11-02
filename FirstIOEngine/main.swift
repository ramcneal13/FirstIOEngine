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

func usage() {
	print(String(format: "Usage: %@ -f=<filename> -d=<io-depth> -p=<pattern> -t=<time> [-s=<size> -v]", commandName))
}

var commandName:String = ""
func main() {
	var skipFirst = true, verbose = false
	var configStr = ""
	var parser:ParseINIConfig?
	
	for arg in CommandLine.arguments {
		if skipFirst {
			skipFirst = false
			commandName = arg
			continue
		}
		switch arg.split(separator: "=")[0] {
		case "-c": processArg(arg) { c in configStr = c }
		default:
			print("Unknown argument '\(arg)'")
			exit(1)
		}
	}
	do {
		try parser = ParseINIConfig(name: configStr)
	} catch FileErrors.openFailure(let fileName, let e) {
		print("Failed to open \(fileName), errno=\(e)")
		exit(1)
	} catch {
		print("Some other odd error occurred")
		exit(1)
	}
	if parser?.parse() == false {
		exit(1)
	}
	parser?.setParam(section: "global", param: "verbose") { _ in verbose = true }

	if let jobList = parser?.requestJobs() {
		for jobName in jobList {
			var fileName = ""
			parser?.setParam(section: jobName, param: "name") { f in fileName = f }
			var f:FileTarget
			do {
				try f = FileTarget(name: fileName)
			} catch {
				print("Failed to open: \(fileName)")
				exit(1)
			}
			parser?.setParam(section: jobName, param: "size") { s in f.sizeStr = s }
			if f.prepFile() == false {
				print("Failed to prep \(fileName), probably invalid size")
				exit(1)
			}
			let job = JobAction(f, verbose)
			parser?.setParam(section: jobName, param: "pattern") { v in job.setPattern(v)}
			parser?.setParam(section: jobName, param: "runtime") { v in job.runTimeStr = v}
			parser?.setParam(section: jobName, param: "iodepth") { v in
				if let iodepth = Int(v) {
					job.ioDepth = iodepth
				} else {
					job.ioDepth = 1
				}
			}
			print(String(format: "Size: %@, Runtime: %@, Pattern: %@, IODepth: %d", f.sizeStr, job.runTimeStr,
				     job.getPattern(), job.ioDepth))
			if job.isValid() {
				job.execute()
			} else {
				print("One of the params is preventing job from starting")
			}
		}
	}
}

main()
