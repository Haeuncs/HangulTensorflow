//  Licensed under the Apache License, Version 2.0 (the "License");
//  you may not use this file except in compliance with the License.
//  You may obtain a copy of the License at
//
//  http://www.apache.org/licenses/LICENSE-2.0


import UIKit

@objc(ViewController)
class ViewController: UIViewController {
  // MARK: - Properties
  
  /// 모델 로드 및 개체 감지를 관리하는 모델 변환 관리자.
  private lazy var modelManager = ModelInterpreterManager()
  /// 사진 라이브러리 또는 카메라에 액세스하기 위한 이미지 선택 도구입니다.
  private var imagePicker = UIImagePickerController()
  
  @IBOutlet private var modelControl: UISegmentedControl!
  @IBOutlet private var resultsTextView: UITextView!
  @IBOutlet private var detectButton: UIBarButtonItem!
  @IBOutlet weak var imageOrView: UIView!
  var drawView : SwiftyDrawView!
  /// 추론에 사용할 이미지
  var imageCapture : UIImage!
  
  override func viewDidLoad() {
    super.viewDidLoad()
    setUpLocalModel()
    drawView = SwiftyDrawView(frame: self.imageOrView.bounds)
    drawView.delegate = self
    // 항상 width 와 height가 동일한 크기이기를 보장
    let width = imageOrView.frame.width
    imageOrView.frame.size.height = width
    self.imageOrView.addSubview(drawView)
  }
  
  // MARK: - IBActions
  
  /// DrawView 지우는 버튼
  @IBAction func clearButton(_ sender: Any) {
    drawView.clear()
  }
  /// 모델이 변경될 때 실행
  @IBAction func modelSwitched(_ sender: Any) {
    clearResults()
    setUpLocalModel()
    drawView.clear()
  }
  /// 모델 실행
  @IBAction func detectObjects(_ sender: Any) {
    // draw한 UIView를 UIImage로 convert 시키기
    clearResults()
    let renderer = UIGraphicsImageRenderer(size: drawView.bounds.size)
    imageCapture = renderer.image { ctx in
      drawView.drawHierarchy(in: drawView.bounds, afterScreenUpdates: true)
    }
    // 이미지를 갤러리에 저장
    UIGraphicsBeginImageContextWithOptions(drawView.bounds.size, true, 1.0)
    drawView.drawHierarchy(in: drawView.bounds, afterScreenUpdates: true)
    let image_t = UIGraphicsGetImageFromCurrentImageContext()
    UIGraphicsEndImageContext()
    UIImageWriteToSavedPhotosAlbum(image_t!,nil,nil,nil)
    
    let isHangulModel = hangleModel()
    let imagere : UIImage?
    /// 추론 모델에 따른 이미지 크기 변경
    if isHangulModel {
      imagere = imageCapture.scaledImage(with: CGSize(width: 64, height: 64))
    }else{
      imagere = imageCapture.scaledImage(with: CGSize(width: 28, height: 28))
      
    }
    guard let image = imagere else {
      resultsTextView.text = "이미지를 찾을 수 없어요."
      return
    }
    
    resultsTextView.text = "로컬 모델 로딩.."
    if !modelManager.loadLocalModel(isHangul: hangleModel()) {
      resultsTextView.text = "로컬 모델 로딩 실패"
      return
    }

    var newResultsTextString = "추론 시작...💬\n"
    if let currentText = resultsTextView.text {
      newResultsTextString = currentText + newResultsTextString
    }
    resultsTextView.text = newResultsTextString
    
    DispatchQueue.global(qos: .userInitiated).async {
      var imageData: Any?
      imageData = self.modelManager.scaledPixelArray(from: image,
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
  func showAlertWith(title: String, message: String){
    let ac = UIAlertController(title: title, message: message, preferredStyle: .alert)
    ac.addAction(UIAlertAction(title: "OK", style: .default))
    present(ac, animated: true)
  }
  /// 현재 선택한 로컬 모델의 이름을 반환합니다.
  private func currentLocalModelName() -> String {
    switch modelControl.selectedSegmentIndex {
    case 0:
      return ModelInterpreterConstants.floatModelFilename
    case 1:
      return ModelInterpreterConstants.hangulModelFilename
    default:
      fatalError("Unsupported model.")
    }
  }
  
  fileprivate func hangleModel() -> Bool {
    return (modelControl.selectedSegmentIndex == 1)
  }
  
  /// Sets up the local model.
  private func setUpLocalModel() {
    let name = currentLocalModelName()
    let filename = currentLocalModelName()
    if !modelManager.setUpLocalModel(withName: name, filename: filename) {
      resultsTextView.text = "\(name) Failed to set up the local model."
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
extension ViewController {
  //MARK: - Add image to Library
  @objc func image(_ image: UIImage, didFinishSavingWithError error: Error?, contextInfo: UnsafeRawPointer) {
    if let error = error {
      // we got back an error!
      showAlertWith(title: "Save error", message: error.localizedDescription)
    } else {
      showAlertWith(title: "Saved!", message: "Your image has been saved to your photos.")
    }
  }
}

extension ViewController: SwiftyDrawViewDelegate {
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
  
  
}
#if !swift(>=4.2)
extension UIImagePickerController {
  public typealias InfoKey = String
}

extension UIImagePickerController.InfoKey {
  public static let originalImage = UIImagePickerControllerOriginalImage
}
#endif  // !swift(>=4.2)
