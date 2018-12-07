
//
//  Copyright (c) 2018 Google Inc.
//
//  Licensed under the Apache License, Version 2.0 (the "License");
//  you may not use this file except in compliance with the License.
//  You may obtain a copy of the License at
//
//  http://www.apache.org/licenses/LICENSE-2.0
//
//  Unless required by applicable law or agreed to in writing, software
//  distributed under the License is distributed on an "AS IS" BASIS,
//  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
//  See the License for the specific language governing permissions and
//  limitations under the License.
//
import RealmSwift

import UIKit
import FirebaseMLModelInterpreter

/// 클라우드 및 로컬 모델 관리에 대한 요구 사항을 정의합니다.
/// Defines the requirements for managing cloud and local models.
public protocol ModelManaging {
    
    
    /// 클라우드 모델 소스가 성공적으로 등록되어 있는지 여부를 나타내는 Bool을 반환합니다.
    /// Returns a Bool indicating whether the cloud model source was successfully registered or had
    /// already been registered.
    func register(_ cloudModelSource: CloudModelSource) -> Bool
    
    /// 로컬 모델 소스가 성공적으로 등록되어 있는지 여부를 나타내는 Bool을 반환합니다.
    /// Returns a Bool indicating whether the local model source was successfully registered or had
    /// already been registered.
    func register(_ localModelSource: LocalModelSource) -> Bool
}

public enum ModelInterpreterError: Int, CustomNSError {
    case invalidImageData = 1
    case invalidResults = 2
    
    // MARK: - CustomNSError
    
    public static var errorDomain: String {
        return "com.google.firebaseml.sampleapps.modelinterpreter"
    }
    
    public var errorCode: Int { return rawValue }
    public var errorUserInfo: [String: Any] { return [:] }
}

public enum ModelInterpreterConstants {
    
    // MARK: - Public
    
    public static let modelExtension = "tflite"
    public static let labelsExtension = "txt"
    public static let topResultsCount: Int = 5
    public static let dimensionComponents: NSNumber = 1
    
    
    // MARK: - Fileprivate
    
    fileprivate static let labelsSeparator = "\n"
    fileprivate static let labelsFilename = "labels"
    public static let quantizedModelFilename = "hangul_tensorflow"
    public static let floatModelFilename = "mnist"
    
    fileprivate static let modelInputIndex: UInt = 0
    fileprivate static let dimensionBatchSize: NSNumber = 1
    fileprivate static var dimensionImageWidth: NSNumber = 64
    fileprivate static var dimensionImageHeight: NSNumber = 64
    fileprivate static let maxRGBValue: Float32 = 255.0
    
    fileprivate static let inputDimensions = [
        dimensionBatchSize,
        dimensionImageWidth,
        dimensionImageHeight,
        dimensionComponents,
        ]
}

public class ModelInterpreterManager {
    
    public typealias DetectObjectsCompletion = ([(label: String, confidence: Float)]?, Error?) -> Void
    
    private let modelManager: ModelManaging
    private let modelInputOutputOptions = ModelInputOutputOptions()
    private var registeredCloudModelNames = Set<String>()
    private var registeredLocalModelNames = Set<String>()
    private var cloudModelOptions: ModelOptions?
    private var localModelOptions: ModelOptions?
    private var modelInterpreter: ModelInterpreter?
    private var modelElementType: ModelElementType = .uInt8
    private var isModelQuantized = true
    private var labels = [String]()
    private var labelsCount: Int = 0
    
    var isHangulTrue = true
    fileprivate static let hangulLabel = "hangul2350"
    fileprivate static let numberLabel = "number10"
    public static let labelsExtension = "txt"
    fileprivate static let modelInputIndex: UInt = 0
    fileprivate static var dimensionImageWidthN: NSNumber = 28
    fileprivate static var dimensionImageHeightN: NSNumber = 28
    fileprivate static var dimensionImageWidthH: NSNumber = 64
    fileprivate static var dimensionImageHeightH: NSNumber = 64
    var topResult = ""
    
