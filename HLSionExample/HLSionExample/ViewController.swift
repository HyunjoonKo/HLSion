//
//  ViewController.swift
//  HLSionExample
//
//  Created by hyde on 2016/11/13.
//  Copyright © 2016年 r-plus. All rights reserved.
//

import UIKit
import AVKit
import AVFoundation
import HLSion

class ViewController: UITableViewController {

    var sources = [HLSion]()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // https://developer.apple.com/streaming/examples/
        sources = [
            HLSion(url: URL(string: "https://bitdash-a.akamaihd.net/content/sintel/hls/playlist.m3u8")!, name: "Sample HLS 1", data: ["infomation": ["json": "data test 1"]]),
            HLSion(url: URL(string: "https://bitdash-a.akamaihd.net/content/sintel/hls/playlist.m3u8")!, name: "Sample HLS 2", data: ["infomation": ["json": "data test 2"]]),
            HLSion(url: URL(string: "https://bitdash-a.akamaihd.net/content/sintel/hls/playlist.m3u8")!, name: "Sample HLS 3", data: ["infomation": ["json": "data test 3"]]),
            HLSion(url: URL(string: "https://bitdash-a.akamaihd.net/content/sintel/hls/playlist.m3u8")!, name: "Sample HLS 4", data: ["infomation": ["json": "data test 4"]]),
            HLSion(url: URL(string: "https://bitdash-a.akamaihd.net/content/sintel/hls/playlist.m3u8")!, name: "Sample HLS 5", data: ["infomation": ["json": "data test 5"]])
        ]
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "Cell") as! Cell
        let hlsion = sources[indexPath.row]
        cell.progressView.isHidden = true
        cell.titleLabel.text = hlsion.name
        cell.subLabel.text = hlsion.state.rawValue
        cell.sizeLabel.text = hlsion.offlineAssetSize == 0 ? nil : "\(hlsion.offlineAssetSize / 1024 / 1024)MB"
//        cell.accessoryType = hlsion.state == .downloaded ? .detailButton : .none
        return cell
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return sources.count
    }
    
    override func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return 60
    }
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        
        let hlsion = sources[indexPath.row]
        switch hlsion.state {
        case .notDownloaded:
            let cell = tableView.cellForRow(at: indexPath) as! Cell
            cell.progressView.isHidden = false
            cell.progressView.progress = 0
            hlsion.download { (percent) in
                DispatchQueue.main.async {
                    print(percent)
                    cell.subLabel.text = hlsion.state.rawValue
                    cell.progressView.progress = Float(percent)
                }
            }.onFinish { (relativePath) in
                DispatchQueue.main.async {
                    tableView.reloadData()
                    print(relativePath)
                    
                    let addtions = self.downloadableAddtionalMedias(hlsion.urlAsset)
                    self.download(subtitles: hlsion, identifier: hlsion.name, addtions: addtions)
                }
            }.onError { (error) in
                print("Error finish. \(error)")
            }
        case .downloading:
            hlsion.cancelDownload()
            tableView.reloadData()
            break
        case .downloaded:
            performSegue(withIdentifier: "AVPlayerViewControllerSegue", sender: hlsion)
        }
    }
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        super.prepare(for: segue, sender: sender)
        
        guard let playerViewControler = segue.destination as? AVPlayerViewController else { return }
        guard let hlsion = sender as? HLSion else { return }
        guard let localUrl = hlsion.localUrl else { return }
        let asset = AVURLAsset(url: localUrl)
        let playerItem = AVPlayerItem(asset: asset)
        let player = AVPlayer(playerItem: playerItem)
        playerViewControler.player = player
    }
    
    override func tableView(_ tableView: UITableView, shouldShowMenuForRowAt indexPath: IndexPath) -> Bool {
        return true
    }
    
//    override func tableView(_ tableView: UITableView, accessoryButtonTappedForRowWith indexPath: IndexPath) {
//        guard let cell = tableView.cellForRow(at: indexPath) as? Cell else { return }
//        
//        let hlsion = sources[indexPath.row]
//        guard hlsion.state == .downloaded else { return }
//        let availables = hlsion.downloadableAdditionalMedias()
//        
//        let alertController = UIAlertController(title: hlsion.name, message: "Select from the following options:", preferredStyle: .actionSheet)
//        availables.forEach { (group, option) in
//            let alertAction = UIAlertAction(title: "Download \(option.displayName)", style: .default) { _ in
//                hlsion.downloadAdditional(media: (group, option)).progress { (progress) in
//                    print(progress)
//                }.finish { (path) in
//                    print("-------------Additional download finish.")
//                    print(path)
//                }
//            }
//            alertController.addAction(alertAction)
//        }
//        alertController.addAction(UIAlertAction(title: "Dismiss", style: .cancel, handler: nil))
//        
//        if UIDevice.current.userInterfaceIdiom == .pad {
//            guard let popoverController = alertController.popoverPresentationController else {
//                return
//            }
//            
//            popoverController.sourceView = cell
//            popoverController.sourceRect = cell.bounds
//        }
//        
//        present(alertController, animated: true, completion: nil)
//    }
    
    override func tableView(_ tableView: UITableView, editActionsForRowAt indexPath: IndexPath) -> [UITableViewRowAction]? {
        let deleteAction = UITableViewRowAction(style: .destructive, title: "Delete", handler: { action, indexPath in
            let hlsion = self.sources[indexPath.row]
            guard hlsion.state == .downloaded else { return }
            try! hlsion.deleteAsset()
            tableView.reloadData()
        })
        return [deleteAction]
    }
    
    // MARK: addtionals
    
    fileprivate func downloadableAddtionalMedias(_ asset: AVURLAsset) -> [(AVMediaSelectionGroup, AVMediaSelectionOption)] {
        var captions: [(AVMediaSelectionGroup, AVMediaSelectionOption)] = []
        if let group = asset.mediaSelectionGroup(forMediaCharacteristic: AVMediaCharacteristicLegible), group.options.count > 0 {
            for item in group.options {
                captions.append((group, item))
            }
        }
        return captions
    }
    
    fileprivate func download(subtitles session: HLSion, identifier: String, addtions: [(AVMediaSelectionGroup, AVMediaSelectionOption)]) {
        DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + Double(Int64(0.2 * Double(NSEC_PER_SEC))) / Double(NSEC_PER_SEC)) {
            for item in addtions {
                session.downloadAdditional(media: item)
            }
        }
    }
}
