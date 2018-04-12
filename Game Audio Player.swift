//
//  Game Audio Player.swift
//  Created by Thiago Martins on 07/04/2018.
//  github.com/ThiagoAM
//

import SpriteKit

class GameAudioPlayer {
    
    // MARK: Properties
    private unowned var scene : SKScene
    private var audioNodes : [GameAudioNode] = [GameAudioNode]()
    private var cachedTempAudioNodes : [GameAudioNode] = [GameAudioNode]()
    private var holderNode : SKNode = SKNode()
    private var cachedAudioNodesEnabled : Bool = true
    private let audioCacheSize : Int = 32
    
    // MARK: Initialization
    init(scene : SKScene) {
        self.scene = scene
        setupHolderNode()
    }
    
    deinit {
        self.removeEveryCachedSound()
        self.removeEveryPreparedSound()
        self.removeHolder()                
    }
    
    // MARK: Public Methods
    
    /**
     Improves performance by disabling the creation of cached SKAudioNodes. Use the `setMaxConrurrentPlayback` method to setup the number of times certain sounds will be able to play at the same time.
     */
    public func disableCachedSounds() {
        self.cachedAudioNodesEnabled = false
        self.removeEveryCachedSound()
    }
    
    /**
     Enables the creation of cached SKAudioNodes.
     */
    public func enableCachedSounds() {
        self.cachedAudioNodesEnabled = true
    }
    
    /**
     Plays a sound already preapred by the `prepareSound` method. If the sound was not prepared, dot it beforehand, or use the `playSoundFileNamed` method of this class.
     */
    public func playPreparedSound(_ soundName : String, duration : TimeInterval = 1, doesLoop : Bool = false) {
        if let preparedAudioNodes = getAudioNodesFromArray(audioName: soundName) {
            var didPlayPausedSounds : Bool = false
            for audioNode in preparedAudioNodes {
                if !audioNode.isPlaying {
                    if audioNode.isPaused {
                        playAnAudioNode(audioNode, duration: duration, doesLoop: doesLoop)
                        didPlayPausedSounds = true
                    } else {
                        playAnAudioNode(audioNode, duration: duration, doesLoop: doesLoop)
                        return
                    }
                }
            }
            if !didPlayPausedSounds && cachedAudioNodesEnabled {
                playTemporaryAudioNode(named: soundName, duration: duration, doesLoop: doesLoop)
            }
        } else if cachedAudioNodesEnabled {
            playTemporaryAudioNode(named: soundName, duration: duration, doesLoop: doesLoop)
        }
    }
    
    /**
     Plays a sound using a temporary SKAudioNode. This method may negatively impact performance if called many times in a short period of time. Use the `prepareSound` method to load resources, and `playPreparedSound` to play the loaded sound for performance improvements.
     */
    public func playSoundFileNamed(_ soundFile : String, duration : TimeInterval, doesLoop : Bool) {
        playTemporaryAudioNode(named: soundFile, duration: duration, doesLoop: doesLoop)
    }
    
    /**
     Prepares a sound to be played later by the `playPreparedSound' method.
    */
    public func prepareSound(soundFileName : String) {
        let newAudioNode = GameAudioNode(fileNamed: soundFileName)
        newAudioNode.autoplayLooped = false
        newAudioNode.id = soundFileName
        newAudioNode.isPositional = false
        audioNodes.append(newAudioNode)
        holderNode.addChild(newAudioNode)
    }
    
    /**
     Prepares multiple sounds to be played later by the `playPreparedSound' method.
     */
    public func prepareSounds(soundFileNames : [String]) {
        for name in soundFileNames {
            prepareSound(soundFileName: name)
        }
    }
    
    /**
     Sets the maximum number of times a certain prepared sound can be played in a short period of time.
    */
    public func setMaxConrurrentPlayback(_ forPreparedSoundNamed : String, value : Int) {
        removePreparedSound(forPreparedSoundNamed)
        if value > 0 {
            for _ in 1...value {
                prepareSound(soundFileName: forPreparedSoundNamed)
            }
        } else {
            prepareSound(soundFileName: forPreparedSoundNamed)
        }
    }
    
    /**
     Checks if a certain prepared sound is currently playing.
    */
    public func soundIsPlaying(_ soundName : String) -> Bool {
        var isPlaying : Bool = false
        if let tempAudioNodes = getAudioNodesFromArray(audioName: soundName) {
            for audioNode in tempAudioNodes {
                if audioNode.id == soundName {
                    if audioNode.isPlaying {
                        isPlaying = true
                    } else {
                        return false
                    }
                }
            }
        }
        return isPlaying
    }
    
