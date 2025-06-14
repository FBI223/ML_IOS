import UIKit
import Vision
import CoreML

class ViewController: UIViewController {

  // Interfejs użytkownika (połączenia z storyboardem)
  @IBOutlet var imageView: UIImageView!              // podgląd zdjęcia
  @IBOutlet var cameraButton: UIButton!              // przycisk aparatu
  @IBOutlet var photoLibraryButton: UIButton!        // przycisk galerii
  @IBOutlet var resultsView: UIView!                 // panel z wynikiem
  @IBOutlet var resultsLabel: UILabel!               // etykieta z wynikiem
  @IBOutlet var resultsConstraint: NSLayoutConstraint! // pozycjonowanie panelu

  var firstTime = true  // do pokazania informacji przy pierwszym uruchomieniu

  // Model klasyfikacji opakowany jako Vision request
  lazy var classificationRequest: VNCoreMLRequest = {
    do {
      // Inicjalizacja modelu HealthySnacks.mlmodel
      let model = try HealthySnacks(configuration: MLModelConfiguration())
      let visionModel = try VNCoreMLModel(for: model.model)

      // Vision request z handlerem wyników
      let request = VNCoreMLRequest(model: visionModel) { [weak self] request, error in
        self?.processObservations(for: request, error: error)
      }

      // Obraz jest wycinany do środka kwadratowego kadru
      request.imageCropAndScaleOption = .centerCrop
      return request
    } catch {
      fatalError("Nie udało się stworzyć modelu: \(error)")
    }
  }()

  // Wywoływane po załadowaniu widoku
  override func viewDidLoad() {
    super.viewDidLoad()

    // Sprawdzenie, czy dostępna jest kamera
    cameraButton.isEnabled = UIImagePickerController.isSourceTypeAvailable(.camera)

    // Ukrycie panelu z wynikiem na starcie
    resultsView.alpha = 0
    resultsLabel.text = "choose or take a photo"
  }

  override func viewDidAppear(_ animated: Bool) {
    super.viewDidAppear(animated)

    // Pokazuje zachętę przy pierwszym otwarciu aplikacji
    if firstTime {
      showResultsView(delay: 0.5)
      firstTime = false
    }
  }

  // Akcja: zrób zdjęcie aparatem
  @IBAction func takePicture() {
    presentPhotoPicker(sourceType: .camera)
  }

  // Akcja: wybierz zdjęcie z galerii
  @IBAction func choosePhoto() {
    presentPhotoPicker(sourceType: .photoLibrary)
  }

  // Pokazuje selektor zdjęcia (kamera lub biblioteka)
  func presentPhotoPicker(sourceType: UIImagePickerController.SourceType) {
    let picker = UIImagePickerController()
    picker.delegate = self
    picker.sourceType = sourceType
    present(picker, animated: true)
    hideResultsView()  // ukrywa stary wynik
  }

  // Animacja pokazania panelu wyników
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

  // Animacja ukrycia wyników
  func hideResultsView() {
    UIView.animate(withDuration: 0.3) {
      self.resultsView.alpha = 0
    }
  }

  // Przetwarza wyniki klasyfikacji zwrócone przez Vision
  func processObservations(for request: VNRequest, error: Error?) {
    DispatchQueue.main.async {
      if let results = request.results as? [VNClassificationObservation] {
        if results.isEmpty {
          self.resultsLabel.text = "nothing found"
        } else if results[0].confidence < 0.8 {
          self.resultsLabel.text = "not sure"
        } else {
          // Formatowanie wyniku: np. "banana 93.4%"
          self.resultsLabel.text = String(format: "%@ %.1f%%", results[0].identifier, results[0].confidence * 100)
        }
      } else if let error = error {
        self.resultsLabel.text = "error: \(error.localizedDescription)"
      } else {
        self.resultsLabel.text = "???"
      }
      self.showResultsView()
    }
  }

    
    
    // Rozszerzenie: obsługa zdjęcia z kamery / galerii
  // Główna funkcja klasyfikacji obrazu
  func classify(image: UIImage) {
    // Konwertuje UIImage na CIImage
    guard let ciImage = CIImage(image: image) else {
      print("Nie udało się przekonwertować na CIImage.")
      return
    }

    // Konwertuje orientację obrazu do formatu wymaganego przez Vision
    let orientation = CGImagePropertyOrientation(image.imageOrientation)

    // W tle wykonuje Vision request
    DispatchQueue.global(qos: .userInitiated).async {
      let handler = VNImageRequestHandler(ciImage: ciImage, orientation: orientation)
      do {
        try handler.perform([self.classificationRequest])
      } catch {
        print("Błąd klasyfikacji: \(error)")
      }
    }
  }
}





// Obsługuje wybór zdjęcia z UIImagePickerController
extension ViewController: UIImagePickerControllerDelegate, UINavigationControllerDelegate {
  func imagePickerController(_ picker: UIImagePickerController,
                             didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
    picker.dismiss(animated: true)

    // Pobiera wybrane zdjęcie
    let image = info[.originalImage] as! UIImage
    imageView.image = image

    // Uruchamia klasyfikację
    classify(image: image)
  }
}







