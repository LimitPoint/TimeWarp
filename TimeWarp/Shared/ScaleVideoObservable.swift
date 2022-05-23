//
//  ScaleVideoObservable.swift
//  ScaleVideo
//
//  Created by Joseph Pagliaro on 3/13/22.
//  Copyright © 2022 Limit Point LLC. All rights reserved.
//

import Foundation
import SwiftUI
import AVFoundation
import Combine

let kDefaultURL = Bundle.main.url(forResource: "DefaultVideo", withExtension: "mov")!

enum FPS: Int, CaseIterable, Identifiable {
    case any = 0, twentyFour = 24, thirty = 30, sixty = 60
    var id: Self { self }
}

enum ScaleFunctionType: String, CaseIterable, Identifiable {
    case doubleSmoothstep = "Double Smooth Step"
    case triangle = "Triangle"
    case cosine = "Cosine"
    case taperedCosine = "Tapered Cosine"
    case constant = "Constant"
    case power = "Power"
    var id: Self { self }
}

struct AlertInfo: Identifiable {
    
    enum AlertType {
        case urlNotLoaded
        case exporterSuccess
        case exporterFailed
        case scalingFailed
        case noScaledVideoURL
    }
    
    let id: AlertType
    let title: String
    let message: String
}

class ScaleVideoObservable:ObservableObject {
    
    var videoURL:URL {
        didSet {
            self.videoDuration = AVAsset(url: videoURL).duration.seconds
        }
    }
    var videoDuration:Double = 0
    var scaledVideoURL:URL?
    var documentsURL:URL
    var scaleVideo:ScaleVideo?
    var videoDocument:VideoDocument?
    
    @Published var progressFrameImage:CGImage?
    @Published var progress:Double = 0
    @Published var progressTitle:String = "Progress"
    @Published var isScaling:Bool = false
    @Published var alertInfo: AlertInfo?
    
    @Published var factor:Double = 1.5 // 0.1 to 2
    @Published var modifier:Double = 0.5 // 0.1 to 1
    @Published var fps:FPS = .sixty
    
    @Published var scalingPath = Path()
    var maximum_y:Double = 0
    var minimum_y:Double = 0
    @Published var expectedScaledDuration:String = ""
    @Published var scalingPathViewFrameSize:CGSize = .zero
    @Published var scalingType:ScaleFunctionType = .doubleSmoothstep
    var cancelBag = Set<AnyCancellable>()
    
    var errorMesssage:String?
    
    @Published var player:AVPlayer
    var currentPlayerDuration:Double?
    @Published var currentPlayerTime:Double?
    
