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
    
    public init(path: String, options: [String: Any]? = nil) {
        self.path = path
        self.options = options        
    }
    
    func encode(with aCoder: NSCoder) {
        if let p = path {
            aCoder.encode(p, forKey: "path")
        }
        if let opt = options {
            aCoder.encode(opt, forKey: "options")
        }
    }
    
    init?(coder aDecoder: NSCoder) {
        path = aDecoder.decodeObject(forKey: "path") as? String
        options = aDecoder.decodeObject(forKey: "path") as? [String : Any]
    }
}
