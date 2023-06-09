import Core
import SharedModels
@_exported import FirebaseStorage

public extension Storage {
  func certificateRef(
    uid: String,
    dogId: String,
    folderName: String,
    fileName: String
  ) -> StorageReference {
    let storageRef = reference()
    return storageRef.child("\(uid)/\(dogId)/certificates/\(folderName)/\(fileName).jpeg")
  }

  func dogRef(
    uid: String,
    dogId: String,
    fileName: String? = nil
  ) -> StorageReference {
    let storageRef = reference()
    return storageRef.child("\(uid)/\(dogId)/\(name(fileName))")
  }

  func reference(from path: String) -> StorageReference { reference().child(path) }

  func name(_ arg: String?) -> String {
    let name = arg ?? iso8601Full.string(from: .now)
    return name + ".jpeg"
  }
}

public extension StorageReference {
  func get() async throws -> Data {
    try await withCheckedThrowingContinuation { [weak self] (continuation: CheckedContinuation<Data, Error>) in
      self?.getData(maxSize: 1024 * 1024) { data, error in
        if let error = error,
           let loadingError = self?.handleError(error: error).toLoadingError {
          logger.error(message: error)
          continuation.resume(throwing: loadingError)
          return
        }
        if let data = data {
          logger.info(message: "Succeeded in getting")
          continuation.resume(returning: data)
        } else {
          logger.error(message: "unknown error")
          continuation.resume(throwing: CloudStorageError.unknown.toLoadingError)
        }
      }
    }
  }

  func upload(_ data: Data) async throws {
    try await withCheckedThrowingContinuation { [weak self] (continuation: CheckedContinuation<Void, Error>) in
      putData(data) { metadata, error in
        if let error = error,
           let loadingError = self?.handleError(error: error).toLoadingError
        {
          logger.error(message: error)
          continuation.resume(throwing: loadingError)
          return
        }
        logger.info(message: "Succeeded in uploading")
        continuation.resume()
      }
    }
  }

  func handleError(error: Error) -> CloudStorageError {
    let code = (error as NSError).code
    let errorCode = StorageErrorCode(rawValue: code)
    switch errorCode {
    case .bucketNotFound, .objectNotFound, .projectNotFound, .unknown:
      return .notFound
    case .retryLimitExceeded:
      return .limitExceeded
    case .unauthorized, .unauthenticated:
      return .unauthorized
    default:
      return .unknown
    }
  }
}

public let iso8601Full: ISO8601DateFormatter = {
  let formatter = ISO8601DateFormatter()
  formatter.timeZone = TimeZone(identifier: "Asia/Tokyo")!
  formatter.formatOptions = [
    .withFullDate,
    .withTime,
    .withColonSeparatorInTime
  ]
  return formatter
}()
