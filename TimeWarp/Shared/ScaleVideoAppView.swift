//
//  ScaleVideoAppView.swift
//  Shared
//
//  Read discussion at:
//  http://www.limit-point.com/blog/2022/time-warp/
//
//  Created by Joseph Pagliaro on 3/13/22.
//  Copyright © 2022 Limit Point LLC. All rights reserved.
//

import SwiftUI

struct ScaleVideoAppView: View {
    
    @ObservedObject var scaleVideoObservable:ScaleVideoObservable 
    
    var body: some View {
        if scaleVideoObservable.isScaling {
            ScaleProgressView(scaleVideoObservable: scaleVideoObservable)
        }
        else {
            ScrollView {
                VStack {
                    HeaderView(scaleVideoObservable: scaleVideoObservable)
                    
                    PickVideoView(scaleVideoObservable: scaleVideoObservable)
                    
                    PlotView(scaleVideoObservable: scaleVideoObservable)
                        .frame(minHeight: 300)
                    
                    Button(action: { scaleVideoObservable.scale() }, label: {
                        Label("Scale", systemImage: "timelapse")
                    })
                    
                    ScaleOptionsView(scaleVideoObservable: scaleVideoObservable)
                        .frame(minHeight: 300)
                }
                .alert(item: $scaleVideoObservable.alertInfo, content: { alertInfo in
                    Alert(title: Text(alertInfo.title), message: Text(alertInfo.message))
                })
            }
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ScaleVideoAppView(scaleVideoObservable: ScaleVideoObservable())
    }
}