    /**
     Pauses a prepared sound.
    */
    public func pausePreparedSound(_ soundName : String) {
        if let preparedAudioNodes = getAudioNodesFromArray(audioName: soundName) {
            for audioNode in preparedAudioNodes {
                audioNode.isPlaying = false
                audioNode.run(.pause())
                audioNode.isPaused = true
            }
        }
    }
    
    /**
     Removes a prepared sound.
    */
    public func removePreparedSound(_ soundName : String) {
        for child in holderNode.children {
            if let audioNode = child as? GameAudioNode {
                if audioNode.id == soundName {
                    audioNode.removeFromParent()
                    audioNode.removeAllActions()
                }
            }
        }
        var counter : Int = 0
        for audioNode in self.audioNodes {
            if audioNode.id == soundName {
                self.audioNodes.remove(at: counter)
            }
            counter += 1
        }
    }
    
    /**
     Removes every prepared sound.
    */
    public func removeEveryPreparedSound() {
        for node in audioNodes {
            node.removeFromParent()
            node.removeAllActions()
        }
        audioNodes.removeAll()
    }
    
    // MARK: Private Methods
    private func removeEveryCachedSound() {
        for node in cachedTempAudioNodes {
            node.removeFromParent()
            node.removeAllActions()
        }
        cachedTempAudioNodes.removeAll()
    }
    
    private func removeHolder() {
        holderNode.removeAllChildren()
        self.holderNode.removeFromParent()
        self.holderNode.removeAllActions()
    }
    
    private func getAvailableCachedAudioNode(named : String) -> GameAudioNode? {
        for node in cachedTempAudioNodes {
            if node.id == named && node.isPlaying == false {
                return node
            }
        }
        return nil
    }
    
    private func addCachedAudioNode(node : GameAudioNode) {
        holderNode.addChild(node)
        cachedTempAudioNodes.append(node)
        if cachedTempAudioNodes.count > audioCacheSize {
            cachedTempAudioNodes.first?.removeFromParent()
            cachedTempAudioNodes.first?.removeAllActions()
            cachedTempAudioNodes.removeFirst()
        }
    }
    
    private func playTemporaryAudioNode(named : String, duration : TimeInterval, doesLoop : Bool) {
        if let cachedAudioNode = getAvailableCachedAudioNode(named: named) {
            playAnAudioNode(cachedAudioNode, duration: duration, doesLoop: doesLoop)
        } else {
            let audioNode = GameAudioNode(fileNamed: named)
            audioNode.id = named
            audioNode.autoplayLooped = doesLoop
            audioNode.isPlaying = true
            self.addCachedAudioNode(node: audioNode)
            let wait = SKAction.wait(forDuration: duration)
            audioNode.run(SKAction.sequence([.play(), wait]), completion: {
                audioNode.isPlaying = false
                audioNode.run(.stop())
            })
        }
    }
    
    private func setupHolderNode() {
        self.scene.addChild(holderNode)
        holderNode.position = CGPoint(x: UIScreen.main.bounds.width/2, y: UIScreen.main.bounds.height/2)
    }
    
    private func audioNodeIsHoldersChild(_ audioNode : GameAudioNode) -> Bool {
        for child in holderNode.children {
            if let audioNodeChild = child as? GameAudioNode {
                if audioNodeChild == audioNode {
                    return true
                }
            }
        }
        return false
    }
    
    private func playAnAudioNode(_ audioNode : GameAudioNode, duration : TimeInterval, doesLoop : Bool) {
        audioNode.autoplayLooped = doesLoop
        audioNode.isPaused = false
        audioNode.isPlaying = true
        if !doesLoop {
            let wait = SKAction.wait(forDuration: duration)
            let sequence = SKAction.sequence([.play(), wait])
            audioNode.run(sequence, completion: {
                audioNode.isPlaying = false
                audioNode.run(.stop())
            })
        } else {
            audioNode.run(.play())
        }
    }
    
    private func getAudioNodesFromArray(audioName : String) -> [GameAudioNode]? {
        var tempAudioNodes = [GameAudioNode]()
        for audioNode in self.audioNodes {
            if audioNode.id == audioName {
                tempAudioNodes.append(audioNode)
            }
        }
        if !tempAudioNodes.isEmpty {
            return tempAudioNodes
        } else {
            return nil
        }
    }
    
    // MARK: GameAudioNode Class
    class GameAudioNode : SKAudioNode {
        var id : String = ""
        var maxSimultaneousPlayback : Int = 1
        var isPlaying : Bool = false
    }
}

