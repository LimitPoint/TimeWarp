//
//  ScaleVideoObservable.swift
//  ScaleVideo
//
//  Read discussion at:
//  http://www.limit-point.com/blog/2022/time-warp/#scale-video-observable
//
//  Created by Joseph Pagliaro on 3/13/22.
//  Copyright © 2022 Limit Point LLC. All rights reserved.
//

import Foundation
import SwiftUI
import AVFoundation
import Combine

let kDefaultURL = Bundle.main.url(forResource: "DefaultVideo", withExtension: "mov")!
let kFireworksURL = Bundle.main.url(forResource: "Fireworks", withExtension: "mov")!
let kTwistsURL = Bundle.main.url(forResource: "Twists", withExtension: "mov")!

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
    var periodicTimeObserver:Any?
    var playingScaled = false
    var scalingLUT:[CGPoint] = []
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
    
    func loadAndPlayURL(_ url:URL) {
        self.videoURL = url
        self.play(url)
    }
    
    func loadSelectedURL(_ url:URL, completion: @escaping (Bool) -> ()) {
        
        let scoped = url.startAccessingSecurityScopedResource()
        
        copyURL(url) { copiedURL in
            
            if scoped { 
                url.stopAccessingSecurityScopedResource() 
            }
            
            DispatchQueue.main.async {
                if let copiedURL = copiedURL {
                    self.loadAndPlayURL(copiedURL)
                    completion(true)
                }
                else {
                    completion(false)
                }
            }
        }
    }
    
    func play(_ url:URL) {
        
        playingScaled = ( url == scaledVideoURL ? true : false)
        
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
                let w = c * self.modifier
                value = integrate_double_smoothstep(t, from: 1, to: self.factor, range: c-w...c+w)
            case .triangle:
                let c = 1/2.0
                let w = c * self.modifier
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
        
        let scale = integrator(1)
        
        if let videoTrack = assetresult.tracks(withMediaType: .video).first {
            let videoTrackDuration = videoTrack.timeRange.duration.seconds
            print("scaled video duration = \(videoTrackDuration)")
        }
        
        if let audioTrack = assetresult.tracks(withMediaType: .audio).first {
            let audioTrackDuration = audioTrack.timeRange.duration.seconds
            print("scaled audio duration = \(audioTrackDuration)")
        }
        
        let assetinput = AVAsset(url: self.videoURL)
        
        if let videoTrack = assetinput.tracks(withMediaType: .video).first {
            let videoTrackDuration = videoTrack.timeRange.duration.seconds
            print("original video duration = \(videoTrackDuration)")
            print("original video duration * scale = \(videoTrackDuration * scale)")
        }
        
        if let audioTrack = assetinput.tracks(withMediaType: .audio).first {
            let audioTrackDuration = audioTrack.timeRange.duration.seconds
            print("original audio duration  = \(audioTrackDuration)")
            print("original audio duration * scale  = \(audioTrackDuration * scale)")
        }
    }
    
    func scale() {
        
        self.player.pause()
        
        isScaling = true
        scalingLUT.removeAll()
        
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
                    self.isScaling = false
                    
                    if let resultURL = resultURL, self.scaleVideo?.isCancelled == false, self.scaleVideo?.outOfOrder == false {
                        self.scaledVideoURL = resultURL
                        
                        if let scalingLUT = self.scaleVideo?.scalingLUT {
                            self.scalingLUT.append(contentsOf: scalingLUT)
                        }
                        
                        self.printDurations(resultURL)
                        
                        self.playScaled()
                    }
                    else {
                        if self.scaleVideo?.isCancelled == true {
                            self.alertInfo = AlertInfo(id: .scalingFailed, title: "Scaling Cancelled", message: "The operation was cancelled.")
                        }
                        else if self.scaleVideo?.outOfOrder == true {
                            self.alertInfo = AlertInfo(id: .scalingFailed, title: "Scaling Failed", message: "Scaling produced out of order presentation times.\n\nTry different settings for factor, modifer or frame rate.")
                        }
                        else {
                            var message = (errorMessage ?? "Error message not available")
                            message += "\n\nTry different settings for factor, modifer or frame rate."
                            self.alertInfo = AlertInfo(id: .scalingFailed, title: "Scaling Failed", message: message)
                        }
                    }
                }
            })
            
            self.scaleVideo?.start()
        }
    }
    
    func cancel() {
        self.scaleVideo?.isCancelled = true
    }
    
    func prepareToExportScaledVideo() -> Bool {
        guard let url = self.scaledVideoURL else {
            self.alertInfo = AlertInfo(id: .noScaledVideoURL, title: "No Scaled Video", message: "Time scale a video and try again.")
            return false
        }
        self.player.pause() // export alert can't be dismissed while video is playing.
        videoDocument = VideoDocument(url: url)
        return true
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
        
        let videoAsset = AVAsset(url: videoURL)
        let assetDurationSeconds = videoAsset.duration.seconds
        
        let scaleFactor = integrator(1)
        
        let scaledDuration = scaleFactor * assetDurationSeconds
        
        expectedScaledDuration = secondsToString(secondsIn: scaledDuration)
        
        let estimatedFrameCount = videoAsset.estimatedFrameCount()
        let estimatedFrameRate = Double(estimatedFrameCount) / scaledDuration
        
        expectedScaledDuration += " (\(String(format: "%.2f", estimatedFrameRate)) FPS)"
    }
    
    func lookupTime(_ time:Double) -> Double? {
        
        guard scalingLUT.count > 0 else {
            return nil
        }
        
        var value:Double?
        
        let lastTime = scalingLUT[scalingLUT.count-1].y
        
            // find range of scaledTime in scalingLUT, return interpolated value
        for i in 0...scalingLUT.count-2 {
            if scalingLUT[i].x <= time && scalingLUT[i+1].x >= time {
                
                let d = scalingLUT[i+1].x - scalingLUT[i].x
                
                if d > 0 {
                    value = ((scalingLUT[i].y + (time - scalingLUT[i].x) * (scalingLUT[i+1].y - scalingLUT[i].y) / d)) / lastTime
                }
                else {
                    value = scalingLUT[i].y / lastTime
                }
                
                break
            }
        }
        
        // time may overflow end of table, use 1
        if value == nil {
            value = 1
        }
    
        return value
    }
    
    func updatePath() {
        
        var scalingFunction:(Double)->Double
        
        switch scalingType {
            case .doubleSmoothstep:
                let c = 1/4.0
                let w = c * self.modifier
                scalingFunction = {t in double_smoothstep(t, from: 1, to: self.factor, range: c-w...c+w) }
            case .triangle:
                let c = 1/2.0
                let w = c * self.modifier
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
        if let time = self.currentPlayerTime {
            
            if playingScaled {
                if let lut = lookupTime(time) {
                    currentTime = lut
                }
            }
            else {
                currentTime = time / self.videoDuration
            }
            
        }
        
        (scalingPath, minimum_y, maximum_y) = path(a: 0, b: 1, time:currentTime, subdivisions: Int(scalingPathViewFrameSize.width), frameSize: scalingPathViewFrameSize, function:scalingFunction)
        
        updateExpectedScaledDuration()
    }
}
