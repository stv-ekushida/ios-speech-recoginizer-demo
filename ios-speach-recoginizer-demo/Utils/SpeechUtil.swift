//
//  SpeechUtil.swift
//  ios-speach-recoginizer-demo
//
//  Created by Kushida　Eiji on 2017/02/24.
//  Copyright © 2017年 Kushida　Eiji. All rights reserved.
//

import Foundation
import Speech

protocol SpeechResultDelegate {
    func setButtonStatus(isEnabled: Bool)
    func setGuideMessage(message: String)
    func setResult(result: String)
}

final class SpeechUtil: NSObject {
    
    var delegate: SpeechResultDelegate?
    
    private let speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "ja-JP"))!
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private let audioEngine = AVAudioEngine()
    
    /// 認証処理
    func requestRecognizerAuthorization() {
        SFSpeechRecognizer.requestAuthorization { authStatus in
            
            // メインスレッドで処理したい内容のため、OperationQueue.main.addOperationを使う
            OperationQueue.main.addOperation { [weak self] in
                
                guard let `self` = self else { return }
                
                switch authStatus {
                case .authorized:
                    self.delegate?.setButtonStatus(isEnabled: true)
                    self.speechRecognizer.delegate = self as SFSpeechRecognizerDelegate?
                    
                case .denied:
                    self.delegate?.setButtonStatus(isEnabled: false)
                    self.delegate?.setGuideMessage(message: "音声認識へのアクセスが拒否されています")
                    
                case .restricted:
                    self.delegate?.setButtonStatus(isEnabled: false)
                    self.delegate?.setGuideMessage(message: "この端末で音声認識はできません。")
                    
                case .notDetermined:
                    self.delegate?.setButtonStatus(isEnabled: false)
                    self.delegate?.setGuideMessage(message: "音声認識はまだ許可されていません。")
                }
            }
        }
    }
    
    /// 録音開始
    func startRecording() throws {
        refreshTask()
        
        let audioSession = AVAudioSession.sharedInstance()
        // 録音用のカテゴリをセット
        try audioSession.setCategory(AVAudioSessionCategoryRecord)
        try audioSession.setMode(AVAudioSessionModeMeasurement)
        try audioSession.setActive(true, with: .notifyOthersOnDeactivation)
        
        recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
        
        guard let inputNode = audioEngine.inputNode else {
            fatalError("Audio engine has no input node")
        }
        guard let recognitionRequest = recognitionRequest else {
            fatalError("Unable to created a SFSpeechAudioBufferRecognitionRequest object")
        }
        
        // 録音が完了する前のリクエストを作るかどうかのフラグ。
        // trueだと現在-1回目のリクエスト結果が返ってくる模様。falseだとボタンをオフにしたときに音声認識の結果が返ってくる設定。
        recognitionRequest.shouldReportPartialResults = true
        
        recognitionTask = speechRecognizer.recognitionTask(with: recognitionRequest) { [weak self] result, error in

            guard let `self` = self else { return }
            var isFinal = false
            
            if let result = result {
                self.delegate?.setResult(result: result.bestTranscription.formattedString)
                isFinal = result.isFinal
                
                print("---- \(self.kanaHenkan(text: result.bestTranscription.formattedString)) ----")
            }
            
            // エラーがある、もしくは最後の認識結果だった場合の処理
            if error != nil || isFinal {
                self.audioEngine.stop()
                inputNode.removeTap(onBus: 0)
                
                self.recognitionRequest = nil
                self.recognitionTask = nil
                self.delegate?.setButtonStatus(isEnabled: true)
            }
        }
        
        // マイクから取得した音声バッファをリクエストに渡す
        let recordingFormat = inputNode.outputFormat(forBus: 0)
        inputNode.installTap(onBus: 0,
                             bufferSize: 1024,
                             format: recordingFormat) { [weak self](buffer: AVAudioPCMBuffer, when: AVAudioTime) in
                                self?.recognitionRequest?.append(buffer)
        }
        
        try startAudioEngine()
    }
    
    /// 録音停止
    func stopRecording() {
        
        audioEngine.stop()
        recognitionRequest?.endAudio()
        
        delegate?.setGuideMessage(message: "マイクボタンを押して下さい。")
        delegate?.setButtonStatus(isEnabled: false)
    }
    
    /// 録音中か？
    func isRunning() -> Bool {
        return audioEngine.isRunning
    }
    
    private func refreshTask() {
        if let recognitionTask = recognitionTask {
            recognitionTask.cancel()
            self.recognitionTask = nil
        }
    }
    
    private func startAudioEngine() throws {
        // startの前にリソースを確保しておく。
        audioEngine.prepare()
        try audioEngine.start()
        delegate?.setGuideMessage(message: "どうぞ喋ってください。\n終わったら、マイクボタンを押して下さい。")
    }
    
    /// 漢字をカナに変換する
    private func kanaHenkan(text: String) -> String {
        let inputText = text
        let outputText = NSMutableString()
        
        let range: CFRange = CFRangeMake(0, inputText.characters.count)
        let locale: CFLocale = CFLocaleCopyCurrent()
        let tokenizer: CFStringTokenizer
            = CFStringTokenizerCreate(kCFAllocatorDefault,
                                      inputText as CFString,
                                      range,
                                      kCFStringTokenizerUnitWordBoundary,
                                      locale)
        
        var tokenType: CFStringTokenizerTokenType = CFStringTokenizerGoToTokenAtIndex(tokenizer, 0)
        
        while (tokenType != .none) {
            if let latin: CFTypeRef
                = CFStringTokenizerCopyCurrentTokenAttribute(tokenizer,
                                                             kCFStringTokenizerAttributeLatinTranscription) {
                let romanAlphabet: NSString = latin as! NSString
                let furigana = romanAlphabet.mutableCopy()
                CFStringTransform(furigana as! CFMutableString, nil, kCFStringTransformLatinHiragana, false)
                
                outputText.append(furigana as! String)
                print(furigana)
                
                tokenType = CFStringTokenizerAdvanceToNextToken(tokenizer)
            } else {
                break
            }
        }
        return outputText as String
    }
}

//MARK:- SFSpeechRecognizerDelegate
extension SpeechUtil: SFSpeechRecognizerDelegate {
    
    /// 音声認識の可否が変更したときに呼ばれる
    func speechRecognizer(_ speechRecognizer: SFSpeechRecognizer,
                          availabilityDidChange available: Bool) {
        
        delegate?.setButtonStatus(isEnabled: available)

        if available {
            delegate?.setGuideMessage(message: "どうぞ喋ってください。\n終わったら、マイクボタンを押して下さい。")

        } else {
            delegate?.setGuideMessage(message: "マイクボタンを押して下さい。")
        }        
    }
}
