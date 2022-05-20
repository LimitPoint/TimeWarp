//
//  ScaleVideoAppView.swift
//  Shared
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
            VStack {
                HeaderView(scaleVideoObservable: scaleVideoObservable)
                PickVideoView(scaleVideoObservable: scaleVideoObservable)
                HStack {
                    ScaleOptionsView(scaleVideoObservable: scaleVideoObservable)
                    PlotView(scaleVideoObservable: scaleVideoObservable)
                }
            }
            .alert(item: $scaleVideoObservable.alertInfo, content: { alertInfo in
                Alert(title: Text(alertInfo.title), message: Text(alertInfo.message))
            })
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ScaleVideoAppView(scaleVideoObservable: ScaleVideoObservable())
    }
}
