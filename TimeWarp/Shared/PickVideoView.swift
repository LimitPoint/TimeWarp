//
//  PickVideoView.swift
//  ScaleVideo
//
//  Created by Joseph Pagliaro on 3/14/22. 
//  Copyright © 2022 Limit Point LLC. All rights reserved.
//

import SwiftUI
import AVKit

let tangerine = Color(red: 0.98, green: 0.57, blue: 0.21, opacity:0.9)

struct PickVideoView: View {
    
    @ObservedObject var scaleVideoObservable:ScaleVideoObservable 
    
    @State private var showFileImporter: Bool = false
    @State private var showFileExporter: Bool = false
    
    @State private var showURLLoadingProgress = false
    
    var body: some View {
        VStack {
            
            HStack {
                
                Button(action: { scaleVideoObservable.loadAndPlayURL(kDefaultURL) }, label: {
                    Label("Default", systemImage: "cube.fill")
                })
                
                Button(action: { scaleVideoObservable.loadAndPlayURL(kFireworksURL) }, label: {
                    Label("Fireworks", systemImage: "flame")
                })
                
                Button(action: { scaleVideoObservable.loadAndPlayURL(kTwistsURL) }, label: {
                    Label("Music", systemImage: "music.note")
                })
            }
            .padding()
            
            Button(action: { showFileImporter = true }, label: {
                Label("Import", systemImage: "square.and.arrow.down")
            })
            
            VideoPlayer(player: scaleVideoObservable.player)
                .frame(minHeight: 300)
            
            Text(scaleVideoObservable.videoURL.lastPathComponent)
            
            HStack {
                Button(action: { scaleVideoObservable.playOriginal() }, label: {
                    Label("Video", systemImage: "play.circle")
                })
                
                Button(action: { scaleVideoObservable.playScaled() }, label: {
                    Label("Scaled", systemImage: "play.circle.fill")
                })
                
                Button(action: { 
                    if scaleVideoObservable.prepareToExportScaledVideo() {
                        showFileExporter = true 
                    }
                }, label: {
                    Label("Export", systemImage: "square.and.arrow.up.fill")
                })
            }
            .padding()
        }
        .padding()
        .fileExporter(isPresented: $showFileExporter, document: scaleVideoObservable.videoDocument, contentType: UTType.quickTimeMovie, defaultFilename: scaleVideoObservable.videoDocument?.filename) { result in
            if case .success = result {
                do {
                    let exportedURL: URL = try result.get()
                    scaleVideoObservable.alertInfo = AlertInfo(id: .exporterSuccess, title: "Scaled Video Saved", message: exportedURL.lastPathComponent)
                }
                catch {
                    
                }
            } else {
                scaleVideoObservable.alertInfo = AlertInfo(id: .exporterFailed, title: "Scaled Video Not Saved", message: (scaleVideoObservable.videoDocument?.filename ?? ""))
            }
        }
        .fileImporter(isPresented: $showFileImporter, allowedContentTypes: [.movie, .quickTimeMovie, .mpeg4Movie], allowsMultipleSelection: false) { result in
            do {
                showURLLoadingProgress = true
                guard let selectedURL: URL = try result.get().first else { return }
                scaleVideoObservable.loadSelectedURL(selectedURL) { wasLoaded in
                    if !wasLoaded {
                        scaleVideoObservable.alertInfo = AlertInfo(id: .urlNotLoaded, title: "Video Not Loaded", message: (scaleVideoObservable.errorMesssage ?? "No information available."))
                    }
                    showURLLoadingProgress = false
                }
            } catch {
                print(error.localizedDescription)
            }
        }
        .alert(item: $scaleVideoObservable.alertInfo, content: { alertInfo in
            Alert(title: Text(alertInfo.title), message: Text(alertInfo.message))
        })
        .overlay(Group {
            if showURLLoadingProgress {          
                ProgressView("Loading...")
                    .padding()
                    .background(RoundedRectangle(cornerRadius: 16).fill(tangerine))
            }
        })
    }
}

struct PickVideoView_Previews: PreviewProvider {
    static var previews: some View {
        PickVideoView(scaleVideoObservable: ScaleVideoObservable())
    }
}
