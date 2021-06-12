//
//  AssetStore.swift
//  HLSion
//
//  Created by hyde on 2016/11/12.
//  Copyright © 2016年 r-plus. All rights reserved.
//

import Foundation

internal struct AssetStore {
    
    // name : key, value : path
    private static var shared: [String: AssetData] = {
        if FileManager.default.fileExists(atPath: storeURL.path) {
            do {
                let data = try Data(contentsOf: storeURL)
                let object = NSKeyedUnarchiver.unarchiveObject(with: data)
                //let object = try NSKeyedUnarchiver.unarchivedObject(ofClasses: [NSDictionary.self, AssetData.self, NSString.self], from: data)
                if let dictionary = object as? [String: AssetData] {
                    return dictionary
                }
            }
            catch {
                print("An error occured trying to saved list: \(error)")
                return [:]
            }
        }
        return [:]
    }()
    
    private static let storeURL: URL = {
        let library = NSSearchPathForDirectoriesInDomains(.libraryDirectory, .userDomainMask, true)[0]
        return URL(fileURLWithPath: library).appendingPathComponent("HLSion").appendingPathExtension("data")
    }()
    
    static func allMap() -> [String: AssetData] {
        return shared
    }
    
    static func path(forName: String) -> AssetData? {
        if let data = shared.first(where: { $0.key == forName }) {
            return data.value
        }
        return nil
    }
    
    @discardableResult
    static func set(path: String, options: [String : Any]? = nil, data: Any? = nil, forName: String) -> Bool {
        shared[forName] = AssetData(path: path, options: options, data: data)
        let archive = NSKeyedArchiver.archivedData(withRootObject: shared)
        do {
            //let archive = try NSKeyedArchiver.archivedData(withRootObject: shared, requiringSecureCoding: true)
            try archive.write(to: storeURL, options: .atomic)
            return true
        } catch {
            print("An error occured trying to saving.")
            return false
        }
    }
    
    @discardableResult
    static func remove(forName: String) -> Bool {
        guard let _ = shared.removeValue(forKey: forName) else { return false }
        let data = NSKeyedArchiver.archivedData(withRootObject: shared)
        do {
            //let data = try NSKeyedArchiver.archivedData(withRootObject: shared, requiringSecureCoding: true)
            try data.write(to: storeURL, options: .atomic)
            return true
        } catch {
            print("An error occured trying to deleting.")
            return false
        }
    }
}
