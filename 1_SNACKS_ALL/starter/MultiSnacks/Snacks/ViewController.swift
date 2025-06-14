import UIKit
import CoreML
import Vision

class ViewController: UIViewController {
  
  // Interfejs użytkownika
  @IBOutlet var imageView: UIImageView!
  @IBOutlet var cameraButton: UIButton!
  @IBOutlet var photoLibraryButton: UIButton!
  @IBOutlet var resultsView: UIView!
  @IBOutlet var resultsLabel: UILabel!
  @IBOutlet var resultsConstraint: NSLayoutConstraint!

  // Zmienna pomocnicza do pokazania podpowiedzi tylko raz
  var firstTime = true

  // Żądanie klasyfikacji z modelem MultiSnacks.mlmodel
  lazy var classificationRequest: VNCoreMLRequest = {
    do {
      let multiSnacks = MultiSnacks() // Ładuje model .mlmodel
      let visionModel = try VNCoreMLModel(for: multiSnacks.model) // Przekształca go do Vision

      let request = VNCoreMLRequest(model: visionModel, completionHandler: { [weak self] request, error in
        self?.processObservations(for: request, error: error) // Callback po predykcji
      })

      request.imageCropAndScaleOption = .centerCrop // Środek obrazu będzie klasyfikowany
      return request
    } catch {
      fatalError("Failed to create VNCoreMLModel: \(error)")
    }
  }()

  override func viewDidLoad() {
    super.viewDidLoad()

    // Sprawdza, czy dostępny jest aparat
    cameraButton.isEnabled = UIImagePickerController.isSourceTypeAvailable(.camera)
    
    // Ukrywa widok wyników przy starcie
    resultsView.alpha = 0
    resultsLabel.text = "choose or take a photo"
  }

  override func viewDidAppear(_ animated: Bool) {
    super.viewDidAppear(animated)

    // Pokazuje podpowiedź tylko raz przy pierwszym uruchomieniu
    if firstTime {
      showResultsView(delay: 0.5)
      firstTime = false
    }
  }

  // Obsługa przycisku: zrób zdjęcie
  @IBAction func takePicture() {
    presentPhotoPicker(sourceType: .camera)
  }

  // Obsługa przycisku: wybierz zdjęcie z galerii
  @IBAction func choosePhoto() {
    presentPhotoPicker(sourceType: .photoLibrary)
  }

  // Prezentuje UIImagePicker z danego źródła (kamera lub galeria)
  func presentPhotoPicker(sourceType: UIImagePickerController.SourceType) {
    let picker = UIImagePickerController()
    picker.delegate = self
    picker.sourceType = sourceType
    present(picker, animated: true)
    hideResultsView()
  }

  // Pokazuje animacyjnie widok z wynikami
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

  // Ukrywa wyniki (animacja)
  func hideResultsView() {
    UIView.animate(withDuration: 0.3) {
      self.resultsView.alpha = 0
    }
  }

  // Rozpoczyna klasyfikację obrazu przez Vision/CoreML
  func classify(image: UIImage) {
    guard let ciImage = CIImage(image: image) else {
      print("Unable to create CIImage")
      return
    }

    let orientation = CGImagePropertyOrientation(image.imageOrientation)

    DispatchQueue.global(qos: .userInitiated).async {
      let handler = VNImageRequestHandler(ciImage: ciImage, orientation: orientation)
      do {
        try handler.perform([self.classificationRequest])
      } catch {
        print("Failed to perform classification: \(error)")
      }
    }
  }

  // Obsługuje wynik klasyfikacji (lub błąd)
  func processObservations(for request: VNRequest, error: Error?) {
    DispatchQueue.main.async {
      if let results = request.results as? [VNClassificationObservation] {
          if results.isEmpty {
            self.resultsLabel.text = "nothing found"
          } else {
              // Pokazuje 3 najlepsze klasy wraz z procentem
              let top3 = results.prefix(3).map { observation in
                  String(format: "%@ %.1f%%", observation.identifier, observation.confidence * 100)
              }
              self.resultsLabel.text = top3.joined(separator: "\n")
          }
      } else if let error = error {
        self.resultsLabel.text = "error: \(error.localizedDescription)"
      } else {
        self.resultsLabel.text = "???"
      }
      self.showResultsView()
    }
  }
}

// Rozszerzenie do obsługi wyboru zdjęcia z UIImagePickerController
extension ViewController: UIImagePickerControllerDelegate, UINavigationControllerDelegate {
  func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
    picker.dismiss(animated: true)

    // Pobiera obraz z galerii lub aparatu
    let image = info[.originalImage] as! UIImage
    imageView.image = image

    // Uruchamia klasyfikację
    classify(image: image)
  }
}

