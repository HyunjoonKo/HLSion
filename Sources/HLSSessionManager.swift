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
    internal var downloadingMap = [URLSessionTask : HLSion]()
    private var session: AVAssetDownloadURLSession?
    
    // MARK: Intialization
    
    override private init() {
        super.init()
        
        if let className = self.classForKeyedArchiver {
            if let text = "\(className)".components(separatedBy: ".").first {
                NSKeyedUnarchiver.setClass(AssetData.self, forClassName: text + ".AssetData")
            }
        }
        prepareForURLSession()
        restoreDownloadsMap()
    }
    
    @discardableResult
    func prepareForURLSession(_ option: [AnyHashable : Any]? = nil) -> AVAssetDownloadURLSession? {
        let configuration = URLSessionConfiguration.background(withIdentifier: "jp.HLSion.configuration")
        configuration.timeoutIntervalForRequest = 20.0
        configuration.timeoutIntervalForResource = 20.0
        configuration.shouldUseExtendedBackgroundIdleMode = true
        configuration.isDiscretionary = false
        configuration.networkServiceType = .video
        configuration.httpAdditionalHeaders = option
        let downloadURLSession = AVAssetDownloadURLSession(configuration: configuration, assetDownloadDelegate: self, delegateQueue: OperationQueue.main)
        session = downloadURLSession
        
        return downloadURLSession
    }
    
    // MARK: Method
    
    private func restoreDownloadsMap() {
        session?.getAllTasks { tasksArray in
            for task in tasksArray {
                guard let assetDownloadTask = task as? AVAssetDownloadTask, let hlsionName = task.taskDescription else { break }
                
                let hlsion = HLSion(asset: assetDownloadTask.urlAsset, description: hlsionName)
                self.downloadingMap[assetDownloadTask] = hlsion
            }
        }
    }
    
    func downloadStream(_ hlsion: HLSion, options: [String: Any]? = nil, isForced: Bool = false) {
        guard assetExists(forName: hlsion.name) == false || isForced == true else { return }
        
        hlsion.result = nil
        session?.configuration.httpAdditionalHeaders = hlsion.options
        
        guard let task = session?.makeAssetDownloadTask(asset: hlsion.urlAsset, assetTitle: hlsion.name, assetArtworkData: nil, options: options) else { return }
        
        task.taskDescription = hlsion.name
        downloadingMap[task] = hlsion
        
        task.resume()
        
    }
    
    func downloadAdditional(media: AVMutableMediaSelection, option: AVMediaSelectionOption, hlsion: HLSion) {
        guard assetExists(forName: hlsion.name) == true else { return }
        let options = [AVAssetDownloadTaskMediaSelectionKey: media]
        self.downloadStream(hlsion, options: options, isForced: true)
    }
    
    func cancelDownload(_ hlsion: HLSion) {
        if let index = downloadingMap.firstIndex(where: { $1 == hlsion }) {
            downloadingMap[index].key.cancel()
            downloadingMap.remove(at: index)
        }
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
    
    func update(infomation hlsion: HLSion) -> Bool {
        guard let relativePath = AssetStore.path(forName: hlsion.name)?.path else { return false }
        return AssetStore.set(path: relativePath, options: hlsion.options, data: hlsion.data, forName: hlsion.name)
    }
    
    fileprivate func set(totalTimeRangesLoaded loadedTimeRanges: [NSValue], timeRangeExpectedToLoad: CMTimeRange, progressClosure: ProgressParameter) {
        let percentComplete = loadedTimeRanges.reduce(0.0) {
            let loadedTimeRange : CMTimeRange = $1.timeRangeValue
            return $0 + CMTimeGetSeconds(loadedTimeRange.duration) / CMTimeGetSeconds(timeRangeExpectedToLoad.duration)
        }
        
        progressClosure(percentComplete)
    }
    
    // MARK: AVAssetDownloadDelegate
    
    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        guard let task = task as? AVAssetDownloadTask , let hlsion = downloadingMap.removeValue(forKey: task) else { return }
        
        if let error = error as NSError? {
            switch (error.domain, error.code) {
            case (NSURLErrorDomain, NSURLErrorCancelled):
                // hlsion.result as success when cancelled.
                guard let localFileLocation = AssetStore.path(forName: hlsion.name)?.path else { return }
                
                do {
                    let fileURL = homeDirectoryURL.appendingPathComponent(localFileLocation)
                    try FileManager.default.removeItem(at: fileURL)
                } catch {
                    print("An error occured trying to delete the contents on disk for \(hlsion.name): \(error)")
                }
                
            case (NSURLErrorDomain, NSURLErrorUnknown):
                hlsion.result = .failure(error)
                fatalError("Downloading HLS streams is not supported in the simulator.")
                
            default:
                hlsion.result = .failure(error)
                print("An unexpected error occured \(error.domain) >> \(error.localizedDescription)")
            }
        } else {
            hlsion.result = .success
        }
        
        if let result = hlsion.result {
            switch result {
            case .success:
                if let path = AssetStore.path(forName: hlsion.name)?.path {
                    if hlsion.isDownloadAddtions {
                        hlsion.finishAdditionalClosure?(path)
                    } else {
                        hlsion.finishClosure?(path)
                    }
                }
            case .failure(let err):
                if hlsion.isDownloadAddtions {
                    hlsion.errorAdditionalClosure?(err)
                } else {
                    hlsion.errorClosure?(err)
                }
            }
        }
    }
    
    func urlSession(_ session: URLSession, assetDownloadTask: AVAssetDownloadTask, didFinishDownloadingTo location: URL) {

        guard let hlsion = downloadingMap[assetDownloadTask] else { return }
        AssetStore.set(path: location.relativePath, options: hlsion.options, data: hlsion.data, forName: hlsion.name)
    }
    
    func urlSession(_ session: URLSession,
                    assetDownloadTask: AVAssetDownloadTask,
                    didLoad timeRange: CMTimeRange,
                    totalTimeRangesLoaded loadedTimeRanges: [NSValue],
                    timeRangeExpectedToLoad: CMTimeRange) {
        guard let hlsion = downloadingMap[assetDownloadTask] else { return }
        hlsion.result = nil
        
        if hlsion.isDownloadAddtions {
            guard let progressClosure = hlsion.progressAdditionalClosure else { return }
            self.set(totalTimeRangesLoaded: loadedTimeRanges, timeRangeExpectedToLoad: timeRangeExpectedToLoad, progressClosure: progressClosure)
        } else {
            guard let progressClosure = hlsion.progressClosure else { return }
            self.set(totalTimeRangesLoaded: loadedTimeRanges, timeRangeExpectedToLoad: timeRangeExpectedToLoad, progressClosure: progressClosure)            
        }
    }
    
    func urlSession(_ session: URLSession, assetDownloadTask: AVAssetDownloadTask, didResolve resolvedMediaSelection: AVMediaSelection) {
        guard let hlsion = downloadingMap[assetDownloadTask] else { return }
        hlsion.resolvedMediaSelection = resolvedMediaSelection
    }
    
    func urlSession(_ session: URLSession, didBecomeInvalidWithError error: Error?) {
        print("didBecomeInvalidWithError: \(String(describing: error))")
    }
    
    func urlSessionDidFinishEvents(forBackgroundURLSession session: URLSession) {
        print("forBackgroundURLSession: \(String(describing: session))")
    }
}
