import Foundation

// Rozszerzenie klasy FileManager — dodaje pomocniczą właściwość,
// która zwraca URL do katalogu Dokumenty aplikacji iOS
extension FileManager {

  // Zwraca ścieżkę do katalogu „Documents” w sandboxie aplikacji.
  // Używany do trwałego zapisywania plików (np. CSV z danymi gestów).
  //
  // Ten katalog:
  // - jest prywatny dla danej aplikacji,
  // - nie jest czyszczony automatycznie przez system,
  // - może być przeglądany np. przez Xcode (Devices → app → Download container).
  //
  // `try!` jest tu używane, bo ten katalog **zawsze istnieje** w aplikacjach iOS.
  static var documentDirectoryURL: URL {
    try! FileManager.default.url(
      for: .documentDirectory,        // typ katalogu: Dokumenty
      in: .userDomainMask,            // katalog użytkownika (sandbox aplikacji)
      appropriateFor: nil,            // niepotrzebne — brak powiązanego pliku
      create: false                   // nie twórz jeśli nie istnieje (i tak istnieje zawsze)
    )
  }
}
