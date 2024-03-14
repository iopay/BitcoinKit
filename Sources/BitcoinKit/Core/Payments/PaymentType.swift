import Foundation

public protocol PaymentType {
    var output: Data { get }
}

public enum PaymentError: Error {
    case outputInvalid
    case addressInvalid
}
