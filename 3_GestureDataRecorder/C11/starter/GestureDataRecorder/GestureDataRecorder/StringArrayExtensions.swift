import Foundation

// Rozszerzenie dla tablicy Stringów (Array<String>),
// które umożliwia łatwy zapis danych tekstowych (np. linii CSV) do pliku
extension Array where Element == String {

  // Dodaje wszystkie linie tekstu (self) do pliku na końcu (`append`)
  // Jeśli plik nie istnieje — zostaje utworzony.
  //
  // - Parameter fileURL: URL do pliku, do którego mają być dopisane dane
  // - Throws: Jeśli operacja zapisu się nie powiedzie
  func appendLinesToURL(fileURL: URL) throws {
    // Sprawdza, czy plik już istnieje
    if let fileHandle = FileHandle(forWritingAtPath: fileURL.path) {
      // Zamyka uchwyt po zakończeniu działania bloku
      defer {
        fileHandle.closeFile()
      }
      // Ustawia wskaźnik zapisu na koniec pliku (append mode)
      fileHandle.seekToEndOfFile()

      // Zapisuje dane (zwrócone jako Data przez `toData()`)
      fileHandle.write(self.toData())
    }
    // Jeśli plik nie istnieje — tworzy go z zawartością
    else if !FileManager.default.createFile(atPath: fileURL.path, contents: toData()) {
      // Jeśli również nie udało się stworzyć pliku — wypisz błąd do konsoli
      print("ERROR: data could not be saved to \(fileURL.path)")
    }
  }

  // Konwertuje tablicę Stringów do formatu Data (UTF-8),
  // dodając znak nowej linii `\n` po każdym elemencie.
  //
  // - Returns: Dane gotowe do zapisu jako tekst (np. CSV)
  func toData() -> Data {
    map { $0 + "\n" }         // dodaje \n do każdej linii
      .joined(separator: "")  // łączy wszystkie linie razem
      .data(using: .utf8)     // konwertuje do UTF-8
    ?? Data()                 // jeśli konwersja się nie powiedzie, zwraca pusty obiekt Data
  }
}

