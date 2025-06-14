import UIKit
import AVFoundation
import CoreMotion

// Główna klasa widoku — kontroler aplikacji do nagrywania gestów
class ViewController: UIViewController, AVSpeechSynthesizerDelegate {

  // MARK: - Stałe

  /*
   TO SA DANE CSV
   
   timestamp, roll, pitch, yaw, rotX, rotY, rotZ, gravX, gravY, gravZ, accX, accY, accZ, label


   
   
   1. drive-it (jazda)

   Ruch:
   Płynne, łagodne przesuwanie telefonu przód–tył lub lekko w bok jak przy trzymaniu kierownicy.

   Cechy liczbowe:
   rotX/Y/Z: niskie (około 0.01–0.1 rad/s) → prawie brak obrotów
   accX/Y/Z: bliskie zeru, rzadkie wychylenia → bardzo małe przyspieszenia
   gravZ: stabilne w okolicach −1 (telefon pionowo), wskazuje trzymanie w dłoni
   roll, pitch, yaw: zmieniają się powoli, zmiany o niskiej częstotliwości
   brak gwałtownych skoków ani periodyczności
   
   
   
   
  2. shake-it (potrząsanie)

  Ruch:
  Nagłe, chaotyczne drgania — np. potrząsanie jak butelką.

  Cechy liczbowe:
  rotX/Y/Z: duże skoki, np. ±2.0 rad/s → telefon mocno obracany
  accX/Y/Z: gwałtowne wartości, np. ±1.0–±2.5 m/s² (szczególnie accX, accY)
  roll, pitch, yaw: silnie niestabilne, losowe zmiany
  brak rytmu, ale wysoka entropia i duży standard deviation
   
   
  3. chop-it (siekanie)

  Ruch:
  Rytmiczne poruszanie w pionie, np. jak siekanie ręką w dół.

  Cechy liczbowe:
  rotX: dominujący i powtarzalny (np. sinusoidalny z amplitudą ±1.0)
  accZ: regularne skoki w dół i w górę, np. −1.0 → 0.5 → −1.0
  gravZ: lekko się zmienia, ale wciąż zbliżone do −1
  widoczna periodyczność (da się wykryć FFT)
   
   
   */
  
  
  func configure(_ utterance: AVSpeechUtterance) -> AVSpeechUtterance {
    utterance.voice = AVSpeechSynthesisVoice(language: "en-US")
    return utterance
  }
  
  // Teksty, które aplikacja wypowiada podczas sesji nagrywania
  enum Utterances {
    static let phonePlacement = AVSpeechUtterance(string: "Please hold your phone in your right hand...")
    static let sessionStart = AVSpeechUtterance(string: "The session will begin in 5...4...3...2...1...")
    static let driveIt = AVSpeechUtterance(string: "Position the phone out in front of you... pretend to drive...")
    static let shakeIt = AVSpeechUtterance(string: "Hold it firmly, and shake the phone vigorously...")
    static let chopIt = AVSpeechUtterance(string: "Begin making a steady chopping motion...")

    // Odliczanie i komunikaty systemowe
    static let begin = AVSpeechUtterance(string: "Begin in 3...2...1.")
    static let sessionComplete = AVSpeechUtterance(string: "This recording session is now complete.")
    static let error = AVSpeechUtterance(string: "An error has occurred.")
    
    // Odliczanie czasu
    static let twenty = AVSpeechUtterance(string: "20")
    static let fifteen = AVSpeechUtterance(string: "15")
    static let ten = AVSpeechUtterance(string: "10")
    static let nine = AVSpeechUtterance(string: "9")
    static let eight = AVSpeechUtterance(string: "8")
    static let seven = AVSpeechUtterance(string: "7")
    static let six = AVSpeechUtterance(string: "6")
    static let five = AVSpeechUtterance(string: "5")
    static let four = AVSpeechUtterance(string: "4")
    static let three = AVSpeechUtterance(string: "3")
    static let two = AVSpeechUtterance(string: "2")
    static let one = AVSpeechUtterance(string: "1")
    static let stop = AVSpeechUtterance(string: "And stop.")
    static let rest = AVSpeechUtterance(string: "Now rest for a few seconds.")
    static let ok = AVSpeechUtterance(string: "Ok, I hope you're ready.")
    static let again = AVSpeechUtterance(string: "When the countdown ends, please perform the same activity as before.")
  }

