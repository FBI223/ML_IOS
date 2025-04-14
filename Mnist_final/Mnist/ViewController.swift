// ML in iOS

import UIKit
import CoreML
import Vision

class ViewController: UIViewController {
  
  @IBOutlet var imageView: UIImageView!
  @IBOutlet var cameraButton: UIButton!
  @IBOutlet var photoLibraryButton: UIButton!
  @IBOutlet var resultsView: UIView!
  @IBOutlet var resultsLabel: UILabel!
  @IBOutlet var resultsConstraint: NSLayoutConstraint!

  var firstTime = true

  let myModel = try! MyModel()

  override func viewDidLoad() {
    super.viewDidLoad()
    cameraButton.isEnabled = UIImagePickerController.isSourceTypeAvailable(.camera)
    resultsView.alpha = 0
    resultsLabel.text = "choose or take a photo"
  }

  override func viewDidAppear(_ animated: Bool) {
    super.viewDidAppear(animated)

    // Show the "choose or take a photo" hint when the app is opened.
    if firstTime {
      showResultsView(delay: 0.5)
      firstTime = false
    }
  }
  
  @IBAction func takePicture() {
    presentPhotoPicker(sourceType: .camera)
  }

  @IBAction func choosePhoto() {
    presentPhotoPicker(sourceType: .photoLibrary)
  }

  func presentPhotoPicker(sourceType: UIImagePickerController.SourceType) {
    let picker = UIImagePickerController()
    picker.delegate = self
    picker.sourceType = sourceType
    present(picker, animated: true)
    hideResultsView()
  }

  func showResultsView(delay: TimeInterval = 0.1) {
    resultsConstraint.constant = 100
    view.layoutIfNeeded()

    UIView.animate(withDuration: 0.5,
                   delay: delay,
                   usingSpringWithDamping: 0.6,
                   initialSpringVelocity: 0.6,
                   options: .beginFromCurrentState,
                   animations: {
      self.resultsView.alpha = 1
      self.resultsConstraint.constant = -10
      self.view.layoutIfNeeded()
    },
    completion: nil)
  }

  func hideResultsView() {
    UIView.animate(withDuration: 0.3) {
      self.resultsView.alpha = 0
    }
  }

  func classify(image: UIImage) {
        guard let inputArray = preprocessImage(image) else {
            print("Could not process image to input tensor of shape 1x784.")
            return
        }

        DispatchQueue.global(qos: .userInitiated).async {
            do {
                let input = MyModelInput(dense_input: inputArray)
                let output = try self.myModel.prediction(input: input)

                let outputArray = output.Identity
                var maxValue: Float32 = -Float.greatestFiniteMagnitude
                var maxIndex = -1

                for i in 0..<outputArray.count {
                    let value = outputArray[i].floatValue
                    if value > maxValue {
                        maxValue = value
                        maxIndex = i
                    }
                }

                DispatchQueue.main.async {
                    self.resultsLabel.text = "Digit: \(maxIndex), probability: \(maxValue)"
                    self.showResultsView()
                }
            } catch {
                print("Classification error: \(error)")
            }
        }
  }
    
    
    func preprocessImage(_ image: UIImage) -> MLMultiArray? {
        // 1. Convert to a square with margin, preserving aspect ratio.
        let targetSize = CGSize(width: 28, height: 28)
        let imageSize = image.size
        let scale = min(targetSize.width / imageSize.width, targetSize.height / imageSize.height)
        let scaledSize = CGSize(width: imageSize.width * scale, height: imageSize.height * scale)
        UIGraphicsBeginImageContextWithOptions(targetSize, false, 1.0)
        let origin = CGPoint(x: (targetSize.width - scaledSize.width) / 2, y: (targetSize.height - scaledSize.height) / 2)
        image.draw(in: CGRect(origin: origin, size: scaledSize))
        guard let resized = UIGraphicsGetImageFromCurrentImageContext() else { return nil }
        UIGraphicsEndImageContext()
        
        // 2. Grayscale
        guard let ciImage = CIImage(image: resized) else { return nil }
        let grayscale = ciImage.applyingFilter("CIColorControls", parameters: [kCIInputSaturationKey: 0.0])
        let context = CIContext()
        guard let finalCGImage = context.createCGImage(grayscale, from: grayscale.extent) else { return nil }
        
        // 3. Read pixels
        var pixelData = [UInt8](repeating: 0, count: 28 * 28)
        let colorSpace = CGColorSpaceCreateDeviceGray()
        let bitmapContext = CGContext(
            data: &pixelData,
            width: 28,
            height: 28,
            bitsPerComponent: 8,
            bytesPerRow: 28,
            space: colorSpace,
            bitmapInfo: 0)!
        
        bitmapContext.draw(finalCGImage, in: CGRect(x: 0, y: 0, width: 28, height: 28))
        
        // 4. Calculate the centroid of the image
        var totalMass: Float = 0
        var sumX: Float = 0
        var sumY: Float = 0
        for y in 0..<28 {
            for x in 0..<28 {
                let i = y * 28 + x
                let value = Float(255 - pixelData[i]) / 255.0  // inwersja (ciemne = masa)
                totalMass += value
                sumX += Float(x) * value
                sumY += Float(y) * value
            }
        }
        
        let centerX = totalMass > 0 ? sumX / totalMass : 13.5
        let centerY = totalMass > 0 ? sumY / totalMass : 13.5
        
        let shiftX = Int(round(13.5 - centerX))
        let shiftY = Int(round(13.5 - centerY))
        
        // 5. Translate (shift) the image relative to its centroid.
        var shiftedData = [Float](repeating: 0.0, count: 28 * 28)
        for y in 0..<28 {
            for x in 0..<28 {
                let srcX = x - shiftX
                let srcY = y - shiftY
                if srcX >= 0, srcX < 28, srcY >= 0, srcY < 28 {
                    let fromIdx = srcY * 28 + srcX
                    let toIdx = y * 28 + x
                    shiftedData[toIdx] = Float(255 - pixelData[fromIdx]) / 255.0  // inwersja + normalizacja
                }
            }
        }
        
        // 6. Conversion to MLMultiArray [1, 784]
        guard let inputArray = try? MLMultiArray(shape: [1, 784], dataType: .float32) else { return nil }
        
        for i in 0..<784 {
            inputArray[[0, NSNumber(value: i)]] = NSNumber(value: shiftedData[i])
        }
        
        return inputArray
  }
    
