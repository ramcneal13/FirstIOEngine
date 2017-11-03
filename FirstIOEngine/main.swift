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
	parser?.setParam("global", "verbose") { _ in verbose = true }

	if let jobList = parser?.requestJobs() {
		for jobName in jobList {
			var fileName = ""
			parser?.setParam(jobName, "name") { f in fileName = f }
			var f:FileTarget
			do {
				try f = FileTarget(name: fileName)
			} catch {
				print("Failed to open: \(fileName)")
				exit(1)
			}
			parser?.setParam(jobName, "size") { s in f.sizeStr = s }
			if f.prepFile() == false {
				print("Failed to prep \(fileName), probably invalid size")
				exit(1)
			}
			let job = JobAction(f)
			parser?.setParam(jobName, "pattern") { v in job.patternStr = v}
			parser?.setParam(jobName, "runtime") { v in job.runTimeStr = v}
			parser?.setParam(jobName, "iodepth") { v in job.ioDepthStr = v}
			parser?.setParam(jobName, "verbose") { v in job.verboseStr = v}

			if verbose {
				print("[]---- \(jobName) ----[]")
				outputInColumn(array: ["Size":f.sizeStr, "RunTime":job.runTimeStr,
						       "Pattern":job.patternStr, "iodepth":job.ioDepthStr,
						       "File":fileName, "Verbose":job.verboseStr])
			}
			if job.isValid() {
				job.execute()
			} else {
				print("One of the params is preventing job from starting")
			}
		}
	}
}

func outputInColumn(array:[String:String]) {
	var maxName:Int = 0, maxValue:Int = 0
	
	for (k, v) in array {
		if maxName < k.count {
			maxName = k.count
		}
		if maxValue < v.count {
			maxValue = v.count
		}
	}
	for (k, v) in array {
		print(String(format: "%*s : %@", maxName, strToUnsafe(k)!, v))
	}
}
main()
