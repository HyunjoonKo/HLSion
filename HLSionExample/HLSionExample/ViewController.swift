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
        //sources.append(HLSion(url: URL(string: "https://bitdash-a.akamaihd.net/content/sintel/hls/playlist.m3u8")!, name: "Sample HLS", data: ["infomation": ["json": "data test"]]))
        sources.append(HLSion(url: URL(string: "https://vod.mubeat.tv/clip/111001/clip_365.m3u8")!, options: ["AVURLAssetHTTPHeaderFieldsKey": ["Cookie": "CloudFront-Policy=eyJTdGF0ZW1lbnQiOlt7IlJlc291cmNlIjoiaHR0cHM6Ly92b2QubXViZWF0LnR2L2NsaXAvMTExMDAxLyoqIiwiQ29uZGl0aW9uIjp7IkRhdGVMZXNzVGhhbiI6eyJBV1M6RXBvY2hUaW1lIjoxNTQwMTkzMzAxfX19XX0_;CloudFront-Signature=b0x~I1CcxhNjVRbmoIerCLz4AV~8DxWH3kk9QAKIEPL6pYst5Ds1ZOFCAFpEUS-OgJPqrDeQqSMy2Bul2d9-h0VYatvlfyQau8jL~afciYlcykScV4DCguLNQeopvXYmbTRt9obJUja2OrTBBAzN~nXAty-OF~qNdjz70uuh5vF50e9AEaF6k7lfn67iC25SKXEVoiRxunKUlCTFFLYQ1f~zv6Nam--vRBX~B3Y9r3Xp06EMQQBvbmYmDpDIAe4~QRqFc2NQztR2Dcnb50VXqZ1AkXMdirhQs~FEwmqPRVSs48Ap9JGiIv7-kdnEkwZb~ZDrkLIcN7cjKBRYkN3czw__"]], name: "111001"))
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
        return 1
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
            }.finish { (relativePath) in
                DispatchQueue.main.async {
                    tableView.reloadData()
                    print(relativePath)
                    
                    if let url = URL(string: relativePath) {
                        let asset = AVURLAsset(url: url)
                        let addtions = self.downloadableAddtionalMedias(asset)
                        self.download(subtitles: hlsion, identifier: hlsion.name, addtions: addtions)
                    }
                }
            }.onError { (error) in
                print("Error finish. \(error)")
            }
        case .downloading:
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
        for item in addtions {
            session.downloadAdditional(media: item) // TODO : 여기 진행중.
        }
    }
}
