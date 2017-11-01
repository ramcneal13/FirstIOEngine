//
//  QueueSupport.swift
//  FirstIOEngine
//
//  Created by Richard McNeal on 10/30/17.
//  Copyright © 2017 Richard McNeal. All rights reserved.
//
// This code was found on the web and I've pretty much just copied
// it sense it does what I want. Here's the Author data that I have.
// MARCH 1, 2017 BY BASEM EMARA

import Foundation

/* ---- A thread-safe array. ---- */
public class SynchronizedArray<Element> {
	fileprivate let queue = DispatchQueue(label: "io.zamzam.ZamzamKit.SynchronizedArray", attributes: .concurrent)
	fileprivate var array = [Element]()
	fileprivate var alternateQ:DispatchQueue?
	init(q:DispatchQueue) {
		alternateQ = q
	}
}

/* ---- MARK: - Properties ---- */
public extension SynchronizedArray {
	
	/// The first element of the collection.
	var first: Element? {
		var result: Element?
		queue.sync { result = self.array.first }
		return result
	}
	
	/// The last element of the collection.
	var last: Element? {
		var result: Element?
		queue.sync { result = self.array.last }
		return result
	}
	
	/// The number of elements in the array.
	var count: Int {
		var result = 0
		queue.sync { result = self.array.count }
		return result
	}
	
	/// The capacity of the array
	var capacity: Int {
		var result = 0
		queue.sync { result = self.array.capacity }
		return result
	}
	
	/// A Boolean value indicating whether the collection is empty.
	var isEmpty: Bool {
		var result = false
		queue.sync { result = self.array.isEmpty }
		return result
	}
	
	/// A textual representation of the array and its elements.
	var description: String {
		var result = ""
		queue.sync { result = self.array.description }
		return result
	}
}

/* ---- MARK: - Mutable ---- */
public extension SynchronizedArray {
	
	/// Adds a new element at the end of the array.
	///
	/// - Parameter element: The element to append to the array.
	func append( _ element: Element) {
		queue.async(flags: .barrier) {
			self.array.append(element)
		}
	}
	
	/// Adds a new element at the end of the array.
	///
	/// - Parameter element: The element to append to the array.
	func append( _ elements: [Element]) {
		queue.async(flags: .barrier) {
			self.array += elements
		}
	}
	
	/// Inserts a new element at the specified position.
	///
	/// - Parameters:
	///   - element: The new element to insert into the array.
	///   - index: The position at which to insert the new element.
	func insert( _ element: Element, at index: Int) {
		queue.async(flags: .barrier) {
			self.array.insert(element, at: index)
		}
	}
	
	/// Removes and returns the element at the specified position.
	///
	/// - Parameters:
	///   - index: The position of the element to remove.
	///   - completion: The handler with the removed element.
	func remove(at index: Int, completion: ((Element) -> Void)? = nil) {
		queue.async(flags: .barrier) {
			let element = self.array.remove(at: index)
			
			self.queue.async {
				completion?(element)
			}
		}
	}
	
	/// Removes and returns the element at the specified position.
	///
	/// - Parameters:
	///   - predicate: A closure that takes an element of the sequence as its argument and returns a Boolean value indicating whether the element is a match.
	///   - completion: The handler with the removed element.
	func remove(where predicate: @escaping (Element) -> Bool, completion: ((Element) -> Void)? = nil) {
		queue.async(flags: .barrier) {
			guard let index = self.array.index(where: predicate) else { return }
			let element = self.array.remove(at: index)
			
			DispatchQueue.main.async {
				completion?(element)
			}
		}
	}
	
	/// Removes all elements from the array.
	///
	/// - Parameter completion: The handler with the removed elements.
	func removeAll(completion: (([Element]) -> Void)? = nil) {
		queue.async(flags: .barrier) {
			let elements = self.array
			self.array.removeAll()
			
			DispatchQueue.main.async {
				completion?(elements)
			}
		}
	}
}
