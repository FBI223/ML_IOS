import UIKit
import CoreML
import Vision

class ViewController: UIViewController {
  
  // Elementy interfejsu użytkownika
  @IBOutlet var imageView: UIImageView!
  @IBOutlet var backCameraButton: UIButton!
  @IBOutlet var backPhotoLibraryButton: UIButton!
  @IBOutlet var frontCameraButton: UIButton!
  @IBOutlet var frontPhotoLibraryButton: UIButton!

  // Zmienne do przechowywania zdjęć: tło (back) i obiekt (front)
  var backImage: UIImage?
  var frontImage: UIImage?
  var destinationIsBack = false  // flaga określająca, które zdjęcie teraz wybieramy

  // Czy wyświetlać maskę klas (kolory), czy złożone zdjęcie (matting)
  var showingColors = false
  var colors: [[UInt8]] = []

  // Model segmentacji obrazu DeepLab (CoreML)
  let deepLab = try! DeepLab(configuration: MLModelConfiguration())
  let deepLabWidth: Int
  let deepLabHeight: Int

  // Pomiar czasu działania modelu
  var startTime: CFTimeInterval = 0
  var lastResults: MLMultiArray?

  // Vision Request z wykorzystaniem modelu DeepLab
  lazy var visionRequest: VNCoreMLRequest = {
    do {
      let visionModel = try VNCoreMLModel(for: deepLab.model)
      let request = VNCoreMLRequest(model: visionModel, completionHandler: {
        [weak self] request, error in
        self?.processObservations(for: request, error: error)
      })
      request.imageCropAndScaleOption = .scaleFill // dopasowanie do wejścia modelu
      return request
    } catch {
      fatalError("Nie udało się załadować modelu Vision: \(error)")
    }
  }()

  // Konstruktor: uzyskujemy wymiary wyjścia modelu (np. 513x513)
  required init?(coder aDecoder: NSCoder) {
    let outputs = deepLab.model.modelDescription.outputDescriptionsByName
    guard let output = outputs["ResizeBilinear_3__0"],
          let constraint = output.multiArrayConstraint else {
      fatalError("Nie znaleziono wyjścia ResizeBilinear_3__0")
    }
    deepLabHeight = constraint.shape[1].intValue
    deepLabWidth = constraint.shape[2].intValue
    super.init(coder: aDecoder)
  }