    /// 지정된 개체로 '모델 관리'를 준수하는 새 인스턴스를 만듭니다.
    public init(modelManager: ModelManaging = ModelManager.modelManager()) {
        self.modelManager = modelManager
    }
    public func setUpCloudModel(withName name: String) -> Bool {
        let conditions = ModelDownloadConditions(isWiFiRequired: false, canDownloadInBackground: true)
        let cloudModelSource = CloudModelSource(
            modelName: name,
            enableModelUpdates: true,
            initialConditions: conditions,
            updateConditions: conditions
        )
        guard registeredCloudModelNames.contains(name) || modelManager.register(cloudModelSource) else {
            print("Failed to register the cloud model source with name: \(name)")
            return false
        }
        cloudModelOptions = ModelOptions(cloudModelName: name, localModelName: nil)
        registeredCloudModelNames.insert(name)
        return true
    }
    
    /// 'LocalModelSource'를 만들고 지정된 이름으로 등록하여 로컬 모델을 설정합니다.
    ///
    /// - 매개 변수:
    /// - 이름: 로컬 모델의 이름입니다.
    /// - 번들: 모델 리소스를 로드할 번들. 기본값은 기본 번들입니다.
    /// - 반환: 로컬 모델이 성공적으로 설정 및 등록되었는지 여부를 나타내는 '볼'입니다.
    public func setUpLocalModel(withName name: String, filename: String, bundle: Bundle = .main) -> Bool {
        guard let localModelFilePath = bundle.path(
            forResource: filename,
            ofType: ModelInterpreterConstants.modelExtension)
            else {
                print("Failed to get the local model file path.")
                return false
        }
        let localModelSource = LocalModelSource(
            modelName: name,
            path: localModelFilePath
        )
        guard registeredLocalModelNames.contains(name) || modelManager.register(localModelSource) else {
            print("Failed to register the local model source with name: \(name)")
            return false
        }
        localModelOptions = ModelOptions(cloudModelName: nil, localModelName: name)
        registeredLocalModelNames.insert(name)
        return true
    }
    
    /// 설정 중에 생성된 'ModelOptions(모델 옵션)'로 등록된 로컬 모델을 로드합니다.
    ///
    /// - 매개 변수:
    /// - 번들: 모델 리소스를 로드할 번들. 기본값은 기본 번들입니다.
    /// - 반환: 로컬 모델이 성공적으로 로드되었는지 여부를 나타내는 '볼'입니다.
    public func loadLocalModel(bundle: Bundle = .main, isQuantized: Bool = true) -> Bool {
        guard let localModelOptions = localModelOptions else {
            print("Failed to load the local model because the options are nil.")
            return false
        }
        isModelQuantized = isQuantized
        isHangulTrue = isQuantized
        print(isHangulTrue)
        return loadModel(options: localModelOptions, isHangul: isQuantized, bundle: bundle)
    }
    
