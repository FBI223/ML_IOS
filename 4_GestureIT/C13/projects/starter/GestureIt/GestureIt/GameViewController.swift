// GameViewController.swift z komentarzami po polsku

import UIKit
import AVFoundation
import CoreMotion
import CoreML

// MARK: - Predefiniowane wypowiedzi dźwiękowe, które lektor może wygłaszać
extension AVSpeechUtterance {
  static let getReady = AVSpeechUtterance(string: "Ready?...Set?...")
  static let chopIt = AVSpeechUtterance(string: "Chop it!")
  static let driveIt = AVSpeechUtterance(string: "Drive it!")
  static let shakeIt = AVSpeechUtterance(string: "Shake it!")
  static let great = AVSpeechUtterance(string: "Great!")
  static let `super` = AVSpeechUtterance(string: "Super!")
  static let nice = AVSpeechUtterance(string: "Nice!")
  static let awesome = AVSpeechUtterance(string: "Awesome!")
  static let sweet = AVSpeechUtterance(string: "Sweet!")
  static let thatsIt = AVSpeechUtterance(string: "That's it!")
  static let timeout = AVSpeechUtterance(string: "Sorry, but time's run out!")
  static let error = AVSpeechUtterance(string: "An error has occurred.")
}

class GameViewController: UIViewController, AVSpeechSynthesizerDelegate {
  // MARK: - Konfiguracja gry i modelu
  struct Config {
    static let chopItValue = "chop_it"       // oczekiwany wynik modelu ML dla gestu "chop"
    static let driveItValue = "drive_it"     // dla gestu "drive"
    static let shakeItValue = "shake_it"     // dla gestu "shake"
    static let restItValue = "rest_it"       // domyślny stan spoczynku

    static let gestureTimeout = 1.5          // maksymalny czas na wykonanie gestu (w sekundach)
    static let doubleSize = MemoryLayout<Double>.stride

    static let samplesPerSecond = 25.0       // częstotliwość danych z czujników
    static let numberOfFeatures = 6          // 3x rotacja + 3x przyspieszenie
    static let windowSize = 20               // rozmiar okna wejściowego dla ML

    static let windowOffset = 5              // przesunięcie między oknami (stride)
    static let numberOfWindows = windowSize / windowOffset
    static let bufferSize = windowSize + windowOffset * (numberOfWindows - 1)

    static let windowSizeAsBytes = doubleSize * numberOfFeatures * windowSize
    static let windowOffsetAsBytes = doubleSize * numberOfFeatures * windowOffset

    static let predictionThreshold = 0.9     // minimalne prawdopodobieństwo uznania predykcji
  }

  // MARK: - Syntezator mowy: ustawia głos na angielski (en-US)
  func configure(_ utterance: AVSpeechUtterance) -> AVSpeechUtterance {
    utterance.voice = AVSpeechSynthesisVoice(language: "en-US")
    return utterance
  }

  // MARK: - Ruch
  let motionManager = CMMotionManager()
  let queue = OperationQueue()

  // MARK: - Core ML
  let modelInput: MLMultiArray! = GameViewController.makeMLMultiArray(numberOfSamples: Config.windowSize)
  let dataBuffer: MLMultiArray! = GameViewController.makeMLMultiArray(numberOfSamples: Config.bufferSize)

  var bufferIndex = 0
  var isDataAvailable = false

  let gestureClassifier = GestureClassifier() // model ML utworzony z .mlmodel
  var modelOutputs = [GestureClassifierOutput?](repeating: nil, count: Config.numberOfWindows)

  // MARK: - Stan gry
  var expectedGesture: String?     // oczekiwany gest
  var timer: Timer?                // timer odpowiedzi
  var score = 0                    // wynik gracza

  // MARK: - UI
  let speechSynth = AVSpeechSynthesizer()
  @IBOutlet var scoreLabel: UILabel!
  @IBOutlet var dismissButton: UIButton!

  override func viewDidLoad() {
    super.viewDidLoad()

    // sprawdzenie poprawności danych wejściowych
    guard modelInput != nil, dataBuffer != nil else {
      displayFatalError("Failed to create required memory storage")
      return
    }

    enableMotionUpdates() // uruchamia czujniki ruchu

    if motionManager.isDeviceMotionAvailable {
      speechSynth.delegate = self
      speechSynth.speak(configure(.getReady), after: 1.0)
    }
  }

  @IBAction func dismiss() {
    dismiss(animated: true, completion: nil)
  }

  // MARK: - Błędy krytyczne
  func displayFatalError(_ error: String) {
    DispatchQueue.main.async {
      let alert = UIAlertController(title: "Unable to Play", message: error, preferredStyle: .alert)
      alert.addAction(UIAlertAction(title: "OK", style: .default) { _ in self.dismiss() })
      self.present(alert, animated: true)
    }
  }

  // MARK: - Logika gry
  func randomGesture() -> String {
    switch Int.random(in: 1...3) {
    case 1: return Config.chopItValue
    case 2: return Config.driveItValue
    default: return Config.shakeItValue
    }
  }

  func startTimer(forGesture gesture: String) {
    resetPredictionWindows()
    expectedGesture = gesture
    timer = Timer(timeInterval: Config.gestureTimeout, repeats: false) { [weak self] _ in
      self?.gameOver()
    }
    RunLoop.current.add(timer!, forMode: .common)
  }