    init() {
        
        videoURL = kDefaultURL
        videoDuration = AVAsset(url: videoURL).duration.seconds
        
        player = AVPlayer(url: videoURL)
        
        documentsURL = try! FileManager.default.url(for:.documentDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
        print("path = \(documentsURL.path)")

        #if os(iOS)        
        if let uiimage = UIImage(named: "ScaleVideo.png") {
            progressFrameImage = uiimage.cgImage
        }
        #else
        if let nsimage = NSImage(named: "ScaleVideo.png") {
            progressFrameImage = nsimage.cgImage(forProposedRect:nil, context: nil, hints: nil)
        }
        #endif
        
        self.updatePath()
        
        $scalingPathViewFrameSize.sink { _ in
            DispatchQueue.main.async {
                self.updatePath()
            }
            
        }
        .store(in: &cancelBag)
        
        $factor.sink { _ in
            DispatchQueue.main.async {
                self.updatePath()
            }
            
        }
        .store(in: &cancelBag)
        
        $modifier.sink { _ in
            DispatchQueue.main.async {
                self.updatePath()
            }
            
        }
        .store(in: &cancelBag)
        
        $scalingType.sink { _ in
            DispatchQueue.main.async {
                self.updatePath()
            }
            
        }
        .store(in: &cancelBag)
        
        $currentPlayerTime.sink { _ in
            DispatchQueue.main.async {
                self.updatePath()
            }
            
        }
        .store(in: &cancelBag)
        
        $player.sink { _ in
            DispatchQueue.main.async {
                self.updateExpectedScaledDuration()
            }
            
        }
        .store(in: &cancelBag)
    }
    
    func tryDownloadingUbiquitousItem(_ url: URL, completion: @escaping (URL?) -> ()) {
        
        var downloadedURL:URL?
        
        if FileManager.default.isUbiquitousItem(at: url) {
            
            let queue = DispatchQueue(label: "com.limit-point.startDownloadingUbiquitousItem")
            let group = DispatchGroup()
            group.enter()
            
            DispatchQueue.global(qos: .userInteractive).asyncAfter(deadline: .now()) {
                
                do {
                    try FileManager.default.startDownloadingUbiquitousItem(at: url)
                    let error:NSErrorPointer = nil
                    let coordinator = NSFileCoordinator(filePresenter: nil)
                    coordinator.coordinate(readingItemAt: url, options: NSFileCoordinator.ReadingOptions.withoutChanges, error: error) { readURL in
                        downloadedURL = readURL
                    }
                    if let error = error {
                        self.errorMesssage = error.pointee?.localizedFailureReason
                        print("Can't download the URL: \(self.errorMesssage ?? "No avaialable error from NSFileCoordinator")")
                    }
                    group.leave()
                }
                catch {
                    self.errorMesssage = error.localizedDescription
                    print("Can't download the URL: \(error.localizedDescription)")
                    group.leave()
                }
            }
            
            group.notify(queue: queue, execute: {
                completion(downloadedURL)
            })
        }
        else {
            self.errorMesssage = "URL is not ubiquitous item"
            completion(nil)
        }
    }
    
    func copyURL(_ url: URL, completion: @escaping (URL?) -> ()) {
        
        let filename = url.lastPathComponent
        
        if let copiedURL = FileManager.documentsURL("\(filename)") {
            
            try? FileManager.default.removeItem(at: copiedURL)
            
            do {
                try FileManager.default.copyItem(at: url, to: copiedURL)
                completion(copiedURL)
            }
            catch {
                tryDownloadingUbiquitousItem(url) { downloadedURL in
                    
                    if let downloadedURL = downloadedURL {
                        do {
                            try FileManager.default.copyItem(at: downloadedURL, to: copiedURL)
                            completion(copiedURL)
                        }
                        catch {
                            self.errorMesssage = error.localizedDescription
                            completion(nil)
                        }
                    }
                    else {
                        self.errorMesssage = error.localizedDescription
                        completion(nil)
                    }
                }
            }
        }
        else {
            completion(nil)
        }
    }
    
    func loadSelectedURL(_ url:URL, completion: @escaping (Bool) -> ()) {
        
        let scoped = url.startAccessingSecurityScopedResource()
        
        copyURL(url) { copiedURL in
            
            if scoped { 
                url.stopAccessingSecurityScopedResource() 
            }
            
            DispatchQueue.main.async {
                if let copiedURL = copiedURL {
                    self.videoURL = copiedURL
                    
                    self.play(copiedURL)
                    completion(true)
                }
                else {
                    completion(false)
                }
            }
        }
    }
    
    var periodicTimeObserver:Any?
    
    func play(_ url:URL) {
        
        if let periodicTimeObserver = periodicTimeObserver {
            self.player.removeTimeObserver(periodicTimeObserver)
        }
        
        self.player.pause()
        self.player = AVPlayer(url: url)
        
        self.currentPlayerDuration = AVAsset(url: url).duration.seconds
        periodicTimeObserver = self.player.addPeriodicTimeObserver(forInterval: CMTime(value: 1, timescale: 30), queue: nil) { [weak self] cmTime in
            self?.currentPlayerTime = cmTime.seconds
        }
        
        DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + .milliseconds(500)) { () -> Void in
            self.player.play()
        }
        
    }
    