    /// 지정된 영상 데이터에서 '데이터' 또는 픽셀 값의 배열로 표시되는 개체를 검색합니다.
    /// 각 tupples에서 탐지 결과를 Tuples 배열로 호출하여 완료
    ///에는 라벨 및 신뢰 값이 포함됩니다.
    ///
    /// - 매개 변수
    /// - imageData: 객체를 탐지하는 이미지의 데이터 또는 픽셀 배열을 나타냅니다.
    /// - topResultsCount: 반환할 상위 결과 수입니다.
    /// - 완료: 탐지 결과 또는 오류가 있는 메인 스레드에서 호출할 처리기.
    ///   - completion: The handler to be called on the main thread with detection results or error.
    public func detectObjects(
        in imageData: Any?,
        topResultsCount: Int = ModelInterpreterConstants.topResultsCount,
        completion: @escaping DetectObjectsCompletion
        ) {
        guard let imageData = imageData else {
            safeDispatchOnMain {
                completion(nil, ModelInterpreterError.invalidImageData)
            }
            return
        }
        //        print(imageData)
        let inputs = ModelInputs()
        do {
            // Add the image data to the model input.
            try inputs.addInput(imageData)
        } catch let error as NSError {
            print("Failed to add the image data input with error: \(error.localizedDescription)")
            safeDispatchOnMain {
                completion(nil, error)
            }
            return
        }
        let ioOptions = ModelInputOutputOptions()
        print("test")
        if isModelQuantized {
            do {
                print("한글")
                try ioOptions.setInputFormat(index: 0, type: .float32, dimensions: [1, 64,64,1])
                try ioOptions.setOutputFormat(index: 0, type: .float32, dimensions: [1,2350])
            } catch let error as NSError {
                print("Failed to set input or output format with error: \(error.localizedDescription)")
            }
        }
        else{
            do {
                print("숫자")
                try ioOptions.setInputFormat(index: 0, type: .float32, dimensions: [1, 28,28,1])
                try ioOptions.setOutputFormat(index: 0, type: .float32, dimensions: [1,10])
            } catch let error as NSError {
                print("Failed to set input or output format with error: \(error.localizedDescription)")
            }
            
        }
        
        // Run the interpreter for the model with the given inputs.
        modelInterpreter?.run(inputs: inputs, options: ioOptions) { (outputs, error) in
            guard error == nil, let outputs = outputs else {
                completion(nil, error)
                return
            }
            print(".run 안")
            do {
                // Get the output for the first batch, since `dimensionBatchSize` is 1.
                let outputArrayOfArrays = try outputs.output(index: 0) as! Array<Any>
                print(outputArrayOfArrays)
                print("작동")
                for i in outputArrayOfArrays{
                    print("?")
                    print(i)
                }
            } catch let error as NSError {
                print("Failed to process detection outputs with error: \(error.localizedDescription)")
                completion(nil, error)
                return
            }
            self.process(outputs, topResultsCount: topResultsCount, completion: completion)
            
        }
    }
    
    func showAlertWith(title: String, message: String){
        let realm = try! Realm()
        let countRealm = realm.objects(Count.self).first
        let ac = UIAlertController(title: title, message: message, preferredStyle: .alert)
        let yesAction = UIAlertAction(title: "네",
                                      style: .default) { (action) in
                                        print("yessssss action")
                                        if countRealm != nil{
                                            try! realm.write {
                                                
                                                let count = countRealm!.count
                                                let right = countRealm!.rightCount
                                                countRealm!.count = count+1
                                                countRealm!.rightCount = right+1
                                            }
                                        }else{
                                            let countData = Count()
                                            countData.count = 1
                                            countData.rightCount = 1
                                            try! realm.write {
                                                realm.add(countData)
                                            }

                                        }
                                        
        }
        let noAction = UIAlertAction(title: "아니요", style: .cancel, handler: {(action) in
            if countRealm != nil{
                try! realm.write {
                    let count = countRealm!.count
                    countRealm!.count = count+1
                }
            }else{
                let countData = Count()
                countData.count = 1
                countData.rightCount = 0
                try! realm.write {
                    realm.add(countData)
                }
            }
        })
        ac.addAction(noAction)
        ac.addAction(yesAction)

        // root 에게
        var rootViewController = UIApplication.shared.keyWindow?.rootViewController
        if let navigationController = rootViewController as? UINavigationController {
            rootViewController = navigationController.viewControllers.first
        }
        if let tabBarController = rootViewController as? UITabBarController {
            rootViewController = tabBarController.selectedViewController
        }
        rootViewController?.present(ac, animated: true, completion: nil)
    }
    
