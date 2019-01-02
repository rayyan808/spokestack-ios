//
//  AudioEngineController.swift
//  SpokeStack
//
//  Created by Cory D. Wiles on 12/10/18.
//  Copyright © 2018 Pylon AI, Inc. All rights reserved.
//

import Foundation
import AVFoundation

protocol AudioEngineControllerDelegate: AnyObject {
    
    func didStart(_ engineController: AudioEngineController) -> Void
    func didStop(_ engineController: AudioEngineController) -> Void
    func didReceive(_ buffer: AVAudioPCMBuffer) -> Void
}

public enum AudioEngineControllerError: Error {
    case failedToSTart(message: String)
}

final class AudioEngineController {
    
    // MARK: Internal (properties)
    
    weak var delegate: AudioEngineControllerDelegate?
    
    // MARK: Private (properties)
    
    private let bufferSize: Int

    private var engine: AVAudioEngine = AVAudioEngine()
    
    private var audioBuffer: AVAudioPCMBuffer = AVAudioPCMBuffer()
    
    // MARK: Initializers
    
    deinit {
        engine.stop()
        engine.reset()
    }
    
    init(_ buffer: Int) {
        
        self.engine.stop()
        self.engine.reset()
        self.engine = AVAudioEngine()
        self.bufferSize = buffer
        
        do {
            
            try AVAudioSession.sharedInstance().setCategory(.playAndRecord,
                                                            mode: .spokenAudio,
                                                            options: .defaultToSpeaker)
            
            let ioBufferDuration = Double(self.bufferSize) / 48000.0
            try AVAudioSession.sharedInstance().setPreferredIOBufferDuration(ioBufferDuration)
            try AVAudioSession.sharedInstance().setActive(true, options: .notifyOthersOnDeactivation)
            
        } catch {
            
            assertionFailure("AVAudioSession setup error: \(error)")
        }
    }
    
    // MARK: Internal (methods)
    
    func startRecording() throws -> Void {
        
        let node: AVAudioInputNode = self.engine.inputNode
        let outputFormat: AVAudioFormat = node.outputFormat(forBus: 0)
        let bufferSize: AVAudioFrameCount = AVAudioFrameCount(self.bufferSize)

        print("formatDescription \(outputFormat.formatDescription)")
        print("sampleRate \(outputFormat.sampleRate)")
        print("streamDescription \(outputFormat.streamDescription)")
        print("settings \(outputFormat.settings)")

        node.installTap(onBus: 0,
                         bufferSize: bufferSize,
                         format: outputFormat,
                         block: {[weak self] buffer, time in

                            guard let strongSelf = self else {
                                return
                            }

                            print("buffer coming back \(Int(buffer.frameLength)) and time \(time) and capacity \(buffer.frameCapacity)")                            
                            strongSelf.delegate?.didReceive(buffer)
                            
        })
        
        do {
            
            self.engine.prepare()
            try self.engine.start()
            
            self.delegate?.didStart(self)

        } catch let error {
            
            throw AudioEngineControllerError.failedToSTart(message: error.localizedDescription)
        }
    }
    
    func stopRecording() -> Void {
        
        self.engine.mainMixerNode.removeTap(onBus: 0)
        self.engine.stop()
        self.delegate?.didStop(self)
    }
}