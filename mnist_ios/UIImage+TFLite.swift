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

import CoreGraphics
import UIKit

/// 이미지 배율을 위한 'UIIMage' 범주입니다.
/// A `UIImage` category for scaling images.
extension UIImage {
    
    /// 지정된 크기에 따라 크기를 조정합니다.
    ///
    /// - 파라미터 크기: 반환된 이미지의 최대 크기.
    /// - 리턴: 이미지 크기 조정에 실패할 경우 제공 크기에 따라 이미지 크기를 조정하거나 영(0)으로 조정합니다.
    
    /// Returns image scaled according to the given size.
    ///
    /// - Parameter size: Maximum size of the returned image.
    /// - Return: Image scaled according to the give size or `nil` if image resize fails.
    public func scaledImage(with size: CGSize) -> UIImage? {
        UIGraphicsBeginImageContextWithOptions(size, false, scale)
        draw(in: CGRect(x: 0, y: 0, width: size.width, height: size.height))
        let scaledImage = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        
        // 스케일링된 이미지를 PNG 또는 JPEG 데이터로 변환하여 비트맵 정보를 보존합니다.
        // Attempt to convert the scaled image to PNG or JPEG data to preserve the bitmap info.
        guard let image = scaledImage else { return nil }
        return image.data.map { UIImage(data: $0) } ?? nil
    }
    /// 이미지의 PNG 또는 JPEG 데이터 표현 또는 변환에 실패한 경우 "없음".
    /// The PNG or JPEG data representation of the image or `nil` if the conversion failed.
    private var data: Data? {
        #if swift(>=4.2)
        return self.pngData() ?? self.jpegData(compressionQuality: Constants.jpegCompressionQuality)
        #else
        return UIImagePNGRepresentation(self) ??
        UIImageJPEGRepresentation(self, Constants.jpegCompressionQuality)
        #endif  // swift(>=4.2)
    }
    
