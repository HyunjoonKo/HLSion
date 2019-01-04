//
//  HLSion.swift
//  HLSion
//
//  Created by hyde on 2016/11/12.
//  Copyright © 2016年 r-plus. All rights reserved.
//

import Foundation
import AVFoundation

public typealias ProgressParameter = (Double) -> Void
public typealias FinishParameter = (String) -> Void
public typealias ErrorParameter = (Error) -> Void

public class HLSion {
    
    public enum State: String {
        case notDownloaded
        case downloading
        case downloaded
    }
    
    enum Result {
        case success
        case failure(Error)
    }

    // MARK: Properties
    
    /// Identifier name.
    public let name: String
    /// Target AVURLAsset that have HLS URL.
    public let urlAsset: AVURLAsset
    /// Local url path that saved for offline playback. return nil if not downloaded.
    public var localUrl: URL? {
        guard let relativePath = AssetStore.path(forName: name)?.path else { return nil }
        return HLSSessionManager.shared.homeDirectoryURL.appendingPathComponent(relativePath)
    }
    /// Download state.
    public var state: State {
        if HLSSessionManager.shared.assetExists(forName: name) {
            return .downloaded
        }
        if HLSSessionManager.shared.downloadingMap.count > 0, let _ = HLSSessionManager.shared.downloadingMap.first(where: { $1 == self }) {
            return .downloading
        }
        return .notDownloaded
    }
    /// File size of downloaded HLS asset.
    public var offlineAssetSize: UInt64 {
        guard state == .downloaded else { return 0 }
        guard let relativePath = AssetStore.path(forName: name)?.path else { return 0 }
        let bundleURL = HLSSessionManager.shared.homeDirectoryURL.appendingPathComponent(relativePath)
        guard let subpaths = try? FileManager.default.subpathsOfDirectory(atPath: bundleURL.path) else { return 0 }
        let size: UInt64 = subpaths.reduce(0) {
            let filePath = bundleURL.appendingPathComponent($1).path
            guard let fileAttribute = try? FileManager.default.attributesOfItem(atPath: filePath) else { return $0 }
            guard let size = fileAttribute[FileAttributeKey.size] as? NSNumber else { return $0 }
            return $0 + size.uint64Value
        }
        return size
    }
    
    /// AVURLAsset options.
    public var options: [String: Any]?
    /// save other data objects.
    public var data: Any?
    
    public var isDownloadAddtions: Bool = false
    internal var progressAdditionalClosure: ProgressParameter?
    internal var finishAdditionalClosure: FinishParameter?
    internal var errorAdditionalClosure: ErrorParameter?
    
    internal var result: Result?
    internal var progressClosure: ProgressParameter?
    internal var finishClosure: FinishParameter?
    internal var errorClosure: ErrorParameter?
    internal var resolvedMediaSelection: AVMediaSelection?
    
    // MARK: Intialization
    
    public init(asset: AVURLAsset, description: String) {
        name = description
        urlAsset = asset
        isDownloadAddtions = false
    }
    
    /// Initialize HLSion
    ///
    /// - Parameters:
    ///   - url: HLS(m3u8) URL.
    ///   - options: AVURLAsset options.
    ///   - name: Identifier name.
    public convenience init(url: URL, options: [String: Any]? = nil, name: String, data: Any? = nil) {
        let urlAsset = AVURLAsset(url: url, options: options)
        self.init(asset: urlAsset, description: name)
        self.options = options
        self.data = data
    }
    
    // MARK: Method
    
    /// Restore downloading tasks. You should call this method in AppDelegate.
    public static func restoreDownloadsTasks() {
        _ = HLSSessionManager.shared
    }
    
    /// Start download HLS stream data as asset. Should delete asset when you want to re-download HLS stream, simply ignore if exist same HLSion.
    ///
    /// - Parameter closure: Progress closure.
    /// - Returns: Chainable self instance.
    @discardableResult
    public func download(progress closure: ProgressParameter? = nil) -> Self {
        progressClosure = closure
        HLSSessionManager.shared.downloadStream(self)
        return self
    }
    
    /// Set progress closure.
    ///
    /// - Parameter closure: Progress closure that will invoke when download each time range files.
    /// - Returns: Chainable self instance.
    @discardableResult
    public func onProgress(progress closure: @escaping ProgressParameter) -> Self {
        progressClosure = closure
        return self
    }
    
