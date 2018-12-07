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

import UIKit

@objc(ViewController)
class ViewController: UIViewController, UINavigationControllerDelegate,SwiftyDrawViewDelegate {
    func swiftyDraw(shouldBeginDrawingIn drawingView: SwiftyDrawView, using touch: UITouch) -> Bool {
        return true
    }
    
    func swiftyDraw(didBeginDrawingIn drawingView: SwiftyDrawView, using touch: UITouch) {
        
    }
    
    func swiftyDraw(isDrawingIn drawingView: SwiftyDrawView, using touch: UITouch) {
        
    }
    
    func swiftyDraw(didFinishDrawingIn drawingView: SwiftyDrawView, using touch: UITouch) {
        
    }
    
    func swiftyDraw(didCancelDrawingIn drawingView: SwiftyDrawView, using touch: UITouch) {
        
    }
    
    
    // MARK: - Properties
    /// 모델 로드 및 개체 감지를 관리하는 모델 변환 관리자.
    private lazy var modelManager = ModelInterpreterManager()
    /// 클라우드 모델 다운로드 버튼이 선택되었는지 여부를 나타냅니다.
    private var downloadCloudModelButtonSelected = false
    /// 사진 라이브러리 또는 카메라에 액세스하기 위한 이미지 선택 도구입니다.
    private var imagePicker = UIImagePickerController()
    
    @IBOutlet private var modelControl: UISegmentedControl!
    
    @IBOutlet private var resultsTextView: UITextView!
    @IBOutlet private var detectButton: UIBarButtonItem!
    
    @IBOutlet weak var imageOrView: UIView!
    var drawView : SwiftyDrawView!
    var imageCapture : UIImage!
    // MARK: - UIViewController
    
    override func viewDidLoad() {
        super.viewDidLoad()
        //        imageCapture = UIImage(named: Constants.defaultImage)
        setUpLocalModel()
        drawView = SwiftyDrawView(frame: self.imageOrView.bounds)
        drawView.delegate = self
        self.imageOrView.addSubview(drawView)
        
        
    }
    
    @IBAction func clearButton(_ sender: Any) {
        print("clear")
        drawView.clear()
    }
    // MARK: - IBActions
    //MARK: - Add image to Library
    @objc func image(_ image: UIImage, didFinishSavingWithError error: Error?, contextInfo: UnsafeRawPointer) {
        if let error = error {
            // we got back an error!
            showAlertWith(title: "Save error", message: error.localizedDescription)
        } else {
            showAlertWith(title: "Saved!", message: "Your image has been saved to your photos.")
        }
    }
    
