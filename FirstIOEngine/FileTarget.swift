//
//  FileTarget.swift
//  FirstIOEngine
//
//  Created by Richard McNeal on 10/29/17.
//  Copyright © 2017 Richard McNeal. All rights reserved.
//

import Foundation

public enum FileErrors: Error {
	case openFailure(name:String, error_num:Int32)
	case statFailure(error_num:Int32)
	case invalidType
	case readFailure(block:Int64)
	case writeFailure(block:Int64)
}

enum FileMode {
	case RegFile
	case Dir
	case Block
	case Char
	case Link
	case Unknown
}

public class FileTarget {
	private var fileName:String
	private var fileFD:Int32 = 0
	private var statData:stat
	private var bufData:UnsafeMutablePointer<Int64>
	private var bufSize = 1024

	private var size:Int64 = 0
	var sizeStr:String {
		get {return ByteCountFormatter.string(fromByteCount: size, countStyle: .binary)}
		set(input) { size = convertHumanSize(input)}
	}
	func fileSize() -> Int64 { return size }
	
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
		bufData = UnsafeMutablePointer.allocate(capacity: bufSize)
		switch mode() {
		case .RegFile:
			print("Input is normal file")
		default:
			print("Invalid file")
			throw FileErrors.invalidType
		}
	}
	deinit {
		bufData.deallocate(capacity: bufSize)
		close(fileFD)
	}
	
	private func mode() -> FileMode {
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
	
	func prepFile() {
		if mode() == .RegFile {
			if statData.st_size > size {
				/* --- File exists and is larger than we need, we're done ---- */
				size = statData.st_size
				return
			}
			let bufHandle = FileHandle(fileDescriptor: fileFD)
			let bufSize = 1024
			var bufData = Data(capacity: bufSize)
			for pos in 0..<bufSize {
				bufData.append(UInt8(pos&0xff))
			}
			for _ in stride(from: 0, to: size, by: 1024) {
				bufHandle.write(bufData)
			}
			bufHandle.synchronizeFile()
			bufHandle.seek(toFileOffset: 0)
		}
	}
	func prepBuffers(max size:Int) {
		bufData.deallocate(capacity: bufSize)
		bufData = UnsafeMutablePointer.allocate(capacity: size)
		bufData.initialize(to: 0xbad_cafe_dead_beef, count: size / 8)
		bufSize = size
	}
	
	func doOp(request ior:ioRequest) throws {
		switch ior.op {
		case .FileRead:
			guard pread(fileFD, bufData, Int(ior.size), ior.block) == ior.size else {
				throw FileErrors.readFailure(block: ior.block)
			}
		case .FileWrite:
			guard pwrite(fileFD, bufData, Int(ior.size), ior.block) == ior.size else {
				throw FileErrors.writeFailure(block: ior.block)
			}
		default: print("Oops!")
		}
	}
}
