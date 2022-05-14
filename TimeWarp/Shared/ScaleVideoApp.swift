//
//  ScaleVideoApp.swift
//  Shared
//
//  Created by Joseph Pagliaro on 3/13/22.
//  Copyright © 2022 Limit Point LLC. All rights reserved.
//

import SwiftUI

enum ScaleFunctionTestType: CaseIterable {
    case fastNormal
    case normalFast
    case normalSlow
    case slowNormal
    case cosine3
    case cosine6
    case sqrt
    case oneOverSqrt
    case linear
    case half
    case double
}

func testScaleVideo(scaleType:ScaleFunctionTestType) {
    
    var filename:String
    
    switch scaleType {
        case .fastNormal:
            filename = "fast-normal.mov"
        case .normalFast:
            filename = "normal-fast.mov"
        case .normalSlow:
            filename = "normal-slow.mov"
        case .slowNormal:
            filename = "slow-normal.mov"
        case .cosine3:
            filename = "cosine3.mov"
        case .cosine6:
            filename = "cosine6.mov"
        case .sqrt:
            filename = "sqrt.mov"
        case .oneOverSqrt:
            filename = "oneOverSqrt.mov"
        case .linear:
            filename = "linear.mov"
        case .half:
            filename = "half.mov"
        case .double:
            filename = "double.mov"
    }
    
    func integrator(_ t:Double) -> Double {
        
        var value:Double?
        
        switch scaleType {
            case .fastNormal:
                value = integrate(t, integrand: { t in 
                    mapunit(1, 0.1, smoothstep_flip_on(0, 1, t))
                })
            case .normalFast:
                value = integrate(t, integrand: { t in 
                    mapunit(0.1, 1, smoothstep_flip_on(0, 1, t))
                })
            case .normalSlow:
                value = integrate(t, integrand: { t in 
                    mapunit(1, 3, smoothstep_on(0, 1, t))
                })
            case .slowNormal:
                value = integrate(t, integrand: { t in 
                    mapunit(3, 1, smoothstep_on(0, 1, t))
                })
            case .cosine3:
                value = integrate(t, integrand: { t in 
                    cos(6 * .pi * t) + 1
                })
            case .cosine6:
                value = integrate(t, integrand: { t in 
                    cos(12 * .pi * t) + 1
                })
            case .sqrt:
                value = integrate(t, integrand: { t in 
                    sqrt(2 * t + 1.0 / Double(9))
                })
            case .oneOverSqrt:
                value = integrate(t, integrand: { t in 
                    1.0 / sqrt(2 * t + 1.0 / Double(9))
                })
            case .linear:
                value = integrate(t, integrand: { t in 
                    t
                })
            case .half:
                value = integrate(t, integrand: { t in 
                    2
                })
            case .double:
                value = integrate(t, integrand: { t in 
                    1/2.0
                })
        }
        
        return value!
    } 
    
    let fm = FileManager.default
    let docsurl = try! fm.url(for:.documentDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
    
    let destinationPath = docsurl.appendingPathComponent(filename).path
    let scaleVideo = ScaleVideo(path: kDefaultURL.path, frameRate: 30, destination: destinationPath, integrator: integrator, progress: { p, _ in
        print("p = \(p)")
    }, completion: { result, error in
        print("result = \(String(describing: result))")
    })
    
    scaleVideo?.start()
}

@main
struct ScaleVideoApp: App {
        
    init() {
        FileManager.clearDocuments()
        
        // Go to Documents to see output:
        
        // iterate all tests:
        //let _ = ScaleFunctionTestType.allCases .map({ testScaleVideo(scaleType: $0) })
        
        // or try individually:
        /*
         testScaleVideo(scaleType: .fastNormal)
         testScaleVideo(scaleType: .normalFast)
         testScaleVideo(scaleType: .slowNormal)
         testScaleVideo(scaleType: .normalSlow)
         testScaleVideo(scaleType: .cosine3)
         testScaleVideo(scaleType: .cosine6)
         testScaleVideo(scaleType: .sqrt)
         testScaleVideo(scaleType: .oneOverSqrt)
         testScaleVideo(scaleType: .linear)
         testScaleVideo(scaleType: .half)
         testScaleVideo(scaleType: .double)
         */
    }
    
    var body: some Scene {
        WindowGroup {
            ScaleVideoAppView(scaleVideoObservable: ScaleVideoObservable())
        }
    }
}
