//
//  ViewController.swift
//  Music Test
//
//  Created by thebv on 6/5/20.
//  Copyright © 2020 thebv. All rights reserved.
//

import UIKit
import AVFoundation
import CoreServices
import NotificationCenter
import MediaPlayer

enum PlayType {
    case fromFolder
    case history
}

class ViewController: UIViewController {

    
    @IBOutlet weak var toggleButtonPlayOrPauseMusic: UIBarButtonItem!
    @IBOutlet weak var ivMusicThumbnail: UIImageView!
    @IBOutlet weak var lblSongName: UILabel!
    @IBOutlet weak var lblAlbumName: UILabel!
    @IBOutlet weak var seggmented: UISegmentedControl!
    @IBOutlet weak var vTabListMusic: UIView!
    @IBOutlet weak var tableFolderMusic: UITableView!
    @IBOutlet weak var vTabHistory: UIView!
    @IBOutlet weak var tableHistory: UITableView!
    @IBOutlet weak var lblMusicCurrentDuration: UILabel!
    @IBOutlet weak var lblMusicTotalDuration: UILabel!
    @IBOutlet weak var progressMusic: UISlider!
    
    var repeart = false
    
    var listFolderMusic = [[String: String]]()
    var listHistoryMusic = [[String: String]]()
    var player = AVPlayer()
    var playerTimer: Timer?
    var playerIndex: Int = -1
    var playType: PlayType = .fromFolder
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view.
        
        self.navigationController?.setToolbarHidden(false, animated: false)
        tableFolderMusic.delegate = self
        tableFolderMusic.dataSource = self
        tableHistory.delegate = self
        tableHistory.dataSource = self
        
