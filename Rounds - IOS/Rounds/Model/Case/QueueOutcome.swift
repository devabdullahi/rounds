import Foundation

/// What queuing a patient in the background came to (Shortcuts and Siri, without opening the app).
enum QueueOutcome: Equatable {
    /// A patient is waiting on the ward; nil if the ward didn't reload in time to show them.
    case ready(WardPatient?)
    /// The topic's first case is still being written on the server; a later try will work.
    case preparing
    case failed(String)
}
