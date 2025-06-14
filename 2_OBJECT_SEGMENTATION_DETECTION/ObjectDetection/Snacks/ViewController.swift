// Importy frameworków do obsługi wideo, ML i widoku
import CoreMedia
import CoreML
import UIKit
import Vision

// Główna klasa widoku
class ViewController: UIViewController {

  // Widok podglądu z kamery
  @IBOutlet var videoPreview: UIView!

  // Obiekt przechwytujący wideo
  var videoCapture: VideoCapture!
  var currentBuffer: CVPixelBuffer?

  // Vision model — opakowanie modelu CoreML do użycia z Vision
  lazy var visionModel: VNCoreMLModel = {
    do {
        // Inicjalizacja modelu CoreML
        let coreMLWrapper = try! SnackDetector(configuration:MLModelConfiguration())
        let visionModel = try VNCoreMLModel(for: coreMLWrapper.model)

        // Jeśli system to iOS 13+, ustawia dodatkowe parametry detekcji
        if #available(iOS 13.0, *) {
          visionModel.inputImageFeatureName = "image"
          visionModel.featureProvider = try MLDictionaryFeatureProvider(dictionary: [
            "iouThreshold": MLFeatureValue(double: 0.45),
            "confidenceThreshold": MLFeatureValue(double: 0.25),
          ])
        }

        return visionModel
    } catch {
      fatalError("Błąd podczas tworzenia VNCoreMLModel: \(error)")
    }
  }()

  // Konfiguracja żądania Vision do detekcji obiektów
  lazy var visionRequest: VNCoreMLRequest = {
    let request = VNCoreMLRequest(model: visionModel, completionHandler: {
      [weak self] request, error in
      self?.processObservations(for: request, error: error)
    })

    // Skaluje obraz wejściowy tak, aby wypełniał cały input modelu
    request.imageCropAndScaleOption = .scaleFill
    return request
  }()

  // Maksymalna liczba wyświetlanych prostokątów (dla detekcji wielu obiektów)
  let maxBoundingBoxViews = 10
  var boundingBoxViews = [BoundingBoxView]()
  var colors: [String: UIColor] = [:]

  // Wywoływane po załadowaniu widoku
  override func viewDidLoad() {
    super.viewDidLoad()
    setUpBoundingBoxViews() // konfiguracja kolorów i boxów
    setUpCamera()           // start kamery
  }

  // Inicjalizacja obiektów rysujących prostokąty i kolorów klas
  func setUpBoundingBoxViews() {
    for _ in 0..<maxBoundingBoxViews {
      boundingBoxViews.append(BoundingBoxView())
    }

    // Lista etykiet klas (np. wykrywanych przekąsek)
    let labels = ["apple", "banana", "cake", "candy", "carrot",
                  "cookie", "doughnut", "grape", "hot dog", "ice cream",
                  "juice", "muffin", "orange", "pineapple", "popcorn",
                  "pretzel", "salad", "strawberry", "waffle", "watermelon"]

    // Przydziel kolory do każdej klasy (w sumie 20 unikalnych kolorów)
    var i = 0
    for r: CGFloat in [0.5, 0.6, 0.75, 0.8, 1.0] {
      for g: CGFloat in [0.5, 0.8] {
        for b: CGFloat in [0.5, 0.8] {
          colors[labels[i]] = UIColor(red: r, green: g, blue: b, alpha: 1)
          i += 1
        }
      }
    }
  }

  // Ustawienia kamery i podglądu na żywo
  func setUpCamera() {
    videoCapture = VideoCapture()
    videoCapture.delegate = self
    videoCapture.frameInterval = 1  // 30 klatek na sekundę

    // Rozdzielczość kamery HD
    videoCapture.setUp(sessionPreset: .hd1280x720) { success in
      if success {
        // Dodaj warstwę z kamerą do widoku
        if let previewLayer = self.videoCapture.previewLayer {
          self.videoPreview.layer.addSublayer(previewLayer)
          self.resizePreviewLayer()
        }

        // Dodaj warstwy bounding boxów
        for box in self.boundingBoxViews {
          box.addToLayer(self.videoPreview.layer)
        }

        // Start przechwytywania obrazu
        self.videoCapture.start()
      }
    }
  }

  // Aktualizacja rozmiaru podglądu kamery po zmianie układu
  override func viewWillLayoutSubviews() {
    super.viewWillLayoutSubviews()
    resizePreviewLayer()
  }

  // Skalowanie warstwy kamery do rozmiaru widoku
  func resizePreviewLayer() {
    videoCapture.previewLayer?.frame = videoPreview.bounds
  }

  // Wysłanie klatki z kamery do modelu Vision
  func predict(sampleBuffer: CMSampleBuffer) {
    if currentBuffer == nil, let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) {
      currentBuffer = pixelBuffer

      // Parametry obrazu, np. macierz kalibracyjna kamery
      var options: [VNImageOption : Any] = [:]
      if let cameraIntrinsicMatrix = CMGetAttachment(sampleBuffer, key: kCMSampleBufferAttachmentKey_CameraIntrinsicMatrix, attachmentModeOut: nil) {
        options[.cameraIntrinsics] = cameraIntrinsicMatrix
      }

      // Tworzenie i wykonanie żądania Vision
      let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, orientation: .up, options: options)
      do {
        try handler.perform([self.visionRequest])
      } catch {
        print("Błąd wykonania żądania Vision: \(error)")
      }
      currentBuffer = nil
    }
  }

  // Obsługa wyników detekcji obiektów
  func processObservations(for request: VNRequest, error: Error?) {
    DispatchQueue.main.async {
      if let results = request.results as? [VNRecognizedObjectObservation] {
        self.show(predictions: results)
      } else {
        self.show(predictions: [])
      }
    }
  }

  // Wyświetlanie wykrytych obiektów na ekranie
  func show(predictions: [VNRecognizedObjectObservation]) {
    for i in 0..<boundingBoxViews.count {
      if i < predictions.count {
        let prediction = predictions[i]

        // Skaluje box do rozmiarów ekranu
        let width = view.bounds.width
        let height = width * 16 / 9
        let offsetY = (view.bounds.height - height) / 2
        let scale = CGAffineTransform.identity.scaledBy(x: width, y: height)
        let transform = CGAffineTransform(scaleX: 1, y: -1).translatedBy(x: 0, y: -height - offsetY)
        let rect = prediction.boundingBox.applying(scale).applying(transform)

        // Pobiera najlepszą klasę i pewność
        let bestClass = prediction.labels[0].identifier
        let confidence = prediction.labels[0].confidence

        // Pokazuje bounding box z etykietą i kolorem
        let label = String(format: "%@ %.1f", bestClass, confidence * 100)
        let color = colors[bestClass] ?? UIColor.red
        boundingBoxViews[i].show(frame: rect, label: label, color: color)
      } else {
        // Ukrywa nadmiarowe boxy
        boundingBoxViews[i].hide()
      }
    }
  }
}

// Delegat do przechwytywania klatek z kamery
extension ViewController: VideoCaptureDelegate {
  func videoCapture(_ capture: VideoCapture, didCaptureVideoFrame sampleBuffer: CMSampleBuffer) {
    predict(sampleBuffer: sampleBuffer)
  }
}

