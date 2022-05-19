//
//  ScaleOptionsView.swift
//  ScaleVideo
//
//  Created by Joseph Pagliaro on 3/15/22.
//  Copyright © 2022 Limit Point LLC. All rights reserved.
//

import SwiftUI

struct ScaleOptionsView: View {
    @ObservedObject var scaleVideoObservable: ScaleVideoObservable
    
    @State private var isEditing = false
    
    var body: some View {
        
        VStack {
            Text(String(format: "%.2f", scaleVideoObservable.factor))
                .foregroundColor(isEditing ? .red : .blue)
            Slider(
                value: $scaleVideoObservable.factor,
                in: 0.1...2
            ) {
                Text("Factor")
            } minimumValueLabel: {
                Text("0.1")
            } maximumValueLabel: {
                Text("2")
            } onEditingChanged: { editing in
                isEditing = editing
            }
            
            
            Picker("Scaling", selection: $scaleVideoObservable.scalingType) {
                ForEach(ScaleFunctionType.allCases) { scalingType in
                    Text(scalingType.rawValue.capitalized)
                }
            }
            
            Group {
                Text(String(format: "%.2f", scaleVideoObservable.modifier))
                    .foregroundColor(isEditing ? .red : .blue) 
                Slider(
                    value: $scaleVideoObservable.modifier,
                    in: 0.1...1
                ) {
                    Text("Modifier")
                } minimumValueLabel: {
                    Text("0.1")
                } maximumValueLabel: {
                    Text("1")
                } onEditingChanged: { editing in
                    isEditing = editing
                }
                
            }
            .opacity((scaleVideoObservable.scalingType != .constant ? 1 : 0))
            .animation(.easeIn)
            
            Picker("Frame Rate", selection: $scaleVideoObservable.fps) {
                Text("24").tag(FPS.twentyFour)
                Text("30").tag(FPS.thirty)
                Text("60").tag(FPS.sixty)
                Text("Any").tag(FPS.any)
            }
            .pickerStyle(.segmented)
            
            Button(action: { scaleVideoObservable.scale() }, label: {
                Label("Scale", systemImage: "timelapse")
            })
            .padding()
            
        }
        .padding()
    }
}

struct ScaleOptionsView_Previews: PreviewProvider {
    static var previews: some View {
        ScaleOptionsView(scaleVideoObservable: ScaleVideoObservable())
    }
}