    /// Set finish(success) closure.
    ///
    /// - Parameter closure: Finish closure that will invoke when successfully finished download media.
    /// - Returns: Chainable self instance.
    @discardableResult
    public func onFinish(relativePath closure: @escaping FinishParameter) -> Self {
        finishClosure = closure
        if let result = result, case .success = result {
            closure(AssetStore.path(forName: name)!.path!)
        }
        return self
    }
    
    /// Set failure closure.
    ///
    /// - Parameter closure: Finish closure that will invoke when failure finished download media.
    /// - Returns: Chainable self instance.
    @discardableResult
    public func onError(error closure: @escaping ErrorParameter) -> Self {
        errorClosure = closure
        if let result = result, case .failure(let err) = result {
            closure(err)
        }
        return self
    }
    
    /// Pause download.
    public func pauseDownload() {
        HLSSessionManager.shared.cancelDownload(self)
    }
    
    /// Cancel download.
    public func cancelDownload() {
        pauseDownload()
        AssetStore.remove(forName: name)
    }
    
    /// Delete local stored HLS asset.
    ///
    /// - Throws: FileManager file delete exception.
    public func deleteAsset() throws {
        try HLSSessionManager.shared.deleteAsset(forName: name)
    }
    
    /// Additional downloadable media selection group and option. Return empty array if not yet download to local or completly downloaded all medias.
    ///
    /// - Returns: media group and options.
//    public func downloadableAdditionalMedias() -> [(AVMediaSelectionGroup, AVMediaSelectionOption)] {
//        var result = [(AVMediaSelectionGroup, AVMediaSelectionOption)]()
//        guard let assetCache = urlAsset.assetCache else { return result }
//
//        let mediaCharacteristics = [AVMediaCharacteristicAudible, AVMediaCharacteristicLegible]
//
//        for mediaCharacteristic in mediaCharacteristics {
//            guard let mediaSelectionGroup = urlAsset.mediaSelectionGroup(forMediaCharacteristic: mediaCharacteristic) else { continue }
//            let savedOptions = assetCache.mediaSelectionOptions(in: mediaSelectionGroup)
//            for option in mediaSelectionGroup.options where !savedOptions.contains(option) {
//                result.append((mediaSelectionGroup, option))
//            }
//        }
//
//        return result
//    }
    
    /// Download additional media.
    ///
    /// - Parameter media: Selected pair from `downloadableAdditionalMedias`
    /// - Returns: Chainable self instance. WARN: progress and finish closures are shared.
    @discardableResult
    public func downloadAdditional(media: (AVMediaSelectionGroup, AVMediaSelectionOption), progress: ProgressParameter? = nil, finish: FinishParameter? = nil, error: ErrorParameter? = nil) -> Self {
        guard state == .downloaded else { return self }
        guard let dummyMediaSelection = self.resolvedMediaSelection else { return self }
        
        self.isDownloadAddtions = true
        self.progressAdditionalClosure = progress
        self.finishAdditionalClosure = finish
        self.errorAdditionalClosure = error
        
        let mediaSelection = dummyMediaSelection.mutableCopy() as! AVMutableMediaSelection
        mediaSelection.select(media.1, in: media.0)
        HLSSessionManager.shared.downloadAdditional(media: mediaSelection, option: media.1, hlsion: self)
        
        return self
    }
    
    // custom path is not work for AVAssetCache.
//    public static func set(downloadPath: URL) {
//        HLSSessionManager.shared.homeDirectoryURL = downloadPath
//    }
    
    public static func assetExists(forName: String) -> HLSion? {
        if let data = AssetStore.path(forName: forName), let path = data.path, let url = URL(string: path) {
            return HLSion(url: url, options: data.options, name: forName, data: data.data)
        }
        return nil
    }
    
    public static var downloadList: [HLSion] {
        var lists: [HLSion] = []
        for item in AssetStore.allMap() {
            if let path = item.value.path, let url = URL(string: path) {
                lists.append(HLSion(url: url, options: item.value.options, name: item.key, data: item.value.data))
            }
        }
        return lists
    }
}

extension HLSion: Equatable {}

public func == (lhs: HLSion, rhs: HLSion) -> Bool {
    return (lhs.name == rhs.name) && (lhs.urlAsset == rhs.urlAsset)
}

extension HLSion: CustomStringConvertible {
    
    public var description: String {
        return "\(name), \(urlAsset.url)"
    }
}
