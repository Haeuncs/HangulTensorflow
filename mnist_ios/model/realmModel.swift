//
//  realmModel.swift
//  mnist_ios
//
//  Created by OOPSLA on 11/11/2018.
//  Copyright © 2018 haeun. All rights reserved.
//

// count model

import RealmSwift

class Count: Object {
    @objc dynamic var count = 0
    @objc dynamic var rightCount = 0
}
