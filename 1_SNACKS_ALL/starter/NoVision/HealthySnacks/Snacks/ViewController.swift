import UIKit
import CoreML
import Vision

/*
 bez Vision:
 - Musisz ręcznie przekonwertować UIImage do CVPixelBuffer.
 - Samodzielnie zarządzasz przygotowaniem danych wejściowych i interpretacją wyników.
 - Więcej kontroli, ale trudniej w użyciu.
 
 z Vision:
 - Vision automatycznie obsługuje konwersję do formatu dla modelu ML.
 - Umożliwia użycie VNImageRequestHandler, VNCoreMLRequest, itd.
 - Obsługuje orientację obrazu, cropping, skalowanie.
*/

class ViewController: UIViewController {
  
  @IBOutlet var imageView: UIImageView!
  @IBOutlet var cameraButton: UIButton!
  @IBOutlet var photoLibraryButton: UIButton!
  @IBOutlet var resultsView: UIView!
  @IBOutlet var resultsLabel: UILabel!
  @IBOutlet var resultsConstraint: NSLayoutConstraint!

  var firstTime = true
  
  // Załadowanie modelu CoreML (HealthySnacks.mlmodel)
  let healthySnacks = HealthySnacks()

  // Klasyfikacja obrazu bez użycia Vision
  func classify(image: UIImage) {
    DispatchQueue.global(qos: .userInitiated).async {
      // Konwersja UIImage do CVPixelBuffer
      if let pixelBuffer = self.pixelBuffer(for: image) {
        // Predykcja modelu
        if let prediction = try? self.healthySnacks.prediction(image: pixelBuffer) {
          // Wybranie najlepszego wyniku
          let results = self.top(1, prediction.labelProbability)
          self.processObservations(results: results)
        } else {
          self.processObservations(results: [])
        }
      }
    }
  }

  // Konwersja UIImage → CVPixelBuffer zgodnie z wymaganiami modelu
  func pixelBuffer(for image: UIImage) -> CVPixelBuffer? {
    let model = healthySnacks.model
    let imageConstraint = model.modelDescription
      .inputDescriptionsByName["image"]!
      .imageConstraint!
    
    // Opcje dla skalowania i cropowania obrazu
    let imageOptions: [MLFeatureValue.ImageOption: Any] = [
      .cropAndScale: VNImageCropAndScaleOption.scaleFill.rawValue
    ]
    
    // Utworzenie CVPixelBuffer (MLFeatureValue) z obrazu
    return try? MLFeatureValue(
      cgImage: image.cgImage!,
      constraint: imageConstraint,
      options: imageOptions).imageBufferValue
  }

  // Zwraca top-k wyników (np. top-1 lub top-3)
  func top(_ k: Int, _ prob: [String: Double]) -> [(String, Double)] {
    return Array(prob.sorted { $0.value > $1.value }
      .prefix(min(k, prob.count)))
  }

  // Wyświetlanie wyników na ekranie
  func processObservations(results: [(identifier: String, confidence: Double)]) {
    DispatchQueue.main.async {
      if results.isEmpty {
        self.resultsLabel.text = "nothing found"
      } else if results[0].confidence < 0.8 {
        self.resultsLabel.text = "not sure"
      } else {
        self.resultsLabel.text = String(
          format: "%@ %.1f%%",
          results[0].identifier,
          results[0].confidence * 100)
      }
      self.showResultsView()
    }
  }

  override func viewDidLoad() {
    super.viewDidLoad()
    // Włączenie przycisku aparatu tylko jeśli dostępny
    cameraButton.isEnabled = UIImagePickerController.isSourceTypeAvailable(.camera)
    resultsView.alpha = 0
    resultsLabel.text = "choose or take a photo"
  }

  override func viewDidAppear(_ animated: Bool) {
    super.viewDidAppear(animated)
    
    // Pokazuje podpowiedź przy pierwszym uruchomieniu aplikacji
    if firstTime {
      showResultsView(delay: 0.5)
      firstTime = false
    }
  }

  // Akcja: zrób zdjęcie
  @IBAction func takePicture() {
    presentPhotoPicker(sourceType: .camera)
  }

  // Akcja: wybierz zdjęcie z biblioteki
  @IBAction func choosePhoto() {
    presentPhotoPicker(sourceType: .photoLibrary)
  }

  // Prezentacja UIImagePickerController
  func presentPhotoPicker(sourceType: UIImagePickerController.SourceType) {
    let picker = UIImagePickerController()
    picker.delegate = self
    picker.sourceType = sourceType
    present(picker, animated: true)
    hideResultsView()
  }

  // Pokazuje panel z wynikami
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

  // Ukrywa panel z wynikami
  func hideResultsView() {
    UIView.animate(withDuration: 0.3) {
      self.resultsView.alpha = 0
    }
  }
}

// Rozszerzenie: obsługa wyboru zdjęcia z aparatu lub biblioteki
extension ViewController: UIImagePickerControllerDelegate, UINavigationControllerDelegate {
  func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
    picker.dismiss(animated: true)

    let image = info[.originalImage] as! UIImage
    imageView.image = image

    // Uruchom klasyfikację
    classify(image: image)
  }
}

