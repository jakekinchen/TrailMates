import CoreLocation

// MARK: - Location Item Structure
struct LocationItem {
    let coordinate: CLLocationCoordinate2D
    let title: String
}

// MARK: - Common Locations
struct Locations {
    // Static location properties
    static let shoalBeach = CLLocationCoordinate2D(latitude: 30.26466, longitude: -97.75160)
    static let austinHighBoatLaunch = CLLocationCoordinate2D(latitude: 30.27041, longitude: -97.76594)
    static let texasRowingCenter = CLLocationCoordinate2D(latitude: 30.27208, longitude: -97.76892)
    static let moPacBridgeNorthEntry = CLLocationCoordinate2D(latitude: 30.27484, longitude: -97.77066)
    static let moPacBridgeSouthEntry = CLLocationCoordinate2D(latitude: 30.27284, longitude: -97.77213)
    static let louNeffPoint = CLLocationCoordinate2D(latitude: 30.26721, longitude: -97.76179)
    static let pflugerPedestrianBridge = CLLocationCoordinate2D(latitude: 30.26546, longitude: -97.75587)
    static let stevieRayVaughanStatue = CLLocationCoordinate2D(latitude: 30.26310, longitude: -97.75068)
    static let allianceChildrensGarden = CLLocationCoordinate2D(latitude: 30.26238, longitude: -97.74872)
    static let bufordTowerOverlook = CLLocationCoordinate2D(latitude: 30.26332, longitude: -97.74596)
    static let shoalBeachTreeCanopy = CLLocationCoordinate2D(latitude: 30.26418, longitude: -97.75015)
    static let batObservationDeck = CLLocationCoordinate2D(latitude: 30.26243, longitude: -97.74468)
    static let austinRowingClubPavilion = CLLocationCoordinate2D(latitude: 30.26071, longitude: -97.74192)
    static let blunnCreekObservationDeck = CLLocationCoordinate2D(latitude: 30.25228, longitude: -97.74033)
    static let eastBouldinCreekObservationDeck = CLLocationCoordinate2D(latitude: 30.25455, longitude: -97.74195)
    static let i35ObservationDeckA = CLLocationCoordinate2D(latitude: 30.24897, longitude: -97.73342)
    static let i35ObservationDeckB = CLLocationCoordinate2D(latitude: 30.24833, longitude: -97.73203)
    static let i35ObservationDeckC = CLLocationCoordinate2D(latitude: 30.24768, longitude: -97.73080)
    static let johnZenorPicnicPavilion = CLLocationCoordinate2D(latitude: 30.24644, longitude: -97.72065)
    static let peacePoint = CLLocationCoordinate2D(latitude: 30.24557, longitude: -97.72291)
    static let longhornShores = CLLocationCoordinate2D(latitude: 30.24654, longitude: -97.71523)
    static let underI35North = CLLocationCoordinate2D(latitude: 30.25145, longitude: -97.73590)
    static let raineyStreetTrailhead = CLLocationCoordinate2D(latitude: 30.255573, longitude: -97.739888)
    static let edwardRendonSrParkingLot = CLLocationCoordinate2D(latitude: 30.25039, longitude: -97.73202)
    static let festivalBeachBoatRamp = CLLocationCoordinate2D(latitude: 30.24842, longitude: -97.72787)
    static let internationalShores = CLLocationCoordinate2D(latitude: 30.24543, longitude: -97.72624)
    
    // Location items with titles
    static let items: [LocationItem] = [
        LocationItem(coordinate: shoalBeach, title: "Shoal Beach"),
        LocationItem(coordinate: austinHighBoatLaunch, title: "Austin High Boat Launch"),
        LocationItem(coordinate: texasRowingCenter, title: "Texas Rowing Center"),
        LocationItem(coordinate: moPacBridgeNorthEntry, title: "MoPac Bridge North Entry"),
        LocationItem(coordinate: moPacBridgeSouthEntry, title: "MoPac Bridge South Entry"),
        LocationItem(coordinate: louNeffPoint, title: "Lou Neff Point"),
        LocationItem(coordinate: pflugerPedestrianBridge, title: "Pfluger Pedestrian Bridge"),
        LocationItem(coordinate: stevieRayVaughanStatue, title: "Stevie Ray Vaughan Statue"),
        LocationItem(coordinate: allianceChildrensGarden, title: "Alliance Children's Garden"),
        LocationItem(coordinate: bufordTowerOverlook, title: "Buford Tower Overlook"),
        LocationItem(coordinate: shoalBeachTreeCanopy, title: "Shoal Beach Tree Canopy"),
        LocationItem(coordinate: batObservationDeck, title: "Bat Observation Deck"),
        LocationItem(coordinate: austinRowingClubPavilion, title: "Austin Rowing Club Pavilion"),
        LocationItem(coordinate: blunnCreekObservationDeck, title: "Blunn Creek Observation Deck"),
        LocationItem(coordinate: eastBouldinCreekObservationDeck, title: "East Bouldin Creek Observation Deck"),
        LocationItem(coordinate: i35ObservationDeckA, title: "I-35 Observation Deck A"),
        LocationItem(coordinate: i35ObservationDeckB, title: "I-35 Observation Deck B"),
        LocationItem(coordinate: i35ObservationDeckC, title: "I-35 Observation Deck C"),
        LocationItem(coordinate: johnZenorPicnicPavilion, title: "John Zenor Picnic Pavilion"),
        LocationItem(coordinate: peacePoint, title: "Peace Point"),
        LocationItem(coordinate: longhornShores, title: "Longhorn Shores"),
        LocationItem(coordinate: underI35North, title: "Under I-35 North"),
        LocationItem(coordinate: raineyStreetTrailhead, title: "Rainey Street Trailhead"),
        LocationItem(coordinate: edwardRendonSrParkingLot, title: "Edward Rendon Sr. Parking Lot"),
        LocationItem(coordinate: festivalBeachBoatRamp, title: "Festival Beach Boat Ramp"),
        LocationItem(coordinate: internationalShores, title: "International Shores")
    ]
}
