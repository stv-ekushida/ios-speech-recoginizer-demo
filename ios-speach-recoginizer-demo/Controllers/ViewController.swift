//
//  ViewController.swift
//  ios-speach-recoginizer-demo
//
//  Created by Kushida　Eiji on 2017/02/24.
//  Copyright © 2017年 Kushida　Eiji. All rights reserved.
//

import UIKit

class ViewController: UIViewController {
    
    @IBOutlet weak var button: UIButton!
    @IBOutlet weak var guideLabel: UILabel!    
    @IBOutlet weak var resultTextView: UITextView!
    
    let speech = SpeachUtil()
            
    override func viewDidLoad() {
        super.viewDidLoad()
        speech.delegate = self
    }
    
    public override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        speech.requestRecognizerAuthorization()
        try! speech.startRecording()
    }
    
    @IBAction func tappedStartButton(_ sender: AnyObject) {
        
        if speech.isRunning() {
            speech.stopRecording()
        } else {
            try! speech.startRecording()
        }
    }
}

//MARK:- SpeachResultDelegate
extension ViewController: SpeachResultDelegate {
    
    func setButtonStatus(isEnabled: Bool) {
        self.button.isEnabled = isEnabled
    }
    
    func setGuideMessage(message: String) {
        self.guideLabel.text = message
    }
    
    func setResult(result: String) {
        self.resultTextView.text = result
    }
}