    /// 지정된 값에서 이미지의 확대 이미지 데이터 표현을 반환합니다.
    ///
    /// - 매개 변수
    /// - size(크기): 이미지를 축소할 크기(예: 교육을 받은 모델에서 예상되는 이미지 크기)입니다.
    /// - 구성 요소: 이미지의 색상 구성 요소 수입니다.
    /// - batchSize: 이미지의 배치 크기.
    /// - 반환: 크기를 조정할 수 없는 경우 이미지 데이터 또는 '없음'.
    /// Returns scaled image data representation of the image from the given values.
    ///
    /// - Parameters
    ///   - size: Size to scale the image to (i.e. expected size of the image in the trained model).
    ///   - componentsCount: Number of color components for the image.
    ///   - batchSize: Batch size for the image.
    /// - Returns: The scaled image data or `nil` if the image could not be scaled.
    public func scaledImageData(
        with size: CGSize,
        componentsCount newComponentsCount: Int,
        batchSize: Int
        ) -> Data? {
        guard let cgImage = self.cgImage, cgImage.width > 0, cgImage.height > 0 else { return nil }
        let oldComponentsCount = cgImage.bytesPerRow / cgImage.width
        guard newComponentsCount <= oldComponentsCount else { return nil }
        let newWidth = Int(size.width)
        let newHeight = Int(size.height)
        guard let imageData = imageData(
            from: cgImage,
            size: size,
            componentsCount: oldComponentsCount)
            else {
                return nil
        }
        
        let bytesCount = newWidth * newHeight * newComponentsCount * batchSize * 4
        var scaledBytes = [UInt8](repeating: 0, count: bytesCount)
        // 스케일링된 이미지 데이터에서 RGB(A) 구성 요소를 추출하는 동시에 알파 구성 요소를 무시합니다.
        // Extract the RGB(A) components from the scaled image data while ignoring the alpha component.
        var pixelIndex = 0
        for pixel in imageData.enumerated() {
            let offset = pixel.offset
            let isAlphaComponent = (offset % Constants.alphaComponentBaseOffset) ==
                Constants.alphaComponentModuloRemainder
            guard !isAlphaComponent else { continue }
            scaledBytes[pixelIndex] = pixel.element
            pixelIndex += 1
        }
        
        let scaledImageData = Data(bytes: scaledBytes)
        return scaledImageData
    }
    /// 지정된 값에서 이미지의 배율 조정 픽셀 배열을 반환합니다.
    ///
    /// - 매개 변수
    /// - size(크기): 이미지를 축소할 크기(예: 교육을 받은 모델에서 예상되는 이미지 크기)입니다.
    /// - 구성 요소: 이미지의 색상 구성 요소 수입니다.
    /// - batchSize: 이미지의 배치 크기.
    /// - isQuantized: 모형의 정량화 사용 여부를 나타냅니다. 참인 경우 적용
    /// '(값) / 255'를 각 픽셀으로 변환하여 데이터를 Int(0, 255) 척도에서
    /// 플로트([0, 1]).
    /// - 리턴: 이미지 크기를 조정할 수 없는 경우 크기가 조정된 픽셀 배열 또는 "없음".
    /// Returns a scaled pixel array representation of the image from the given values.
    ///
    /// - Parameters
    ///   - size: Size to scale the image to (i.e. expected size of the image in the trained model).
    ///   - componentsCount: Number of color components for the image.
    ///   - batchSize: Batch size for the image.
    ///   - isQuantized: Indicates whether the model uses quantization. If `true`, apply
    ///     `(value) / 255` to each pixel to convert the data from Int(0, 255) scale to
    ///     Float([0, 1]).
    /// - Returns: The scaled pixel array or `nil` if the image could not be scaled.
    public func scaledPixelArray(
        with size: CGSize,
        componentsCount newComponentsCount: Int,
        batchSize: Int,
        isQuantized: Bool
        ) -> [[[[Any]]]]? {
        guard let cgImage = self.cgImage, cgImage.width > 0, cgImage.height > 0 else { return nil }
        let oldComponentsCount = cgImage.bytesPerRow / cgImage.width
        guard newComponentsCount <= oldComponentsCount else { return nil }
        
        let newWidth = Int(size.width)
        let newHeight = Int(size.height)
        guard let imageData = imageData(
            from: cgImage,
            size: size,
            componentsCount: oldComponentsCount)
            else {
                return nil
        }
        
        var columnArray: [[[Any]]] = isQuantized ? [[[UInt8]]]() : [[[Float32]]]()
        for yCoordinate in 0..<newWidth {
            var rowArray: [[Any]] = isQuantized ? [[UInt8]]() : [[Float32]]()
            for xCoordinate in 0..<newHeight {
                var pixelArray: [Any] = isQuantized ? [UInt8]() : [Float32]()
                for component in 0..<newComponentsCount {
                    let inputIndex =
                        (yCoordinate * newHeight * oldComponentsCount) +
                            (xCoordinate * oldComponentsCount + component)
                    var pixel = Float32(imageData[inputIndex])
                    // Quantized model expects [0, 255] scale, but float expects [0, 1] scale.
                    if !isQuantized {
                        // Normalization:
                        // Convert pixel values from [0, 255] to [0, 1] scale for the float model.
                        pixel /= Constants.maxRGBValue
                    }
                    pixelArray.append(pixel)
                }
                rowArray.append(pixelArray)
            }
            columnArray.append(rowArray)
        }
        return [columnArray]
    }
    
    // MARK: - Private
    /// 지정된 CGImage의 이미지 데이터를 지정된 너비 및 높이로 크기가 조정됩니다.
    /// Returns the image data from the given CGImage resized to the given width and height.
    private func imageData(
        from image: CGImage,
        size: CGSize,
        componentsCount: Int
        ) -> Data? {
        let bitmapInfo = CGBitmapInfo(
            rawValue: CGBitmapInfo.byteOrder32Big.rawValue | CGImageAlphaInfo.premultipliedLast.rawValue
        )
        let width = Int(size.width)
        let height = Int(size.height)
        guard let context = CGContext(
            data: nil,
            width: width,
            height: height,
            bitsPerComponent: image.bitsPerComponent,
            bytesPerRow: componentsCount * width,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: bitmapInfo.rawValue)
            else {
                return nil
        }
        context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
        return context.makeImage()?.dataProvider?.data as Data?
    }
}

// MARK: - Constants

private enum Constants {
    static let maxRGBValue: Float32 = 255.0
    static let jpegCompressionQuality: CGFloat = 0.8
    static let alphaComponentBaseOffset = 4
    static let alphaComponentModuloRemainder = 3
}
