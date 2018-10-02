//
//  HLSSessionManager.swift
//  HLSion
//
//  Created by hyde on 2016/11/12.
//  Copyright © 2016年 r-plus. All rights reserved.
//

import Foundation
import AVFoundation

final internal class HLSSessionManager: NSObject, AVAssetDownloadDelegate {
    // MARK: Properties
    
    static let shared = HLSSessionManager()
    
    internal var homeDirectoryURL = URL(fileURLWithPath: NSHomeDirectory())
    private var session: AVAssetDownloadURLSession!
    internal typealias HLSTaskData = (HLSion: HLSion, options: [String : Any]?)  // HLSion, options
    internal var downloadingMap = [AVAssetDownloadTask : HLSTaskData]()
    
    // MARK: Intialization
    
    override private init() {
        super.init()
        let configuration = URLSessionConfiguration.background(withIdentifier: "jp.HLSion.configuration")
        session = AVAssetDownloadURLSession(configuration: configuration,
                                                            assetDownloadDelegate: self,
                                                            delegateQueue: OperationQueue.main)
        restoreDownloadsMap()
    }
    
    // MARK: Method
    
    private func restoreDownloadsMap() {
        session.getAllTasks { tasksArray in
            for task in tasksArray {
                guard let assetDownloadTask = task as? AVAssetDownloadTask, let hlsionName = task.taskDescription else { break }
                
                let hlsion = HLSion(asset: assetDownloadTask.urlAsset, description: hlsionName)
                self.downloadingMap[assetDownloadTask] = HLSTaskData(HLSion: hlsion, options: nil)
            }
        }
    }
    
    func downloadStream(_ hlsion: HLSion, options: [String: Any]? = nil) {
        guard assetExists(forName: hlsion.name) == false else { return }
        
        if #available(iOS 10.0, *) {
            
            guard let task = session.makeAssetDownloadTask(asset: hlsion.urlAsset, assetTitle: hlsion.name, assetArtworkData: nil, options: nil) else { return }
            
            task.taskDescription = hlsion.name
            downloadingMap[task] = HLSTaskData(HLSion: hlsion, options: options)
            
            task.resume()
            
        } else {
            
            guard let localFileLocation = AssetStore.path(forName: hlsion.name)?.path else { return }
            let fileURL = homeDirectoryURL.appendingPathComponent(localFileLocation)
            guard let task = session.makeAssetDownloadTask(asset:  hlsion.urlAsset, destinationURL: fileURL, options: nil) else { return }
            
            task.taskDescription = hlsion.name
            downloadingMap[task] = HLSTaskData(HLSion: hlsion, options: options)
            
            task.resume()
        }
    }
    
//    func downloadAdditional(media: AVMutableMediaSelection, hlsion: HLSion) {
//        guard assetExists(forName: hlsion.name) == true else { return }
//        
//        let options = [AVAssetDownloadTaskMediaSelectionKey: media]
//        guard let task = session.makeAssetDownloadTask(asset: hlsion.urlAsset, assetTitle: hlsion.name, assetArtworkData: nil, options: options) else { return }
//        
//        task.taskDescription = hlsion.name
//        downloadingMap[task] = hlsion
//        
//        task.resume()
//    }
    
    func cancelDownload(_ hlsion: HLSion) {
        downloadingMap.first(where: { $1.HLSion == hlsion })?.key.cancel()
    }
    
    func deleteAsset(forName: String) throws {
        guard let relativePath = AssetStore.path(forName: forName)?.path else { return }
        let localFileLocation = homeDirectoryURL.appendingPathComponent(relativePath)
        try FileManager.default.removeItem(at: localFileLocation)
        AssetStore.remove(forName: forName)
    }
    
    func assetExists(forName: String) -> Bool {
        guard let relativePath = AssetStore.path(forName: forName)?.path else { return false }
        let filePath = homeDirectoryURL.appendingPathComponent(relativePath).path
        return FileManager.default.fileExists(atPath: filePath)
    }
    
    // MARK: AVAssetDownloadDelegate
    
    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        guard let task = task as? AVAssetDownloadTask , let hlsion = downloadingMap.removeValue(forKey: task) else { return }
        
        if let error = error as NSError? {
            switch (error.domain, error.code) {
            case (NSURLErrorDomain, NSURLErrorCancelled):
                // hlsion.result as success when cancelled.
                guard let localFileLocation = AssetStore.path(forName: hlsion.HLSion.name)?.path else { return }
                
                do {
                    let fileURL = homeDirectoryURL.appendingPathComponent(localFileLocation)
                    try FileManager.default.removeItem(at: fileURL)
                } catch {
                    print("An error occured trying to delete the contents on disk for \(hlsion.HLSion.name): \(error)")
                }
                
            case (NSURLErrorDomain, NSURLErrorUnknown):
                hlsion.HLSion.result = .failure(error)
                fatalError("Downloading HLS streams is not supported in the simulator.")
                
            default:
                hlsion.HLSion.result = .failure(error)
                print("An unexpected error occured \(error.domain)")
            }
        } else {
            hlsion.HLSion.result = .success
        }
        switch hlsion.HLSion.result! {
        case .success:
            hlsion.HLSion.finishClosure?(AssetStore.path(forName: hlsion.HLSion.name)!.path!)
        case .failure(let err):
            hlsion.HLSion.errorClosure?(err)
        }
    }
    
    func urlSession(_ session: URLSession, assetDownloadTask: AVAssetDownloadTask, didFinishDownloadingTo location: URL) {

        guard let hlsion = downloadingMap[assetDownloadTask] else { return }
        AssetStore.set(path: location.relativePath, options: hlsion.options, forName: hlsion.HLSion.name)
    }
    
    func urlSession(_ session: URLSession,
                    assetDownloadTask: AVAssetDownloadTask,
                    didLoad timeRange: CMTimeRange,
                    totalTimeRangesLoaded loadedTimeRanges: [NSValue],
                    timeRangeExpectedToLoad: CMTimeRange) {
        guard let hlsion = downloadingMap[assetDownloadTask] else { return }
        hlsion.HLSion.result = nil
        guard let progressClosure = hlsion.HLSion.progressClosure else { return }
        
        let percentComplete = loadedTimeRanges.reduce(0.0) {
            let loadedTimeRange : CMTimeRange = $1.timeRangeValue
            return $0 + CMTimeGetSeconds(loadedTimeRange.duration) / CMTimeGetSeconds(timeRangeExpectedToLoad.duration)
        }
        
        progressClosure(percentComplete)
    }
    
//    func urlSession(_ session: URLSession, assetDownloadTask: AVAssetDownloadTask, didResolve resolvedMediaSelection: AVMediaSelection) {
//        if assetDownloadTask.taskDescription == "jp.HLSion.dummy" {
//            guard let hlsion = downloadingMap[assetDownloadTask] else { return }
//            hlsion.resolvedMediaSelection = resolvedMediaSelection
//            assetDownloadTask.cancel()
//        }
//    }
}