        resetInterface()
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback)
            try AVAudioSession.sharedInstance().setActive(true, options: [.notifyOthersOnDeactivation])
        } catch(let error) {
            print(error.localizedDescription)
        }

        reloadTableHistory()
        setupRemoteTransportControls()
    }
    
    func resetInterface() -> Void {
        self.lblSongName.text = ""
        self.lblAlbumName.text = ""
        self.lblMusicCurrentDuration.text = "00:00:00"
        self.lblMusicTotalDuration.text = "00:00:00"
        
        ivMusicThumbnail.image = nil
        
        self.progressMusic.maximumValue = 0
        self.progressMusic.value = 0
    }
    
    
    // MARK: Action
    @IBAction func previousButtonPressed(_ sender: Any) {
        previousTrack()
    }
    
    @IBAction func nextButtonPressed(_ sender: Any) {
        nextTrack()
    }
    
    @IBAction func toggleButtonPlayOrPauseMusicPressed(_ sender: UIBarButtonItem) {
        if (player.currentItem != nil) {
            if (player.rate == 1) {
                pauseTrack()
            } else {
                playTrack()
            }
            self.toolbarItems = toolbarItems
        }
    }
    
    @IBAction func shareCurrentMusic(_ sender: Any) {
        
        if (playerIndex == -1) {
            return
        }
        
        var music: [String: String]? = nil
        
        switch playType {
        case .fromFolder:
            if (playerIndex<listFolderMusic.count) {
                music = listFolderMusic[playerIndex]
            }
            break
        default:
            if (playerIndex<listHistoryMusic.count) {
                music = listHistoryMusic[playerIndex]
            }
            break
        }
        if (music==nil) {
            return
        }
        
        let urlPath = music?["urlPath"]
        let item = music?["item"]
        let fullPath = "\(urlPath ?? "")\(item ?? "")"
        
        let fileURL = NSURL(fileURLWithPath: fullPath)

        // Create the Array which includes the files you want to share
        var filesToShare = [Any]()

        // Add the path of the file to the Array
        filesToShare.append(fileURL)

        // Make the activityViewContoller which shows the share-view
        let activityViewController = UIActivityViewController(activityItems: filesToShare, applicationActivities: nil)

        // Show the share-view
        self.present(activityViewController, animated: true, completion: nil)
    }
    
    @IBAction func repeatCurrentMusic(_ sender: UIBarButtonItem) {
        repeart = !repeart
        let image = repeart ? "repeat.1" : "repeat"
        let toolbarItems = self.toolbarItems ?? [UIBarButtonItem]()
        for toolbarItem in toolbarItems {
            if (toolbarItems.firstIndex(of: toolbarItem) == 8) {
                toolbarItem.image = UIImage.init(systemName: image)
            }
        }
    }
    
    @IBAction func sliderValueChanged(_ sender: UISlider) {
        print("sender.value = \(sender.value)")
        let playerItem:AVPlayerItem? = player.currentItem
        player.seek(to: CMTimeMakeWithSeconds(Float64(sender.value), preferredTimescale: playerItem?.asset.duration.timescale ?? 0))
        self.lblMusicCurrentDuration.text = secondToTimeFormated(value: Int(sender.value))
    }
    
    @IBAction func setFolderToLoad(_ sender: Any) {
        let documentPicker = UIDocumentPickerViewController(documentTypes: ["public.folder"], in: .open)
        documentPicker.delegate = self
        self.present(documentPicker, animated: true, completion: nil)
    }
    
    @IBAction func segmentedOnValueChanged(_ sender: UISegmentedControl) {
        UIView.animate(withDuration: 0.3) { [weak self] in
            self?.vTabListMusic.isHidden = sender.selectedSegmentIndex == 1
            self?.vTabHistory.isHidden = sender.selectedSegmentIndex == 0
        }
    }
    

    // MARK: Music Player Action
    
    func playMusicAtIndex(index: Int) -> Void {
        resetInterface()
        
        let music: [String: String]?
        
        switch playType {
        case .fromFolder:
            music = listFolderMusic[index]
            break
        default:
            music = listHistoryMusic[index]
            break
        }
        if (music==nil) {
            return
        }
        
        playerIndex = index
        
        let urlPath = music?["urlPath"]
        let item = music?["item"]
        let fullPath = "\(urlPath ?? "")\(item ?? "")"
        
        let playerAsset = AVAsset(url: URL(fileURLWithPath: fullPath))
        let playerItem = AVPlayerItem(asset: playerAsset)
        
        var title = ""
//        var artist = ""
        var albumName = ""
        var artwork: UIImage?
        
        let metadataList = playerItem.asset.commonMetadata
        for item in metadataList {
            if item.commonKey == nil{
                continue
            }

            if let key = item.commonKey, let value = item.value {
                print(key)
                print(value)
                if key.rawValue == "title" {
                    title = value as! String
                }
//                if key.rawValue == "type" {
//                    let text = value
//                }
//                if key.rawValue == "artist" {
//                    artist = value as! String
//                }
                if key.rawValue == "albumName" {
                    albumName = value as! String
                }
                if key.rawValue == "artwork" {
                    if let audioImage = UIImage(data: value as! Data) {
                        artwork = audioImage
                    }
                }
            }
        }
        
        lblSongName.text = title.count > 0 ? title : item
        lblAlbumName.text = albumName.count > 0 ? albumName : "Unknown Album"
        ivMusicThumbnail.image = artwork
        
        let totalDuration = Int(playerItem.asset.duration.value) / Int(playerItem.asset.duration.timescale)
        print("totalDuration = \(totalDuration)")
        self.lblMusicTotalDuration.text = secondToTimeFormated(value: totalDuration)
        self.progressMusic.maximumValue = Float(totalDuration)
        self.progressMusic.value = 0
        
        NotificationCenter.default.removeObserver(self, name: NSNotification.Name.AVPlayerItemDidPlayToEndTime, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(musicPlayDidEnd), name: NSNotification.Name.AVPlayerItemDidPlayToEndTime, object: nil)
        playerTimer?.invalidate()
        playerTimer = Timer.scheduledTimer(timeInterval: 0.2, target: self, selector: #selector(onTimerCalled), userInfo: nil, repeats: true)
        
        player = AVPlayer(playerItem: playerItem)
        player.play()
        
        if #available(iOS 10.0, *) {
            player.addObserver(self, forKeyPath: "timeControlStatus", options: [.old, .new], context: nil)
        } else {
            player.addObserver(self, forKeyPath: "rate", options: [.old, .new], context: nil)
        }
        player.currentItem?.addObserver(self, forKeyPath: "duration", options: [.old, .new], context: nil)
        
        let toolbarItems = self.toolbarItems ?? [UIBarButtonItem]()
        for toolbarItem in toolbarItems {
            if (toolbarItems.firstIndex(of: toolbarItem) == 4) {
                toolbarItem.image = UIImage.init(systemName: "pause.fill")
            }
        }
        
        if (playType == .fromFolder) {
            tableFolderMusic.selectRow(at: IndexPath(row: index, section: 0), animated: true, scrollPosition: .middle)
        } else {
            tableHistory.selectRow(at: IndexPath(row: index, section: 0), animated: true, scrollPosition: .middle)
        }
        
        if (playType == .fromFolder) {
            addHistory(value: listFolderMusic[index])
        }
        setupOrReloadNowPlayingCenter()
    }
    
    func pauseTrack() {
        if (player.currentItem != nil) {
            player.pause()
            playerTimer?.invalidate()
            
            let toolbarItems = self.toolbarItems ?? [UIBarButtonItem]()
            for toolbarItem in toolbarItems {
                if (toolbarItems.firstIndex(of: toolbarItem) == 4) {
                    toolbarItem.image = UIImage.init(systemName: "play.fill")
                }
            }
            setupOrReloadNowPlayingCenter()
        }
    }
    
    func playTrack() {
        if (player.currentItem != nil) {
            player.play()
            playerTimer?.invalidate()
            playerTimer = Timer.scheduledTimer(timeInterval: 0.2, target: self, selector: #selector(onTimerCalled), userInfo: nil, repeats: true)
            let toolbarItems = self.toolbarItems ?? [UIBarButtonItem]()
            for toolbarItem in toolbarItems {
                if (toolbarItems.firstIndex(of: toolbarItem) == 4) {
                    toolbarItem.image = UIImage.init(systemName: "pause.fill")
                }
            }
            setupOrReloadNowPlayingCenter()
        }
    }
    
    func restartTrack() {
        if (player.currentItem != nil) {
            player.seek(to: .zero)
        }
    }
    
    func previousTrack() {
        var arr = [[String: String]]()
        if (self.playType == .fromFolder) {
            arr = self.listFolderMusic
        } else {
            arr = self.listHistoryMusic
        }
        if (arr.count>0) {
            if (self.playerIndex>0) {
                self.playMusicAtIndex(index: self.playerIndex-1)
            } else {
                self.playMusicAtIndex(index: arr.count-1)
            }
        }
    }
    
    func nextTrack() {
        var arr = [[String: String]]()
        if (self.playType == .fromFolder) {
            arr = self.listFolderMusic
        } else {
            arr = self.listHistoryMusic
        }
        if (arr.count>0) {
            if (self.playerIndex<arr.count-1) {
                self.playMusicAtIndex(index: self.playerIndex+1)
            } else {
                self.playMusicAtIndex(index: 0)
            }
        }
    }
    
    override func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey : Any]?, context: UnsafeMutableRawPointer?) {
        if object as AnyObject? === player {
            if keyPath == "status" {
                //                if player.status == .readyToPlay {
                //                    player.play()
                //                }
            } else if keyPath == "timeControlStatus" {
                if #available(iOS 10.0, *) {
                    setupOrReloadNowPlayingCenter()
                }
            } else if keyPath == "rate" {
                //                if avPlayer.rate > 0 {
                //                    videoCell?.muteButton.isHidden = false
                //                } else {
                //                    videoCell?.muteButton.isHidden = true
                //                }
            }
        } else if object as AnyObject? === player.currentItem {
            if keyPath == "duration" {
                setupOrReloadNowPlayingCenter()
                print("change = \(String(describing: change))")
            }
        }
    }
    
    @objc func onTimerCalled() -> Void {
        if (progressMusic.isTouchInside) {
            return
        }
        if (player.currentItem != nil) {
            let currentDuration = Float(player.currentTime().seconds)
            self.lblMusicCurrentDuration.text = secondToTimeFormated(value: Int(currentDuration))
            self.progressMusic.value = currentDuration
        }
    }
    
    @objc func musicPlayDidEnd() {
        print("musicPlayDidEnd")
        if (repeart) {
            self.playMusicAtIndex(index: playerIndex)
        } else {
            self.nextTrack()
        }
    }
    
    func secondToTimeFormated(value: Int) -> String {
        let hour = value/60/60
        let minute = value/60%60
        let second = value%60
        
        let durationString = "\(hour<10 ? "0\(hour)":"\(hour)"):\(minute<10 ? "0\(minute)":"\(minute)"):\(second<10 ? "0\(second)":"\(second)")"
        return durationString
    }
    
    func addHistory(value: [String:String]) -> Void {
        let key = "history"
        let oldHistory = UserDefaults.standard.string(forKey: key) ?? ""
        var arrHistory = [[String: String]]()
        if (oldHistory.count > 0) {
            // convert String to NSData
            let data = oldHistory.data(using: .utf8)  ?? Data()
            do {
                arrHistory = try JSONSerialization.jsonObject(with: data, options: .allowFragments) as! [[String : String]]
            } catch {
                print(error.localizedDescription)
            }
        }
        var i = 0
        while i == arrHistory.count-1 {
            if (arrHistory[i] == value) {
                arrHistory.remove(at: i)
                i -= 1
            }
            i += 1
        }
        arrHistory.insert(value, at: 0)
        
        do {
            let data = try JSONSerialization.data(withJSONObject: arrHistory, options: [])
            let string = String(data: data, encoding: String.Encoding.utf8)
            UserDefaults.standard.set(string, forKey: key)
            
            reloadTableHistory()
        } catch {
            print(error.localizedDescription)
        }
    }
    
    func reloadTableHistory() -> Void {
        let key = "history"
        let oldHistory = UserDefaults.standard.string(forKey: key) ?? ""
        var arrHistory = [[String: String]]()
        if (oldHistory.count > 0) {
            // convert String to NSData
            let data = oldHistory.data(using: .utf8)  ?? Data()
            do {
                arrHistory = try JSONSerialization.jsonObject(with: data, options: .allowFragments) as! [[String : String]]
            } catch {
                print(error.localizedDescription)
            }
        }
        self.listHistoryMusic = arrHistory
        self.tableHistory.reloadData()
    }
    
    func setupRemoteTransportControls() {
        // Get the shared MPRemoteCommandCenter
        let commandCenter = MPRemoteCommandCenter.shared()
        
        // Add handler for Play Command
        commandCenter.playCommand.addTarget { [unowned self] event in
            self.playTrack()
            return .success
        }

        // Add handler for Pause Command
        commandCenter.pauseCommand.addTarget { [unowned self] event in
            self.pauseTrack()
            return .success
        }
        
        commandCenter.previousTrackCommand.addTarget { [unowned self] event in
            self.previousTrack()
            return .success
        }
        
        commandCenter.nextTrackCommand.addTarget { [unowned self] event in
            self.nextTrack()
            return .success
        }
    }
    
    func setupOrReloadNowPlayingCenter() {
        // Define Now Playing Info
        let playerItem :AVPlayerItem? = player.currentItem
        
        var nowPlayingInfo = [String : Any]()
        nowPlayingInfo[MPMediaItemPropertyTitle] = self.lblSongName.text

        if let image = self.ivMusicThumbnail.image {
            nowPlayingInfo[MPMediaItemPropertyArtwork] =
                MPMediaItemArtwork(boundsSize: image.size) { size in
                    return image
            }
        }
        
        nowPlayingInfo[MPNowPlayingInfoPropertyElapsedPlaybackTime] = playerItem?.currentTime().seconds
        nowPlayingInfo[MPMediaItemPropertyPlaybackDuration] = playerItem?.asset.duration.seconds
        nowPlayingInfo[MPNowPlayingInfoPropertyPlaybackRate] = player.rate

        // Set the metadata
        MPNowPlayingInfoCenter.default().nowPlayingInfo = nowPlayingInfo
    }
    
    
}

