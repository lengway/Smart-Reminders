import Foundation
import SmartRemindersCore

/// Простая реализация клиента API на `URLSession` для загрузки/синхронизации напоминаний.
/// Помещается в `Infrastructure/Network` как stub — можно заменить на Alamofire при желании.
public struct APIClient {
    public enum APIError: Error {
        case invalidResponse
        case decodingError(Error)
        case networkError(Error)
    }

    private let baseURL: URL

    public init(baseURL: URL) {
        self.baseURL = baseURL
    }

    /// Пример: GET /reminders -> [Reminder]
    public func fetchReminders(endpoint: String = "reminders") async throws -> [Reminder] {
        let url = baseURL.appendingPathComponent(endpoint)

        do {
            let (data, response) = try await URLSession.shared.data(from: url)

            guard let http = response as? HTTPURLResponse, 200..<300 ~= http.statusCode else {
                throw APIError.invalidResponse
            }

            do {
                let decoder = JSONDecoder()
                decoder.dateDecodingStrategy = .iso8601
                let items = try decoder.decode([Reminder].self, from: data)
                return items
            } catch {
                throw APIError.decodingError(error)
            }
        } catch {
            throw APIError.networkError(error)
        }
    }

    /// Пример синхронизации: отправка одного напоминания методом POST
    public func uploadReminder(_ reminder: Reminder, endpoint: String = "reminders") async throws {
        let url = baseURL.appendingPathComponent(endpoint)
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        do {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            let body = try encoder.encode(reminder)
            let (_, response) = try await URLSession.shared.upload(for: request, from: body)
            guard let http = response as? HTTPURLResponse, 200..<300 ~= http.statusCode else {
                throw APIError.invalidResponse
            }
        } catch let err as APIError {
            throw err
        } catch {
            throw APIError.networkError(error)
        }
    }
}

// Пример использования (в ViewModel или Coordinator):
// let client = APIClient(baseURL: URL(string: "https://api.example.com/")!)
// let remoteReminders = try await client.fetchReminders()