    func showAlertWith(title: String, message: String){
        let ac = UIAlertController(title: title, message: message, preferredStyle: .alert)
        ac.addAction(UIAlertAction(title: "OK", style: .default))
        present(ac, animated: true)
    }
    @IBAction func detectObjects(_ sender: Any) {
        // draw한 UIView를 UIImage로 convert 시키기
        clearResults()
        let renderer = UIGraphicsImageRenderer(size: drawView.bounds.size)
        imageCapture = renderer.image { ctx in
            drawView.drawHierarchy(in: drawView.bounds, afterScreenUpdates: true)
        }
        // save image in camera roll! only drawView!
        UIGraphicsBeginImageContextWithOptions(drawView.bounds.size, true, 1.0)
        drawView.drawHierarchy(in: drawView.bounds, afterScreenUpdates: true)
        let image_t = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        UIImageWriteToSavedPhotosAlbum(image_t!,nil,nil,nil)
        let isQuantized = quantized()
        
        //        UIImageWriteToSavedPhotosAlbum(image_t!, self, #selector(image(_:didFinishSavingWithError:contextInfo:)), nil)
        let imagere : UIImage
        if isQuantized {
            imagere = ResizeImage(image: imageCapture, targetSize: CGSize(width: 64, height: 64))
            
        }else{
            imagere = ResizeImage(image: imageCapture, targetSize: CGSize(width: 28, height: 28))
            
        }
        print(imagere.cgImage)
        guard let image = imageCapture else {
            resultsTextView.text = "Image must not be nil.\n"
            return
        }
        
        if !downloadCloudModelButtonSelected {
            resultsTextView.text = "Loading the local model...\n"
            if !modelManager.loadLocalModel(isQuantized: quantized()) {
                resultsTextView.text = "Failed to load the local model."
                return
            }
        }
        print("1")
        var newResultsTextString = "추론 시작...💬\n"
        if let currentText = resultsTextView.text {
            newResultsTextString = currentText + newResultsTextString
        }
        resultsTextView.text = newResultsTextString
        
        
        DispatchQueue.global(qos: .userInitiated).async {
            var imageData: Any?
            imageData = self.modelManager.scaledPixelArray(from: imagere,
                                                           componentsCount: 1,
                                                           isQuantized: false)
            
            // detectObject 는 input을 설정하고 결과를 가져온다.
            self.modelManager.detectObjects(in: imageData) { (results, error) in
                guard error == nil, let results = results, !results.isEmpty else {
                    var errorString = error?.localizedDescription ?? "Failed to detect objects in image."
                    errorString = "Inference error: \(errorString)"
                    print(errorString)
                    self.resultsTextView.text = errorString
                    return
                }
                
                var inferenceMessageString: String
                inferenceMessageString = "💡 모델을 통한 추론 결과 💡\n"
                
                self.resultsTextView.text =
                    inferenceMessageString + "\(self.detectionResultsString(fromResults: results))"
            }
        }
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
    
    @IBAction func openPhotoLibrary(_ sender: Any) {
        imagePicker.sourceType = .photoLibrary
        present(imagePicker, animated: true)
    }
    
    @IBAction func openCamera(_ sender: Any) {
        imagePicker.sourceType = .camera
        present(imagePicker, animated: true)
    }
    
    
    @IBAction func modelSwitched(_ sender: Any) {
        clearResults()
        setUpLocalModel()
        drawView.clear()
    }
    
    ///현재 선택한 로컬 모델의 이름을 반환합니다.
    /// Returns the name for the currently selected local model.
    private func currentLocalModelName() -> String {
        switch modelControl.selectedSegmentIndex {
        case 0:
            print("float")
            return ModelInterpreterConstants.floatModelFilename
        case 1:
            print("Quantized")
            return ModelInterpreterConstants.quantizedModelFilename
            
        case 2:
            print("invalid")
            return ModelInterpreterConstants.invalidModelFilename
        default:
            fatalError("Unsupported model.")
        }
        return ""
    }
    
    fileprivate func quantized() -> Bool {
        return (modelControl.selectedSegmentIndex == 1)
    }
    
    /// Sets up the local model.
    private func setUpLocalModel() {
        let name = currentLocalModelName()
        let filename = currentLocalModelName()
        if !modelManager.setUpLocalModel(withName: name, filename: filename) {
            resultsTextView.text = "\(resultsTextView.text ?? "")\nFailed to set up the local model."
        }
    }
    /// 탐지 결과의 문자열 표현을 반환합니다.
    /// Returns a string representation of the detection results.
    private func detectionResultsString(
        fromResults results: [(label: String, confidence: Float)]?
        ) -> String {
        guard let results = results else { return "Failed to detect objects in image." }
        return results.reduce("") { (resultString, result) -> String in
            let (label, confidence) = result
            return resultString + "\(label): \(String(describing: confidence))\n"
        }
    }
    
    /// 결과를 지웁니다.
    /// Clears the results from the last inference call.
    private func clearResults() {
        resultsTextView.text = nil
        //        drawView.clear()
    }
    
}


// MARK: - Extensions

#if !swift(>=4.2)
extension UIImagePickerController {
public typealias InfoKey = String
}

extension UIImagePickerController.InfoKey {
public static let originalImage = UIImagePickerControllerOriginalImage
}
#endif  // !swift(>=4.2)

extension UIImage {
    class func imageWithView(view: UIView) -> UIImage? {
        UIGraphicsBeginImageContextWithOptions(view.bounds.size, view.isOpaque, 0.0)
        view.drawHierarchy(in: view.bounds, afterScreenUpdates: true)
        let img = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        return img
    }
}