extension ViewController: UIDocumentPickerDelegate {
    
    func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
        
    }
    
    func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
        if (urls.count>0) {
            let url = urls[0]
            print("url = \(url.absoluteString)")
            
            let urlPath = url.absoluteString.replacingOccurrences(of: "file:/", with: "")
            
            do {
                // If file with same name exists remove it (replace file with new one)
                if FileManager.default.fileExists(atPath: urlPath) {
                    let fileURLS = try FileManager.default.contentsOfDirectory(atPath: urlPath)
                    print("fileURLS = \(fileURLS)")
                    
                    resetInterface()
                    listFolderMusic.removeAll()
                    for item in fileURLS {
                        listFolderMusic.append([
                            "urlPath":urlPath,
                            "item":item,
                        ])
                    }
                    self.tableFolderMusic.reloadData()
                    
                    if (listFolderMusic.count>0) {
                        playMusicAtIndex(index: 0)
                    }
                }
            } catch {
                print(error.localizedDescription)
            }
        }
    }
    
    func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentAt url: URL) {
        
    }
}

extension ViewController: UITableViewDelegate, UITableViewDataSource {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        if (tableView == tableFolderMusic) {
            return listFolderMusic.count
        } else {
            return listHistoryMusic.count
        }
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        if (tableView == tableFolderMusic) {
            let cell = UITableViewCell.init(style: .default, reuseIdentifier: nil)
            cell.textLabel?.text = listFolderMusic[indexPath.row]["item"]
            cell.textLabel?.numberOfLines = 0
            return cell
        } else {
            let cell = UITableViewCell.init(style: .default, reuseIdentifier: nil)
            cell.textLabel?.text = listHistoryMusic[indexPath.row]["item"]
            cell.textLabel?.numberOfLines = 0
            return cell
        }
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        if (tableView == tableFolderMusic) {
            playType = .fromFolder
            playMusicAtIndex(index: indexPath.row)
        } else {
//            playType = .history
        }
    }
}