  func preprocessImage_old(_ image: UIImage) -> MLMultiArray? {
        // 1. Convert to a square with margin, preserving aspect ratio
        let targetSize = CGSize(width: 28, height: 28)

        // 1.1. Determine the smaller dimension
        let imageSize = image.size
        let scale = min(targetSize.width / imageSize.width, targetSize.height / imageSize.height)
        let scaledSize = CGSize(width: imageSize.width * scale, height: imageSize.height * scale)

        // 1.2. Scale the image while preserving the aspect ratio
        UIGraphicsBeginImageContextWithOptions(targetSize, false, 1.0)
        let origin = CGPoint(
            x: (targetSize.width - scaledSize.width) / 2,
            y: (targetSize.height - scaledSize.height) / 2
        )
        image.draw(in: CGRect(origin: origin, size: scaledSize))
        guard let resized = UIGraphicsGetImageFromCurrentImageContext() else { return nil }
        UIGraphicsEndImageContext()

        // 2. Grayscale
        guard let ciImage = CIImage(image: resized) else { return nil }
        let grayscale = ciImage.applyingFilter("CIColorControls", parameters: [kCIInputSaturationKey: 0.0])
        let context = CIContext()
        guard let finalCGImage = context.createCGImage(grayscale, from: grayscale.extent) else { return nil }

        // 3. Get the pixels
        var pixelData = [UInt8](repeating: 0, count: 28 * 28)
        let colorSpace = CGColorSpaceCreateDeviceGray()
        let bitmapContext = CGContext(
            data: &pixelData,
            width: 28,
            height: 28,
            bitsPerComponent: 8,
            bytesPerRow: 28,
            space: colorSpace,
            bitmapInfo: 0)!

        bitmapContext.draw(finalCGImage, in: CGRect(x: 0, y: 0, width: 28, height: 28))

        // 4. COnversion to MLMultiArray
        guard let inputArray = try? MLMultiArray(shape: [1, 784], dataType: .float32) else { return nil }

        for i in 0..<784 {
            let normalized = Float32(255 - pixelData[i]) / 255.0  // inwersja + normalizacja
            inputArray[[0, NSNumber(value: i)]] = NSNumber(value: normalized)
        }

        return inputArray
    }
    
}

extension ViewController: UIImagePickerControllerDelegate, UINavigationControllerDelegate {
  func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
    picker.dismiss(animated: true)

    let image = info[.originalImage] as! UIImage
    imageView.image = image

    classify(image: image)
  }
}