  // Konfiguracja zachowania aplikacji
  enum Config {
    static let countdownPace = 0.75                 // czas między wypowiedziami licznika
    static let countdownSkip5 = 5.0                 // dłuższa pauza między niektórymi liczbami
    static let secondsBetweenSetupInstructions = 1.0
    static let samplesPerSecond = 25.0              // liczba próbek/s dla czujników
  }

  // Typy aktywności, które aplikacja rozpoznaje
  enum ActivityType: Int {
    case none, driveIt, shakeIt, chopIt
  }

  // MARK: - Właściwości sesji

  var sessionId: String!                            // unikalny identyfikator sesji (np. data)
  var numberOfActionsRecorded = 0                   // licznik nagranych powtórzeń gestu
  var currendActivity = ActivityType.none           // aktualnie wykonywana aktywność
  var isRecording = false                           // czy trwa nagrywanie danych

  // MARK: - Motion i dane

  let motionManager = CMMotionManager()             // menedżer czujników CoreMotion
  let queue = OperationQueue()                      // kolejka dla asynchronicznego odczytu danych
  var activityData: [String] = []                   // tablica tekstowa z zebranymi próbkami

  // MARK: - UI

  let speechSynth = AVSpeechSynthesizer()           // syntezator mowy (VoiceOver)

  // Połączenia z elementami interfejsu użytkownika
  @IBOutlet var sessionStartButton: UIButton!
  @IBOutlet var activityChooser: UISegmentedControl!
  @IBOutlet var numRecordingsChooser: UISegmentedControl!
  @IBOutlet var userIdField: UITextField!
  
  
  

  override func viewDidLoad() {
    super.viewDidLoad()
    speechSynth.delegate = self                     // delegacja do reagowania na zakończenie wypowiedzi
  }

  // Ukryj klawiaturę po kliknięciu poza polem tekstowym
  @IBAction func dismissKeypad() {
    view.endEditing(true)
  }

  // Sprawdzenie czy pole ID nie jest puste – aktywacja przycisku START
  @IBAction func userIdChanged() {
    let isGoodId = userIdField.text != nil && userIdField.text!.count > 0
    sessionStartButton.isEnabled = isGoodId
  }

  // Włączanie/wyłączanie wszystkich elementów UI
  func enableUI(isEnabled: Bool) {
    sessionStartButton.isEnabled = isEnabled
    userIdField.isEnabled = isEnabled
    activityChooser.isEnabled = isEnabled
    numRecordingsChooser.isEnabled = isEnabled
    UIApplication.shared.isIdleTimerDisabled = !isEnabled
  }

  // Zwraca liczbę powtórzeń na podstawie wybranej opcji (1–3)
  var numberOfActionsToRecord: Int {
    numRecordingsChooser.selectedSegmentIndex + 1
  }

  // Zwraca wybraną aktywność jako enum
  var selectedActivity: ActivityType {
    switch activityChooser.selectedSegmentIndex {
    case 0: return .driveIt
    case 1: return .shakeIt
    case 2: return .chopIt
    default: return .none
    }
  }

  // Nazwa gestu jako string (dla nazwy pliku CSV)
  var selectedActivityName: String {
    switch activityChooser.selectedSegmentIndex {
    case 0: return "drive-it"
    case 1: return "shake-it"
    case 2: return "chop-it"
    default: return "Nothing"
    }
  }

  // Sprawdzenie czy dla danego userId istnieją już pliki nagrań
  func isUserIdInUse() -> Bool {
    do {
      let files = try FileManager.default.contentsOfDirectory(
        at: FileManager.documentDirectoryURL,
        includingPropertiesForKeys: [.isRegularFileKey])
      return files.contains { $0.lastPathComponent.starts(with: "u\(userIdField.text!)") }
    } catch {
      print("Błąd odczytu katalogu dokumentów: \(error)")
      return false
    }
  }