    func playOriginal() {
        play(videoURL)
    }
    
    func playScaled() {
        guard let url = self.scaledVideoURL else {
            self.alertInfo = AlertInfo(id: .noScaledVideoURL, title: "No Scaled Video", message: "Time scale a video and try again.")
            return
        }
        play(url)
    }
    
    func integrator(_ t:Double) -> Double {
        
        var value:Double?
        
        switch scalingType {
            case .doubleSmoothstep:
                let c = 1/4.0
                let w = (self.modifier == 1 ? c * 0.99 : c * self.modifier)  
                value = integrate_double_smoothstep(t, from: 1, to: self.factor, range: c-w...c+w)
            case .triangle:
                let c = 1/2.0
                let w = (self.modifier == 1 ? c * 0.99 : c * self.modifier)  
                value = integrate_triangle(t, from: 1, to: self.factor, range: c-w...c+w)
            case .cosine:
                value = integrate(t, integrand: { t in 
                    cosine(t, factor: self.factor, modifier: self.modifier)
                })
            case .taperedCosine:
                value = integrate(t, integrand: { t in 
                    tapered_cosine(t, factor: self.factor, modifier: self.modifier)
                })
            case .constant:
                value = integrate(t, integrand: { t in 
                    constant(t, factor: self.factor)
                })
            case .power:
                value = integrate(t, integrand: { t in 
                    power(t, factor: self.factor, modifier: self.modifier)
                })
        } 
        
        return value ?? 1
    }
    
    func printDurations(_ resultURL:URL) {
        let assetresult = AVAsset(url: resultURL)
        
        if let videoTrack = assetresult.tracks(withMediaType: .video).first {
            let videoTrackDuration = CMTimeGetSeconds(videoTrack.timeRange.duration)
            print("scaled video duration = \(videoTrackDuration)")
        }
        
        if let audioTrack = assetresult.tracks(withMediaType: .audio).first {
            let audioTrackDuration = CMTimeGetSeconds(audioTrack.timeRange.duration)
            print("scaled audio duration = \(audioTrackDuration)")
        }
        
        let assetinput = AVAsset(url: self.videoURL)
        
        if let videoTrack = assetinput.tracks(withMediaType: .video).first {
            let videoTrackDuration = CMTimeGetSeconds(videoTrack.timeRange.duration)
            print("original video duration = \(videoTrackDuration)")
        }
        
        if let audioTrack = assetinput.tracks(withMediaType: .audio).first {
            let audioTrackDuration = CMTimeGetSeconds(audioTrack.timeRange.duration)
            print("original audio duration  = \(audioTrackDuration)")
        }
    }
    
    func scale() {
        
        self.player.pause()
        
        isScaling = true
        
        let filename = self.videoURL.deletingPathExtension().lastPathComponent + "-scaled.mov"
        
        let destinationPath = FileManager.documentsURL("\(filename)")!.path 
                    
        DispatchQueue.global(qos: .userInitiated).async {
            
            var lastDate = Date()
            var updateProgressImage = true
            var totalElapsed:TimeInterval = 0
            
            self.scaleVideo = ScaleVideo(path: self.videoURL.path, frameRate: Int32(self.fps.rawValue), destination: destinationPath, integrator: self.integrator, progress: { (value, ciimage) in
                
                DispatchQueue.main.async {
                    self.progress = value
                    self.progressTitle = "Progress \(String(format: "%.2f", value * 100))%"
                }
                
                let elapsed = Date().timeIntervalSince(lastDate)
                lastDate = Date()
                
                totalElapsed += elapsed
                
                if totalElapsed > 0.3 && updateProgressImage {
                    
                    updateProgressImage = false
                    
                    totalElapsed = 0
                    
                    var previewImage:CGImage?
                    
                    autoreleasepool {
                        if let image = ciimage {
                            previewImage = image.cgimage()
                        }
                    }
                    
                    DispatchQueue.main.async {
                        autoreleasepool {
                            if let previewImage = previewImage {
                                self.progressFrameImage = previewImage
                            }
                        }
                        
                        updateProgressImage = true
                    }
                }
                
            }, completion: { (resultURL, errorMessage) in
                                
                DispatchQueue.main.async {
                    
                    self.progress = 0
                    
                    if let resultURL = resultURL, self.scaleVideo?.isCancelled == false {
                        self.scaledVideoURL = resultURL
                        self.printDurations(resultURL)
                    }
                    else {
                        self.scaledVideoURL = kDefaultURL
                        
                        var message = (errorMessage ?? "Error message not available")
                        message += "\nTry different settings (factor, modifer, frame rate)"
                        self.alertInfo = AlertInfo(id: .scalingFailed, title: "Scaling Failed", message: message)
                    }
                    
                    self.playScaled()
                    
                    self.isScaling = false
                }
            })
            
            self.scaleVideo?.start()
        }
    }
    
