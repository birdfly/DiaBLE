import Foundation

class Abbott: Transmitter {
    override class var type: DeviceType { DeviceType.transmitter(.abbott) }
    override class var name: String { "Abbott" }

    enum UUID: String, CustomStringConvertible, CaseIterable {
        case abbottCustom     = "FDE3"
        case bleLogin         = "F001"
        case compositeRawData = "F002"

        var description: String {
            switch self {
            case .abbottCustom:      return "Abbott custom"
            case .bleLogin:          return "BLE login"
            case .compositeRawData:  return "composite raw data"
            }
        }
    }

    override class var knownUUIDs: [String] { UUID.allCases.map{$0.rawValue} }

    override class var dataServiceUUID: String { UUID.abbottCustom.rawValue }
    override class var dataWriteCharacteristicUUID: String { UUID.bleLogin.rawValue }
    override class var dataReadCharacteristicUUID: String  { UUID.compositeRawData.rawValue }


    override func read(_ data: Data, for uuid: String) {

        switch UUID(rawValue: uuid) {

        case .compositeRawData:
            if sensor == nil {
                sensor = Sensor(transmitter: self)
                main.app.sensor = sensor
            }
            if buffer.count == 0 { sensor!.lastReadingDate = main.app.lastReadingDate }
            buffer.append(data)
            main.log("\(name): partial buffer size: \(buffer.count)")
            if buffer.count == 20 + 18 + 8 {
                // TODO
                sensor!.history.insert(contentsOf: parseBLEData(Data(try! Libre2.decryptBLE(id: [UInt8](sensor!.uid), data: [UInt8](buffer)))), at: 0)
                main.status("\(sensor!.type)  +  BLE)")
            }

        default:
            break
        }
    }


    // TEST
    func parseBLEData( _ data: Data = Data("ee098c09e6898b0dd1c98a0dc1898c09a6098d0d9dc98a0d94c98a0dd2c98a0d000008040000080cf52cc08e".bytes)) -> [Glucose] {
        
        var bleGlucose: [Glucose] = []
        for i in 0 ..< 10 {
            var temperatureAdjustment = readBits(data, i * 4, 0x1a, 0x5) << 2
            let negativeAdjustment = readBits(data, i * 4, 0x1f, 0x1)
            if negativeAdjustment != 0 {
                temperatureAdjustment = -temperatureAdjustment
            }
            let glucose = Glucose(raw: readBits(data, i * 4, 0, 0xe),
                                  rawTemperature: readBits(data, i * 4, 0xe, 0xc) << 2,
                                  temperatureAdjustment: temperatureAdjustment)
            bleGlucose.append(glucose)
        }
        let wearTimeMinutes = UInt16(data[41], data[40])
        let crc = UInt16(data[42], data[43])
        main.debugLog("Bluetooth: received BLE data 0x\(data.hex) (wear time: \(wearTimeMinutes) minutes (0x\(String(format: "%04x", wearTimeMinutes))), CRC: \(String(format: "%04x", crc)), computed CRC: \(String(format: "%04x", crc16(Data(data[0...41]))))), glucose values: \(bleGlucose)")
        return bleGlucose
    }

}