  // Pokazuje okno dialogowe jeśli ID już istnieje
  func confirmUserIdAndStartRecording() {
    let confirmDialog = UIAlertController(title: "User ID Already Exists",
                                          message: "Data will be added to this user's files...",
                                          preferredStyle: .alert)
    confirmDialog.addAction(UIAlertAction(title: "That's me!", style: .default, handler: { _ in self.startRecording() }))
    confirmDialog.addAction(UIAlertAction(title: "Change ID", style: .cancel, handler: { _ in self.userIdField.becomeFirstResponder() }))
    present(confirmDialog, animated: true)
  }

  // Uruchamia sesję nagrywania
  @IBAction func startRecordingSession() {
    guard motionManager.isDeviceMotionAvailable else {
      DispatchQueue.main.async {
        let alert = UIAlertController(title: "Unable to Record", message: "Device motion data is unavailable", preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "Ok", style: .default))
        self.present(alert, animated: true)
      }
      return
    }

    if isUserIdInUse() {
      confirmUserIdAndStartRecording()
    } else {
      startRecording()
    }
  }

  // Inicjuje sesję nagrywania
  func startRecording() {
    enableUI(isEnabled: false)
    sessionId = ISO8601DateFormatter().string(from: Date())
    numberOfActionsRecorded = 0
    speechSynth.speak(configure(Utterances.phonePlacement))

  }

  // Losowe odliczanie czasu trwania aktywności
  func randomRecordTimeCountdown() -> AVSpeechUtterance {
    switch Int.random(in: 1...2) {
    case 1: return Utterances.fifteen
    default: return Utterances.twenty
    }
  }

  // Losowe odliczanie czasu odpoczynku
  func randomRestTimeCountDown() -> AVSpeechUtterance {
    switch Int.random(in: 1...3) {
    case 1: return Utterances.five
    case 2: return Utterances.six
    default: return Utterances.four
    }
  }

  // Obsługa zakończenia wypowiedzi
  func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
    switch utterance {
    case Utterances.phonePlacement:
      speechSynth.speak(configure( Utterances.sessionStart), after: Config.secondsBetweenSetupInstructions)

    case Utterances.sessionStart:
      enableMotionUpdates()
      queueNextActivity()

    case Utterances.driveIt, Utterances.shakeIt, Utterances.chopIt:
      speechSynth.speak( configure(Utterances.begin), after: Config.countdownPace)

    case Utterances.begin:
      isRecording = true
      speechSynth.speak(configure(randomRecordTimeCountdown()), after: Config.countdownPace)

    case Utterances.twenty: speechSynth.speak(configure(Utterances.fifteen), after: Config.countdownSkip5)
    case Utterances.fifteen: speechSynth.speak(configure(Utterances.ten), after: Config.countdownSkip5)
    case Utterances.ten: speechSynth.speak(configure(Utterances.nine), after: Config.countdownPace)
    case Utterances.nine: speechSynth.speak(configure(Utterances.eight), after: Config.countdownPace)
    case Utterances.eight: speechSynth.speak(configure(Utterances.seven), after: Config.countdownPace)
    case Utterances.seven: speechSynth.speak(configure(Utterances.six), after: Config.countdownPace)
    case Utterances.six: speechSynth.speak(configure(Utterances.five), after: Config.countdownPace)
    case Utterances.five: speechSynth.speak(configure(Utterances.four), after: Config.countdownPace)
    case Utterances.four: speechSynth.speak(configure(Utterances.three), after: Config.countdownPace)
    case Utterances.three: speechSynth.speak(configure(Utterances.two), after: Config.countdownPace)
    case Utterances.two: speechSynth.speak(configure(Utterances.one), after: Config.countdownPace)

    case Utterances.one:
      if isRecording {
        speechSynth.speak(configure(Utterances.stop), after: Config.countdownPace)
      } else {
        speechSynth.speak(configure(Utterances.ok), after: Config.countdownPace)
      }

    case Utterances.stop:
      isRecording = false
      if numberOfActionsRecorded >= numberOfActionsToRecord {
        speechSynth.speak(configure(Utterances.sessionComplete), after: Config.secondsBetweenSetupInstructions)
      } else {
        speechSynth.speak(configure(Utterances.rest), after: Config.secondsBetweenSetupInstructions)
      }

    case Utterances.rest:
      speechSynth.speak(configure(randomRestTimeCountDown()), after: Config.countdownPace)

    case Utterances.ok:
      queueNextActivity()

    case Utterances.again:
      speechSynth.speak(configure(Utterances.begin), after: Config.countdownPace)

    case Utterances.sessionComplete:
      disableMotionUpdates()
      DispatchQueue.main.async {
        self.saveActivityData()
        self.enableUI(isEnabled: true)
      }

    default:
      print("WARNING: Nieobsłużona wypowiedź")
    }
  }

  // Wybiera odpowiednią wypowiedź do danego gestu
  func utterance(for activity: ActivityType) -> AVSpeechUtterance {
    switch activity {
    case .driveIt: return Utterances.driveIt
    case .shakeIt: return Utterances.shakeIt
    case .chopIt: return Utterances.chopIt
    default: return Utterances.error
    }
  }

  // Harmonogram nagrywania powtórzeń tego samego gestu
  func queueNextActivity() {
    if numberOfActionsRecorded >= numberOfActionsToRecord {
      speechSynth.speak(configure(Utterances.sessionComplete), after: Config.secondsBetweenSetupInstructions)
      return
    }

    DispatchQueue.main.async {
      self.numberOfActionsRecorded += 1
      self.currendActivity = self.selectedActivity
      if self.numberOfActionsRecorded > 1 {
        self.speechSynth.speak(self.configure(Utterances.again))
      } else {
        self.speechSynth.speak(self.configure(self.utterance(for: self.currendActivity)))
      }
    }
  }

  // Potwierdzenie i zapis danych do pliku CSV
  func saveActivityData() {
    DispatchQueue.main.async {
      let confirmDialog = UIAlertController(title: "Session Complete", message: "Save or discard data from this session?", preferredStyle: .actionSheet)
      let action = UIAlertAction(title: "Save", style: .default, handler: self.confirmSavingActivityData)
      confirmDialog.addAction(action)
      confirmDialog.addAction(UIAlertAction(title: "Discard", style: .cancel))
      self.present(confirmDialog, animated: true)
    }
  }

  // Właściwy zapis do pliku CSV w katalogu Dokumenty
  private func confirmSavingActivityData(_ action: UIAlertAction) {
    let dataURL = FileManager.documentDirectoryURL
      .appendingPathComponent("u\(self.userIdField.text!)-\(self.selectedActivityName)-data")
      .appendingPathExtension("csv")

    do {
      try self.activityData.appendLinesToURL(fileURL: dataURL)
      print("Data appended to \(dataURL)")
    } catch {
      print("Błąd zapisu: \(error)")
    }
  }

  // MARK: - Obsługa czujników

  // Obsługa jednej próbki czujników – konwersja na wiersz CSV
  func process(data motionData: CMDeviceMotion) {
    let activity = isRecording ? currendActivity : .none
    let sample = """
    \(sessionId!)-\(numberOfActionsRecorded),\
    \(activity.rawValue),\
    \(motionData.attitude.roll),\
    \(motionData.attitude.pitch),\
    \(motionData.attitude.yaw),\
    \(motionData.rotationRate.x),\
    \(motionData.rotationRate.y),\
    \(motionData.rotationRate.z),\
    \(motionData.gravity.x),\
    \(motionData.gravity.y),\
    \(motionData.gravity.z),\
    \(motionData.userAcceleration.x),\
    \(motionData.userAcceleration.y),\
    \(motionData.userAcceleration.z)
    """
    activityData.append(sample)
  }

  // Uruchamia odczyt danych z czujników
  func enableMotionUpdates() {
    // 1
    motionManager.deviceMotionUpdateInterval =
    1 / Config.samplesPerSecond
    // 2
    activityData = []
    // 3
    motionManager.startDeviceMotionUpdates(
      using: .xArbitraryZVertical,
      to: queue,
      withHandler: { [weak self] motionData, error in
        // 4
        guard let self = self, let motionData = motionData else {
          let errorText = error?.localizedDescription ?? "Unknown"
          print("Device motion update error: \(errorText)")
          return
        }
        // 5
        self.process(data: motionData)
      })
  }

  // Zatrzymuje odczyt danych z czujników
  func disableMotionUpdates() {
    motionManager.stopDeviceMotionUpdates()
  }
}

