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
	}
}