    func cancel() {
        self.scaleVideo?.isCancelled = true
    }
    
    func prepareToExportScaledVideo() {
        guard let url = self.scaledVideoURL else {
            self.alertInfo = AlertInfo(id: .noScaledVideoURL, title: "No Scaled Video", message: "Time scale a video and try again.")
            return
        }
        videoDocument = VideoDocument(url: url)
    }
    
    func secondsToString(secondsIn:Double) -> String {
        
        if CGFloat(secondsIn) > (CGFloat.greatestFiniteMagnitude / 2.0) {
            return "∞"
        }
        
        let secondsRounded = round(secondsIn)
        
        let hours:Int = Int(secondsRounded / 3600)
        
        let minutes:Int = Int(secondsRounded.truncatingRemainder(dividingBy: 3600) / 60)
        let seconds:Int = Int(secondsRounded.truncatingRemainder(dividingBy: 60))
        
        
        if hours > 0 {
            return String(format: "%i:%02i:%02i", hours, minutes, seconds)
        } else {
            return String(format: "%02i:%02i", minutes, seconds)
        }
    }
    
    func updateExpectedScaledDuration() {
        
        let assetDurationSeconds = AVAsset(url: videoURL).duration.seconds
        
        let scaleFactor = integrator(1)
        
        expectedScaledDuration = secondsToString(secondsIn: scaleFactor * assetDurationSeconds)
    }
    
    func updatePath() {
        
        var scalingFunction:(Double)->Double
        
        switch scalingType {
            case .doubleSmoothstep:
                let c = 1/4.0
                let w = (self.modifier == 1 ? c * 0.99 : c * self.modifier)  
                scalingFunction = {t in double_smoothstep(t, from: 1, to: self.factor, range: c-w...c+w) }
            case .triangle:
                let c = 1/2.0
                let w = (self.modifier == 1 ? c * 0.99 : c * self.modifier)  
                scalingFunction = {t in triangle(t, from: 1, to: self.factor, range: c-w...c+w) }
            case .cosine:
                scalingFunction = {t in cosine(t, factor: self.factor, modifier: self.modifier) }
            case .taperedCosine:
                scalingFunction = {t in tapered_cosine(t, factor: self.factor, modifier: self.modifier) }
            case .constant:
                scalingFunction = {t in constant(t, factor: self.factor)}
            case .power:
                scalingFunction = {t in power(t, factor: self.factor, modifier: self.modifier) }
        }
        
        var currentTime:Double = 0
        if let time = self.currentPlayerTime, let duration = self.currentPlayerDuration {
            currentTime = time / duration
        }
        
        (scalingPath, minimum_y, maximum_y) = path(a: 0, b: 1, time:currentTime, subdivisions: Int(scalingPathViewFrameSize.width), frameSize: scalingPathViewFrameSize, function:scalingFunction)
        
        updateExpectedScaledDuration()
    }
}