  override func viewDidLoad() {
    super.viewDidLoad()

    // Tworzymy paletę kolorów RGB (27 kombinacji) do kolorowania klas
    for r: UInt8 in [0, 255, 127] {
      for g: UInt8 in [0, 127, 255] {
        for b: UInt8 in [63, 127, 255] {
          colors.append([r, g, b])
        }
      }
    }

    // Sprawdzenie dostępności aparatu
    backCameraButton.isEnabled = UIImagePickerController.isSourceTypeAvailable(.camera)
    frontCameraButton.isEnabled = UIImagePickerController.isSourceTypeAvailable(.camera)

    // Tap w ekran przełącza tryb (maski kolorowe / zdjęcie złożone)
    view.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(handleTap)))
  }

  // Obsługa aparatu: zapamiętujemy, czy robimy zdjęcie dla tła czy przodu
  @IBAction func takePicture(sender: UIButton) {
    destinationIsBack = (sender == backCameraButton)
    presentPhotoPicker(sourceType: .camera)
  }

  // Obsługa wyboru zdjęcia z biblioteki
  @IBAction func choosePhoto(sender: UIButton) {
    destinationIsBack = (sender == backPhotoLibraryButton)
    presentPhotoPicker(sourceType: .photoLibrary)
  }

  // Tapnięcie przełącza widok
  @objc func handleTap(sender: UITapGestureRecognizer) {
    if sender.state == .ended {
      showingColors.toggle()
      if let results = lastResults {
        show(results: results)
      }
    }
  }

  // Picker do aparatu lub biblioteki
  func presentPhotoPicker(sourceType: UIImagePickerController.SourceType) {
    let picker = UIImagePickerController()
    picker.delegate = self
    picker.sourceType = sourceType
    present(picker, animated: true)
  }

  // Przesyłamy zdjęcie do modelu do analizy (segmentacji)
  func predict(image: UIImage) {
    startTime = CACurrentMediaTime()
    guard let ciImage = CIImage(image: image) else {
      print("Nie można stworzyć CIImage")
      return
    }
    let orientation = CGImagePropertyOrientation(image.imageOrientation)

    DispatchQueue.global(qos: .userInitiated).async {
      let handler = VNImageRequestHandler(ciImage: ciImage, orientation: orientation)
      do {
        try handler.perform([self.visionRequest])
      } catch {
        print("Błąd działania modelu: \(error)")
      }
    }
  }

  // Obsługa wyników modelu DeepLab (klasy pikseli jako MLMultiArray)
  func processObservations(for request: VNRequest, error: Error?) {
    if let results = request.results as? [VNCoreMLFeatureValueObservation],
       let multiArray = results.first?.featureValue.multiArrayValue {
      lastResults = multiArray
      showingColors = false

      let elapsed = CACurrentMediaTime() - startTime
      print("Model wykonał predykcję w \(elapsed) sekund")

      DispatchQueue.main.async {
        self.show(results: multiArray)
      }
    }
  }

  // Przełączanie widoku — pokazujemy kolorową maskę lub zdjęcie z tłem
  func show(results: MLMultiArray) {
    if !showingColors, let back = backImage, let front = frontImage {
      imageView.image = matteImages(front: front, back: back, features: results)
    } else {
      imageView.image = createMaskImage(from: results)
    }
  }

  // Tworzenie nowego obrazu: piksele z przodu lub tła, w zależności od klasy
  func matteImages(front: UIImage, back: UIImage, features: MLMultiArray) -> UIImage {
    let size = CGSize(width: deepLabWidth, height: deepLabHeight)
    let frontImage = front.resized(to: size)
    let backImage = back.resized(to: size)
    let frontPixels = frontImage.toByteArray()
    let backPixels = backImage.toByteArray()

    let classes = features.shape[0].intValue
    let height = features.shape[1].intValue
    let width = features.shape[2].intValue
    var pixels = [UInt8](repeating: 255, count: width * height * 4)

    let fPtr = UnsafeMutablePointer<Double>(OpaquePointer(features.dataPointer))
    let cStride = features.strides[0].intValue
    let yStride = features.strides[1].intValue
    let xStride = features.strides[2].intValue

    // Dla każdego piksela wybierz klasę z największym prawdopodobieństwem
    for y in 0..<height {
      for x in 0..<width {
        var maxVal: Double = 0
        var maxClass = 0
        for c in 0..<classes {
          let val = fPtr[c*cStride + y*yStride + x*xStride]
          if val > maxVal {
            maxVal = val
            maxClass = c
          }
        }

        let offset = (y*width + x)*4
        let source = (maxClass == 0) ? backPixels : frontPixels

        pixels[offset + 0] = source[offset + 0] // R
        pixels[offset + 1] = source[offset + 1] // G
        pixels[offset + 2] = source[offset + 2] // B
        pixels[offset + 3] = 255
      }
    }

    return UIImage.fromByteArray(&pixels, width: width, height: height)
  }

  // Tworzy kolorową maskę klasyfikacji (każdy piksel pokolorowany wg klasy)
  func createMaskImage(from features: MLMultiArray) -> UIImage {
    let classes = features.shape[0].intValue
    let height = features.shape[1].intValue
    let width = features.shape[2].intValue
    var pixels = [UInt8](repeating: 255, count: width * height * 4)

    let fPtr = UnsafeMutablePointer<Double>(OpaquePointer(features.dataPointer))
    let cStride = features.strides[0].intValue
    let yStride = features.strides[1].intValue
    let xStride = features.strides[2].intValue

    for y in 0..<height {
      for x in 0..<width {
        var maxVal: Double = 0
        var maxClass = 0
        for c in 0..<classes {
          let val = fPtr[c*cStride + y*yStride + x*xStride]
          if val > maxVal {
            maxVal = val
            maxClass = c
          }
        }

        let offset = (y*width + x)*4
        let color = colors[maxClass]
        pixels[offset + 0] = color[0]
        pixels[offset + 1] = color[1]
        pixels[offset + 2] = color[2]
        pixels[offset + 3] = 255
      }
    }

    return UIImage.fromByteArray(&pixels, width: width, height: height)
  }
}

// Obsługa zdjęć z aparatu lub biblioteki
extension ViewController: UIImagePickerControllerDelegate, UINavigationControllerDelegate {
  func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
    picker.dismiss(animated: true)

    let image = info[.originalImage] as! UIImage
    if destinationIsBack {
      backImage = image
    } else {
      frontImage = image
    }

    // Uruchamiamy predykcję tylko dla zdjęcia z przodu
    if let front = frontImage {
      predict(image: front)
    }
  }
}