    func ResizeImage(image: UIImage, targetSize: CGSize) -> UIImage {
        let size = image.size
        
        let widthRatio  = targetSize.width  / image.size.width
        let heightRatio = targetSize.height / image.size.height
        
        // Figure out what our orientation is, and use that to form the rectangle
        var newSize: CGSize
        if(widthRatio > heightRatio) {
            newSize = CGSize(width: size.width * heightRatio, height: size.height * heightRatio)
        } else {
            newSize = CGSize(width: size.width * widthRatio, height: size.height * widthRatio)
        }
        
        // This is the rect that we've calculated out and this is what is actually used below
        let rect = CGRect(x: 0,y: 0,width: newSize.width, height: newSize.height)
        
        // Actually do the resizing to the rect using the ImageContext stuff
        UIGraphicsBeginImageContextWithOptions(newSize, false, 1.0)
        image.draw(in: rect)
        let newImage = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        
        return newImage!
    }
    
    /// 지정된 이미지를 모델이 교육을 받은 기본 크기로 확장합니다.
    ///
    /// - 매개 변수:
    /// - 이미지: 크기를 조정할 이미지.
    /// - componentsCount: 스케일링된 이미지의 구성 요소 수입니다. 구성 요소는 빨간색이고
    /// 녹색, 파란색 또는 알파 값. 기본값은 3입니다. 이 값은 모형이
    /// RGB 구성 요소만 포함하는 이미지에 대해 교육됨(즉, 알파 구성 요소는
    /// 제거됨).
    /// - 반환: 이미지를 크기를 조정할 수 없는 경우 스케일링된 이미지는 '데이터' 또는 '없음'으로 표시됩니다. 스케일링 가능
    /// 실패 원인은 다음과 같습니다. 1) 구성 요소 수가
    /// 지정된 이미지 2)의 구성 요소 개수입니다. 지정된 이미지의 크기 또는 CGImage가 잘못되었습니다.
    ///     components count of the given image 2) the given image's size or CGImage is invalid.
    public func scaledImageData(
        from image: UIImage,
        componentsCount: Int = 1
        ) -> Data? {
        var imageWidth = ModelInterpreterConstants.dimensionImageWidth.doubleValue
        var imageHeight = ModelInterpreterConstants.dimensionImageHeight.doubleValue
        
        if isHangulTrue{
            imageWidth = ModelInterpreterManager.dimensionImageWidthH.doubleValue
            imageHeight = ModelInterpreterManager.dimensionImageHeightH.doubleValue
        }
        else{
            print("숫자 스케일")
            imageWidth = ModelInterpreterManager.dimensionImageWidthN.doubleValue
            imageHeight = ModelInterpreterManager.dimensionImageHeightN.doubleValue
        }
        let imageSize = CGSize(width: imageWidth, height: imageHeight)
        guard let scaledImageData = image.scaledImageData(
            with: imageSize,
            componentsCount: componentsCount,
            batchSize: 1)
            else {
                print("Failed to scale image to size: \(imageSize).")
                return nil
        }
        return scaledImageData
    }
    
