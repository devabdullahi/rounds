import SwiftUI

/// One character's choreography. `lookX`/`lookY`: pupil offset in eye units.
/// `lid`: upper eyelid, 0 open to 1 closed (`lidRight` for a one-eyed blink or wink).
/// `cheek`: 0 to 1, a happy squint. `mouth`: open-mouth depth. `tilt`: head angle in degrees.
struct Choreo: Sendable {
    var period: Double
    var lookX: Keys
    var lookY: Keys
    var lid: Keys
    var lidRight: Keys?
    var cheek: Keys?
    var mouth: Keys?
    var tilt: Keys?
    init(
        period: Double, lookX: Keys, lookY: Keys, lid: Keys,
        lidRight: Keys? = nil, cheek: Keys? = nil, mouth: Keys? = nil, tilt: Keys? = nil
    ) {
        self.period = period
        self.lookX = lookX
        self.lookY = lookY
        self.lid = lid
        self.lidRight = lidRight
        self.cheek = cheek
        self.mouth = mouth
        self.tilt = tilt
    }
}
