//
//  settingView.swift
//  mnist_ios
//
//  Created by OOPSLA on 11/11/2018.
//  Copyright © 2018 haeun. All rights reserved.
//

import UIKit
import RealmSwift

class settingView: UIViewController {
    override func viewDidLoad() {
        super.viewDidLoad()
        
        let realm = try! Realm()
        let countRealm = realm.objects(Count.self).first
        let count = countRealm!.count
        let right = countRealm!.rightCount
        print(count)
        print(right)
        let text = "현재 테스트한 개수 : " + String(count)+"\n"
        let text2 = "올바르게 인식한 개수 : " + String(right) + "\n"
        var accuracy = ""
        if count == 0 || right == 0 {
            accuracy = "현재 정확도 : " + "0" + "\n"
        }else{
            let div = Double(right)/Double(count)
            accuracy = "현재 정확도 : " + String(div) + "\n"
        }
        let all = text + text2 + accuracy
        let textView = UITextView(frame: CGRect(x: 0.0, y: 0.0, width: 450, height: 300))
        textView.center = self.view.center
        textView.textAlignment = NSTextAlignment.justified
        textView.font = UIFont(name: "Times New Roman", size: 30)
        textView.text = all
        view.addSubview(textView)
    }
}
