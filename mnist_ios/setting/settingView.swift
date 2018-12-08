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
    initView()
    
    let realm = try! Realm()
    let countRealm = realm.objects(Count.self).first
    let count = countRealm!.count
    let right = countRealm!.rightCount
    let text = "현재 테스트한 개수 : " + String(count)+"\n"
    let text2 = "올바르게 인식한 개수 : " + String(right) + "\n"
    var accuracy = ""
    if count == 0 || right == 0 {
      accuracy = "현재 정확도 : " + "0" + "\n"
    }else{
      let div = Double(right)/Double(count)
      accuracy = "현재 정확도 : " + String(div) + "\n"
    }
    let allText = text + text2 + accuracy
    textView.text = allText
    
  }
  lazy var textView: UITextView = {
    let view = UITextView()
    view.translatesAutoresizingMaskIntoConstraints = false
    view.font = UIFont.systemFont(ofSize: 16, weight: .medium)
    return view
  }()
  func initView(){
    view.backgroundColor = .white
    view.addSubview(textView)
    NSLayoutConstraint.activate([
      textView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 16),
      textView.leftAnchor.constraint(equalTo: view.leftAnchor, constant: 16),
      textView.rightAnchor.constraint(equalTo: view.rightAnchor, constant: -16),
      textView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -16),

    ])
  }
}