  // MARK: - Obsługa wypowiedzi
  func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
    switch utterance {
    case .getReady, .great, .super, .nice, .awesome, .sweet, .thatsIt:
      switch randomGesture() {
      case Config.chopItValue: speechSynth.speak(configure(.chopIt), after: 0.2)
      case Config.driveItValue: speechSynth.speak(configure(.driveIt), after: 0.2)
      case Config.shakeItValue: speechSynth.speak(configure(.shakeIt), after: 0.2)
      default: speechSynth.speak(configure(.error), after: 0.2)
      }
    case .chopIt: startTimer(forGesture: Config.chopItValue)
    case .driveIt: startTimer(forGesture: Config.driveItValue)
    case .shakeIt: startTimer(forGesture: Config.shakeItValue)
    default: break
    }
  }

  func updateScore() {
    timer?.invalidate()
    score += 1
    if score > 999 {
      disableMotionUpdates()
      speechSynth.speak(configure(AVSpeechUtterance(string: "Ok, nice job. But seriously, you've played this for way too long. It was just a demo!")), after: 0.0)
      DispatchQueue.main.async { self.dismissButton.isHidden = false }
    } else {
      DispatchQueue.main.async {
        self.scoreLabel.text = "Score: \(String(format: "%03d", self.score))"
        switch Int.random(in: 1...6) {
        case 1: self.speechSynth.speak(self.configure(.great))
        case 2: self.speechSynth.speak(self.configure(.super))
        case 3: self.speechSynth.speak(self.configure(.nice))
        case 4: self.speechSynth.speak(self.configure(.awesome))
        case 5: self.speechSynth.speak(self.configure(.sweet))
        default: self.speechSynth.speak(self.configure(.thatsIt))
        }
      }
    }
  }

  func gameOver(incorrectPrediction: String? = nil) {
    timer?.invalidate()
    disableMotionUpdates()

    if let incorrect = incorrectPrediction {
      var wePredicted = ""
      switch incorrect {
      case Config.chopItValue: wePredicted = "chopped it"
      case Config.driveItValue: wePredicted = "drove it"
      case Config.shakeItValue: wePredicted = "shook it"
      default: wePredicted = "did something I didn't recognize"
      }

      var weWanted = ""
      switch expectedGesture {
      case Config.chopItValue: weWanted = "chopped it"
      case Config.driveItValue: weWanted = "driven it"
      case Config.shakeItValue: weWanted = "shaken it"
      default: weWanted = "done something I did recognize"
      }

      expectedGesture = nil
      speechSynth.speak(AVSpeechUtterance(string: "Oops. Sorry, it seems you \(wePredicted) when you should have \(weWanted)."), after: 0.0)
    } else if expectedGesture != nil {
      speechSynth.speak(configure(.timeout))
    }

    DispatchQueue.main.async { self.dismissButton.isHidden = false }
  }

  // MARK: - Obsługa czujników ruchu
  func enableMotionUpdates() {
    guard motionManager.isDeviceMotionAvailable else {
      displayFatalError("Device motion data is unavailable")
      return
    }
    motionManager.deviceMotionUpdateInterval = 1.0 / Config.samplesPerSecond
    motionManager.startDeviceMotionUpdates(using: .xArbitraryZVertical, to: queue) { [weak self] data, error in
      guard let self = self, let data = data else {
        if let error = error {
          print("Device motion update error: \(error.localizedDescription)")
        }
        return
      }
      self.process(motionData: data)
    }
  }

  func disableMotionUpdates() {
    motionManager.stopDeviceMotionUpdates()
  }

  // MARK: - Przygotowanie danych dla modelu ML
  static private func makeMLMultiArray(numberOfSamples: Int) -> MLMultiArray? {
    try? MLMultiArray(shape: [1, numberOfSamples, Config.numberOfFeatures] as [NSNumber], dataType: .double)
  }

  func process(motionData: CMDeviceMotion) {
    guard expectedGesture != nil else { return }
    buffer(motionData: motionData)
    bufferIndex = (bufferIndex + 1) % Config.windowSize
    if bufferIndex == 0 { isDataAvailable = true }

    if isDataAvailable &&
       bufferIndex % Config.windowOffset == 0 &&
       bufferIndex + Config.windowOffset <= Config.windowSize {
      let window = bufferIndex / Config.windowOffset
      memcpy(modelInput.dataPointer,
             dataBuffer.dataPointer.advanced(by: window * Config.windowOffsetAsBytes),
             Config.windowSizeAsBytes)
      predictGesture(window: window)
    }
  }

  @inline(__always)
  func addToBuffer(_ sample: Int, _ feature: Int, _ value: Double) {
    dataBuffer[[0, sample, feature] as [NSNumber]] = value as NSNumber
  }

  func buffer(motionData: CMDeviceMotion) {
    for offset in [0, Config.windowSize] {
      let index = bufferIndex + offset
      if index >= Config.bufferSize { continue }
      addToBuffer(index, 0, motionData.rotationRate.x)
      addToBuffer(index, 1, motionData.rotationRate.y)
      addToBuffer(index, 2, motionData.rotationRate.z)
      addToBuffer(index, 3, motionData.userAcceleration.x)
      addToBuffer(index, 4, motionData.userAcceleration.y)
      addToBuffer(index, 5, motionData.userAcceleration.z)
    }
  }

  func predictGesture(window: Int) {
    let previous = modelOutputs[window]
    let output = try? gestureClassifier.prediction(features: modelInput, hiddenIn: previous?.hiddenOut, cellIn: previous?.cellOut)
    modelOutputs[window] = output

    guard let prediction = output?.activity,
          let probability = output?.activityProbability[prediction],
          prediction != Config.restItValue,
          probability > Config.predictionThreshold
    else { return }

    if prediction == expectedGesture {
      updateScore()
    } else {
      gameOver(incorrectPrediction: prediction)
    }
    expectedGesture = nil
  }

  func resetPredictionWindows() {
    bufferIndex = 0
    isDataAvailable = false
    for i in 0..<modelOutputs.count {
      modelOutputs[i] = nil
    }
  }
}

