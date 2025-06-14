import AVFoundation
import CoreVideo
import UIKit

// Protokół do przekazywania przechwyconych klatek wideo
public protocol VideoCaptureDelegate: AnyObject {
  func videoCapture(_ capture: VideoCapture, didCaptureVideoFrame: CMSampleBuffer)
}

// Klasa obsługująca przechwytywanie wideo z kamery i przekazywanie klatek
public class VideoCapture: NSObject {
  // Warstwa do podglądu obrazu z kamery (dla UI)
  public var previewLayer: AVCaptureVideoPreviewLayer?

  // Delegat otrzymujący przechwycone klatki
  public weak var delegate: VideoCaptureDelegate?

  // Co ile klatek przekazywać dalej (1 = każda klatka)
  public var frameInterval = 1
  var seenFrames = 0

  // Sesja przechwytywania + wyjście danych
  let captureSession = AVCaptureSession()
  let videoOutput = AVCaptureVideoDataOutput()

  // Kolejka, na której działa kamera (aby nie blokować UI)
  let queue = DispatchQueue(label: "com.raywenderlich.camera-queue")

  // Czas ostatniej klatki (nieużywany tutaj)
  var lastTimestamp = CMTime()

  // Publiczne API: uruchamia konfigurację kamery asynchronicznie
  public func setUp(sessionPreset: AVCaptureSession.Preset = .medium,
                    completion: @escaping (Bool) -> Void) {
    queue.async {
      let success = self.setUpCamera(sessionPreset: sessionPreset)
      DispatchQueue.main.async {
        completion(success)
      }
    }
  }

  // Główna konfiguracja kamery
  func setUpCamera(sessionPreset: AVCaptureSession.Preset) -> Bool {
    captureSession.beginConfiguration()
    captureSession.sessionPreset = sessionPreset

    // Pobranie domyślnego urządzenia kamery
    guard let captureDevice = AVCaptureDevice.default(for: AVMediaType.video) else {
      print("Błąd: brak dostępnych urządzeń wideo")
      return false
    }

    // Utworzenie wejścia z kamery
    guard let videoInput = try? AVCaptureDeviceInput(device: captureDevice) else {
      print("Błąd: nie udało się utworzyć AVCaptureDeviceInput")
      return false
    }

    // Dodanie wejścia do sesji
    if captureSession.canAddInput(videoInput) {
      captureSession.addInput(videoInput)
    }

    // Konfiguracja warstwy podglądu
    let previewLayer = AVCaptureVideoPreviewLayer(session: captureSession)
    previewLayer.videoGravity = .resizeAspect             // dopasowanie proporcji
    previewLayer.connection?.videoOrientation = .portrait // orientacja pionowa
    self.previewLayer = previewLayer

    // Ustawienia formatu bufora wideo (kolory w BGRA)
    let settings: [String : Any] = [
      kCVPixelBufferPixelFormatTypeKey as String: NSNumber(value: kCVPixelFormatType_32BGRA)
    ]

    videoOutput.videoSettings = settings
    videoOutput.alwaysDiscardsLateVideoFrames = true // pomija spóźnione klatki
    videoOutput.setSampleBufferDelegate(self, queue: queue)

    // Dodanie wyjścia wideo do sesji
    if captureSession.canAddOutput(videoOutput) {
      captureSession.addOutput(videoOutput)
    }

    // Ustawienie orientacji po dodaniu outputu
    videoOutput.connection(with: AVMediaType.video)?.videoOrientation = .portrait

    // Zatwierdzenie konfiguracji
    captureSession.commitConfiguration()
    return true
  }

  // Uruchamia sesję (jeśli nie jest już uruchomiona)
  public func start() {
    if !captureSession.isRunning {
      seenFrames = 0
      captureSession.startRunning()
    }
  }

  // Zatrzymuje przechwytywanie
  public func stop() {
    if captureSession.isRunning {
      captureSession.stopRunning()
    }
  }
}


//  Obsługa delegate’a — przekazywanie klatek do klasy ViewController:
// Rozszerzenie implementujące protokół delegata bufora wideo
extension VideoCapture: AVCaptureVideoDataOutputSampleBufferDelegate {

  // Główna metoda: przekazuje co N-tą klatkę do delegata
  public func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
    // Dzięki temu nie zmniejszamy FPS kamery, tylko filtrujemy ile klatek analizujemy
    seenFrames += 1
    if seenFrames >= frameInterval {
      seenFrames = 0
      delegate?.videoCapture(self, didCaptureVideoFrame: sampleBuffer)
    }
  }

  // Metoda opcjonalna: jeśli klatka została pominięta
  public func captureOutput(_ output: AVCaptureOutput, didDrop sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
    // print("dropped frame") // opcjonalny debug
  }
}