    /// 지정된 이미지를 모델이 교육을 받은 기본 크기로 확장합니다.
    ///
    /// - 매개 변수:
    /// - 이미지: 크기를 조정할 이미지.
    /// - componentsCount: 스케일링된 이미지의 구성 요소 수입니다. 구성 요소는 빨간색이고
    /// 녹색, 파란색 또는 알파 값. 기본값은 3입니다. 이 값은 모형이
    /// RGB 구성 요소만 포함하는 이미지에 대해 교육됨(즉, 알파 구성 요소는
    /// 제거됨).
    /// - isQuantized: 모형이 정량화를 사용하는지 여부(예: 8비트 고정점 가중치 및
    /// 활성화. 자세한 내용은 https://www.tensorflow.org/performance/quantization을 참조하십시오.
    /// 거짓이면 부동 소수점 모델이 사용됩니다. 기본값은 진실이다.
    /// - 반환: 고정 지점('isQuantized') 값의 다차원 배열
    /// 또는 부동 소수점('isQuantized') 값, 이미지인 경우 nil
    /// 크기를 조정할 수 없습니다. 반환된 픽셀 배열은
    /// 이미지의 기본 폭과 동일한 카운트. 각 수평 픽셀은
    /// 카운트가 이미지의 기본 높이와 동일한 veritcal 픽셀 배열. 각각
    /// 수평 픽셀에 지정된 수와 동일한 카운트의 구성 요소 배열이 포함되어 있습니다.
    /// '구성요소 개수'입니다. 스케일링이 실패하는 이유는 다음과 같습니다. 1) 구성 요소 수가 아닙니다.
    /// 지정된 이미지의 구성 요소 수보다 작거나 같음 2) 지정된 이미지의 크기 또는
    /// CGImage가 잘못되었습니다.
    public func scaledPixelArray(
        from image: UIImage,
        componentsCount: Int = ModelInterpreterConstants.dimensionComponents.intValue,
        isQuantized: Bool = true
        ) -> [[[[Any]]]]? {
        var imageWidth = ModelInterpreterConstants.dimensionImageWidth.doubleValue
        var imageHeight = ModelInterpreterConstants.dimensionImageHeight.doubleValue
        
        if isHangulTrue{
            imageWidth = ModelInterpreterManager.dimensionImageWidthH.doubleValue
            imageHeight = ModelInterpreterManager.dimensionImageHeightH.doubleValue
        }
        else{
            print("숫자 스케일")
            imageWidth = ModelInterpreterManager.dimensionImageWidthN.doubleValue
            imageHeight = ModelInterpreterManager.dimensionImageHeightN.doubleValue
        }
        let imageSize = CGSize(width: imageWidth, height: imageHeight)
        guard let scaledPixelArray = image.scaledPixelArray(
            with: imageSize,
            componentsCount: componentsCount,
            batchSize: ModelInterpreterConstants.dimensionBatchSize.intValue,
            isQuantized: isQuantized)
            else {
                print("Failed to scale image to size: \(imageSize).")
                return nil
        }
        return scaledPixelArray
    }
    
