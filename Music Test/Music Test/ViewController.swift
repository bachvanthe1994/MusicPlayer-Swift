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

    
    
    @IBOutlet weak var ivMusicThumbnail: UIImageView!
    @IBOutlet weak var lblSongName: UILabel!
    @IBOutlet weak var lblAlbumName: UILabel!
    @IBOutlet weak var seggmented: UISegmentedControl!
    @IBOutlet weak var vTabListMusic: UIView!
    @IBOutlet weak var tableFolderMusic: UITableView!
    @IBOutlet weak var vTabHistory: UIView!
    @IBOutlet weak var tableHistory: UITableView!
    @IBOutlet weak var lblFolderPath: UILabel!
    @IBOutlet weak var lblMusicCurrentDuration: UILabel!
    @IBOutlet weak var lblMusicTotalDuration: UILabel!
    @IBOutlet weak var progressMusic: UIProgressView!
    
    var listFolderMusic = [[String: String]]()
    var listHistoryMusic = [[String: String]]()
    var player = AVPlayer()
    var playerTimer: Timer?
    var playerIndex: Int = 0
    var playType: PlayType = .fromFolder
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view.
        
        self.navigationController?.setToolbarHidden(false, animated: false)
        tableFolderMusic.delegate = self
        tableFolderMusic.dataSource = self
        tableHistory.delegate = self
        tableHistory.dataSource = self
        
        self.lblFolderPath.text = ""
        resetInterface()
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback)
            try AVAudioSession.sharedInstance().setActive(true, options: [.notifyOthersOnDeactivation])
        } catch(let error) {
            print(error.localizedDescription)
        }

        reloadTableLog()
    }
    
    func resetInterface() -> Void {
        self.lblSongName.text = ""
        self.lblAlbumName.text = ""
        self.lblMusicCurrentDuration.text = "00:00:00"
        self.lblMusicTotalDuration.text = "00:00:00"
        
        self.progressMusic.progress = 0
        ivMusicThumbnail.image = nil
    }
    
    @IBAction func playButtonPressed(_ sender: Any) {
        playTrack()
    }
    
    @IBAction func pauseButtonPressed(_ sender: Any) {
        pauseTrack()
    }
    
    @IBAction func restartButtonPressed(_ sender: Any) {
        restartTrack()
    }
    
    @IBAction func setFolderToLoad(_ sender: Any) {
        let documentPicker = UIDocumentPickerViewController(documentTypes: ["public.folder"], in: .open)
        documentPicker.delegate = self
        self.present(documentPicker, animated: true, completion: nil)
    }
    

    @objc func onTimerCalled() -> Void {
        if (player.currentItem != nil) {
            let playerItem:AVPlayerItem? = player.currentItem
            let totalDuration = Float(playerItem?.asset.duration.value ?? 0) / Float(playerItem?.asset.duration.timescale ?? 0)
            let currentDuration = Float(player.currentTime().seconds)
            
            self.lblMusicCurrentDuration.text = secondToTimeFormated(value: Int(currentDuration))
            self.progressMusic.progress = currentDuration/totalDuration
            
            if (currentDuration==totalDuration) {
                var arr = [[String: String]]()
                if (playType == .fromFolder) {
                    arr = listFolderMusic
                } else {
                    arr = listHistoryMusic
                }
                if (arr.count>0) {
                    if (playerIndex<arr.count-1) {
                        playMusicAtIndex(index: playerIndex+1)
                        playerIndex += 1;
                    } else {
                        playMusicAtIndex(index: 0)
                    }
                }
            }
        }
        
    }
    
    func secondToTimeFormated(value: Int) -> String {
        let hour = value/60/60
        let minute = value/60%60
        let second = value%60
        
        let durationString = "\(hour<10 ? "0\(hour)":"\(hour)"):\(minute<10 ? "0\(minute)":"\(minute)"):\(second<10 ? "0\(second)":"\(second)")"
        return durationString
    }
    
    @IBAction func segmentedOnValueChanged(_ sender: UISegmentedControl) {
        UIView.animate(withDuration: 0.3) { [weak self] in
            self?.vTabListMusic.isHidden = sender.selectedSegmentIndex == 1
            self?.vTabHistory.isHidden = sender.selectedSegmentIndex == 0
        }
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
        while i == arrHistory.count {
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
            
            reloadTableLog()
        } catch {
            print(error.localizedDescription)
        }
    }
    
    func reloadTableLog() -> Void {
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
    
    func playMusicAtIndex(index: Int) -> Void {
        resetInterface()
        
        let music: [String: String]?
        
        if (playType == .fromFolder) {
            music = listFolderMusic[index]
        } else {
            music = listHistoryMusic[index]
        }
        if (music==nil) {
            return
        }
        
        let urlPath = music?["urlPath"]
        let item = music?["item"]
        let fullPath = "\(urlPath ?? "")\(item ?? "")"
        
        let playerAsset = AVAsset(url: URL(fileURLWithPath: fullPath))
        let playerItem = AVPlayerItem(asset: playerAsset)
        
        let metadataList = playerItem.asset.commonMetadata
        for item in metadataList {
            if item.commonKey == nil{
                continue
            }

            if let key = item.commonKey, let value = item.value {
                print(key)
                print(value)
                if key.rawValue == "title" {
                    let text = value as? String
                    lblSongName.text = text
                }
                if key.rawValue == "type" {
                    let text = value as? String
                }
                if key.rawValue == "albumName" {
                    let text = value as? String
                    lblAlbumName.text = text
                }
                if key.rawValue == "artwork" {
                    if let audioImage = UIImage(data: value as! Data) {
                        let image = audioImage
                        ivMusicThumbnail.image = image
                    }
                }
            }
        }
        
        if (lblSongName.text?.count==0) {
            lblSongName.text = item;
        }
        
        if (lblAlbumName.text?.count==0) {
            lblAlbumName.text = "Không biết album";
        }
        
        let totalDuration = Int(playerItem.asset.duration.value) / Int(playerItem.asset.duration.timescale)
        print("totalDuration = \(totalDuration)")
        self.lblMusicTotalDuration.text = secondToTimeFormated(value: totalDuration)
        
        player = AVPlayer(playerItem: playerItem)
        player.play()
        
        playerTimer?.invalidate()
        playerTimer = Timer.scheduledTimer(timeInterval: 0.2, target: self, selector: #selector(onTimerCalled), userInfo: nil, repeats: true)
        
        if (playType == .fromFolder) {
            tableFolderMusic.selectRow(at: IndexPath(row: index, section: 0), animated: true, scrollPosition: .middle)
        } else {
            tableHistory.selectRow(at: IndexPath(row: index, section: 0), animated: true, scrollPosition: .middle)
        }
        
        if (playType == .fromFolder) {
            addHistory(value: listFolderMusic[index])
        }
        
        setupRemoteTransportControls()
        setupNowPlaying()
    }
    
    func setupRemoteTransportControls() {
        // Get the shared MPRemoteCommandCenter
        let commandCenter = MPRemoteCommandCenter.shared()
        
        // Add handler for Play Command
        commandCenter.playCommand.addTarget { [unowned self] event in
            if self.player.rate == 0.0 {
                self.pauseTrack()
                return .success
            }
            return .commandFailed
        }

        // Add handler for Pause Command
        commandCenter.pauseCommand.addTarget { [unowned self] event in
            if self.player.rate == 1.0 {
                self.playTrack()
                return .success
            }
            return .commandFailed
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
    
    func pauseTrack() {
        if (player.currentItem != nil) {
            player.pause()
            playerTimer?.invalidate()
        }
    }
    
    func playTrack() {
        if (player.currentItem != nil) {
            player.play()
            playerTimer?.invalidate()
            playerTimer = Timer.scheduledTimer(timeInterval: 0.2, target: self, selector: #selector(onTimerCalled), userInfo: nil, repeats: true)
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
                self.playerIndex -= 1;
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
                self.playerIndex += 1
            } else {
                self.playMusicAtIndex(index: 0)
            }
        }
    }
    
    func setupNowPlaying() {
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
                    self.lblFolderPath.text = urlPath
                    
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

