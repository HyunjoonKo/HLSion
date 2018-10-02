//
//  AssetStore.swift
//  HLSion
//
//  Created by hyde on 2016/11/12.
//  Copyright © 2016年 r-plus. All rights reserved.
//

import Foundation

internal struct AssetStore {
    
    internal typealias AssetData = (path: String, options: [String : String]?)  // path, options
    
    // name : key, value : path
    private static var shared: [String: AssetData] = {
        if FileManager.default.fileExists(atPath: storeURL.path) {
            return NSDictionary(contentsOf: storeURL) as! [String : AssetData]
        }
        return [:]
    }()
    
    private static let storeURL: URL = {
        let library = NSSearchPathForDirectoriesInDomains(.libraryDirectory, .userDomainMask, true)[0]
        return URL(fileURLWithPath: library).appendingPathComponent("HLSion").appendingPathExtension("plist")
    }()
    
    static func allMap() -> [String: Any] {
        return shared
    }
    
    static func path(forName: String) -> AssetData? {
        if let data = shared.first(where: { $0.key == forName }) {
            return data.value
        }
        return nil
    }
    
    @discardableResult
    static func set(path: String, options: [String : String]? = nil ,forName: String) -> Bool {
        shared[forName] = AssetData(path: path, options: options)
        let dict = shared as NSDictionary
        return dict.write(to: storeURL, atomically: true)
    }
    
    @discardableResult
    static func remove(forName: String) -> Bool {
        guard let _ = shared.removeValue(forKey: forName) else { return false }
        let dict = shared as NSDictionary
        return dict.write(to: storeURL, atomically: true)
    }
}