    // MARK: - Private
    /// 주어진 옵션과 입력 및 출력 치수가 포함된 모델을 로드합니다.
    ///
    /// - 매개 변수:
    /// - 옵션: 로드할 클라우드 및/또는 로컬 소스로 구성된 모델 옵션.
    /// - isQuantized: 모형이 정량화를 사용하는지 여부(예: 8비트 고정점 가중치 및
    /// 활성화. 자세한 내용은 https://www.tensorflow.org/performance/quantization을 참조하십시오. 한다면
    /// 거짓, 부동 소수점 모델이 사용됩니다. 기본값은 진실이다.
    /// - 입력치수: 입력 텐서 치수의 배열입니다. '출력 이미지'를 포함해야 합니다.
    /// 'inputDimensions'이 지정된 경우 기본 입력 치수를 사용하려면 'nil'을 통과하십시오.
    /// - 출력이미지: 출력 텐서 치수의 배열입니다. inputDimensions를 포함해야 합니다.
    /// 'outputDimensions'이 지정된 경우 기본 출력 치수를 사용하려면 nil을 통과하십시오.
    /// - 번들: 모델 리소스를 로드할 번들. 기본값은 기본 번들입니다.
    /// - 반환: 모형이 성공적으로 로드되었는지 여부를 나타내는 '볼'입니다. 로컬 및
    /// 클라우드 모델 소스가 'ModelOptions'에 제공되었으며 클라우드 모델이 우선함
    /// 및 로드됩니다. 아직 Firebase 콘솔에서 클라우드 모델을 다운로드하지 않은 경우
    /// 모델 다운로드 요청이 생성되고 로컬 모델이 페일백으로 로드됩니다.
    private func loadModel(
        options: ModelOptions,
        isHangul: Bool = true,
        inputDimensions: [NSNumber]? = nil,
        outputDimensions: [NSNumber]? = nil,
        bundle: Bundle = .main
        ) -> Bool {
        guard (inputDimensions != nil && outputDimensions != nil) ||
            (inputDimensions == nil && outputDimensions == nil)
            else {
                print("Invalid input and output dimensions provided.")
                return false
        }
        
        isHangulTrue = isHangul
        var FilePath = ""
        do {
            let encoding = String.Encoding.utf8.rawValue
            if isHangulTrue{
                guard let labelsFilePath = bundle.path(
                    forResource: ModelInterpreterManager.hangulLabel,
                    ofType: ModelInterpreterManager.labelsExtension)
                    else {
                        print("한글 라벨이 file path 에 없음.")
                        return false
                }
                FilePath = labelsFilePath
            }else{
                guard let labelsFilePath = bundle.path(
                    forResource: ModelInterpreterManager.numberLabel,
                    ofType: ModelInterpreterManager.labelsExtension)
                    else {
                        print("숫자 라벨이 file path에 없음.")
                        return false
                }
                FilePath = labelsFilePath
            }
            
            let contents = try NSString(contentsOfFile: FilePath, encoding: encoding)
            labels = contents.components(separatedBy: "\n")
            labelsCount = labels.count
            
            modelInterpreter = ModelInterpreter.modelInterpreter(options: options)
            modelElementType = .float32
            
        } catch let error as NSError {
            print("Failed to load the model with error: \(error.localizedDescription)")
            return false
        }
        return true
    }
    
    
    private func process(
        _ outputs: ModelOutputs,
        topResultsCount: Int,
        completion: @escaping DetectObjectsCompletion
        ) {
        print("process")
        let outputArrayOfArrays: Any
        do {
            // Get the output for the first batch, since `dimensionBatchSize` is 1.
            outputArrayOfArrays = try outputs.output(index: 0)
        } catch let error as NSError {
            print("Failed to process detection outputs with error: \(error.localizedDescription)")
            completion(nil, error)
            return
        }
        // Get the first output from the array of output arrays.
        guard let outputNSArray = outputArrayOfArrays as? NSArray,
            let firstOutputNSArray = outputNSArray.firstObject as? NSArray,
            var outputArray = firstOutputNSArray as? [NSNumber]
            else {
                print("Failed to get the results array from output.")
                completion(nil, ModelInterpreterError.invalidResults)
                return
        }
        
        // Create an array of indices that map to each label in the labels text file.
        var indexesArray = [Int](repeating: 0, count: labelsCount)
        for index in 0..<labelsCount {
            indexesArray[index] = index
        }
        
        // Create a zipped array of tuples ("confidence" as NSNumber, "labelIndex" as Int).
        let zippedArray = zip(outputArray, indexesArray)
        
        // Sort the zipped array of tuples ("confidence" as NSNumber, "labelIndex" as Int) by confidence
        // value in descending order.
        var sortedResults = zippedArray.sorted {
            let confidenceValue1 = ($0 as (NSNumber, Int)).0
            let confidenceValue2 = ($1 as (NSNumber, Int)).0
            return confidenceValue1.floatValue > confidenceValue2.floatValue
        }

        // Resize the sorted results array to match the `topResultsCount`
        sortedResults = Array(sortedResults.prefix(topResultsCount))
        topResult = labels[(sortedResults.first?.1)!]
        // Create an array of tuples with the results as [("label" as String, "confidence" as Float)].
        let results = sortedResults.map { (confidence, labelIndex) -> (String, Float) in
            return (labels[labelIndex], confidence.floatValue)
        }
        completion(results, nil)
        if isHangulTrue{
            showAlertWith(title: "예측값이 올바른가요?!", message: "작성한 값이 \""+topResult+"\" 인가요?")
        }

    }
}

// MARK: - ModelManaging

extension ModelManager: ModelManaging {}

// MARK: - Fileprivate

/// Safely dispatches the given block on the main queue. If the current thread is `main`, the block
/// is executed synchronously; otherwise, the block is executed asynchronously on the main thread.
fileprivate func safeDispatchOnMain(_ block: @escaping () -> Void) {
    if Thread.isMainThread {
        block()
    } else {
        DispatchQueue.main.async {
            block()
        }
    }
}
