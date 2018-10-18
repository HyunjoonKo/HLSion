//
//  AssetData.swift
//  HLSion
//
//  Created by 고현준 on 2018. 10. 2..
//  Copyright © 2018년 r-plus. All rights reserved.
//

import Foundation

final internal class AssetData: NSObject, NSCoding {
    
    var path: String?
    var options: [String : Any]?
    var data: Any?
    
    public init(path: String, options: [String: Any]? = nil, data: Any? = nil) {
        self.path = path
        self.options = options
        self.data = data
    }
    
    func encode(with aCoder: NSCoder) {
        if let p = path {
            aCoder.encode(p, forKey: "path")
        }
        if let opt = options {
            aCoder.encode(opt, forKey: "options")
        }
        if let d = data {
            aCoder.encode(d, forKey: "data")
        }
    }
    
    init?(coder aDecoder: NSCoder) {
        path = aDecoder.decodeObject(forKey: "path") as? String
        options = aDecoder.decodeObject(forKey: "path") as? [String : Any]
        data = aDecoder.decodeObject(forKey: "data")
    }
}
