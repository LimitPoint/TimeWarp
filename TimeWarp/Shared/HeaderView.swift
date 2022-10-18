//
//  HeaderView.swift
//  ScaleAudio
//
//  Read discussion at:
//  http://www.limit-point.com/blog/2022/time-warp/
//
//  Created by Joseph Pagliaro on 2/11/22.
//  Copyright © 2022 Limit Point LLC. All rights reserved.
//

import SwiftUI

struct HeaderView: View {
    
    @ObservedObject var scaleVideoObservable: ScaleVideoObservable
    
    var body: some View {
        VStack {
            Text("Files generated into Documents folder")
                .fontWeight(.bold)
                .padding(2)
                .multilineTextAlignment(.center)
            Text("Select instantaneous time scaling function below.")
                .multilineTextAlignment(.center)
                .padding(2)
#if os(macOS)
            Button("Go to Documents", action: { 
                NSWorkspace.shared.open(scaleVideoObservable.documentsURL)
            }).padding(2)
#endif
        }
    }
}

struct HeaderView_Previews: PreviewProvider {
    static var previews: some View {
        HeaderView(scaleVideoObservable: ScaleVideoObservable())
    }
}
