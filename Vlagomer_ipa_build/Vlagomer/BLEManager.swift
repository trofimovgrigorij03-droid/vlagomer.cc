import Foundation
import CoreBluetooth

enum Wood: Int, CaseIterable, Identifiable {
    case pine = 0, birch = 1, larch = 2
    var id: Int { rawValue }
    var title: String {
        switch self {
        case .pine: return "Сосна"
        case .birch: return "Берёза"
        case .larch: return "Лиственница"
        }
    }
}

enum MoistureStatus: Int {
    case idle = 0, dry = 2, airDry = 3, wet = 4, shortCircuit = 5, searching = 6

    var title: String {
        switch self {
        case .idle: return "Нажмите «Замерить»"
        case .dry: return "Сухое"
        case .airDry: return "Воздушно-сухое"
        case .wet: return "Сырое"
        case .shortCircuit: return "Замыкание"
        case .searching: return "Поиск контакта…"
        }
    }
}

enum ConnectionState {
    case bluetoothOff, scanning, connecting, connected

    var title: String {
        switch self {
        case .bluetoothOff: return "Bluetooth выключен"
        case .scanning: return "Поиск влагомера…"
        case .connecting: return "Подключение…"
        case .connected: return "Подключено"
        }
    }
}

final class BLEManager: NSObject, ObservableObject {
    // UUID должны совпадать со скетчем
    private let serviceUUID = CBUUID(string: "6E400001-B5A3-F393-E0A9-E50E24DCCA9E")
    private let dataUUID    = CBUUID(string: "6E400003-B5A3-F393-E0A9-E50E24DCCA9E")
    private let woodUUID    = CBUUID(string: "6E400002-B5A3-F393-E0A9-E50E24DCCA9E")
    private let cmdUUID     = CBUUID(string: "6E400004-B5A3-F393-E0A9-E50E24DCCA9E")

    @Published var moisture: Double = 0
    @Published var temperature: Double = 20
    @Published var wood: Wood = .pine
    @Published var status: MoistureStatus = .idle
    @Published var hasResult = false
    @Published var isMeasuring = false
    @Published var supportsMeasure = false
    @Published var connection: ConnectionState = .scanning

    private var central: CBCentralManager!
    private var peripheral: CBPeripheral?
    private var woodChar: CBCharacteristic?
    private var cmdChar: CBCharacteristic?

    var canMeasure: Bool { connection == .connected && supportsMeasure && !isMeasuring }

    override init() {
        super.init()
        central = CBCentralManager(delegate: self, queue: .main)
    }

    func startScan() {
        guard central.state == .poweredOn else { return }
        connection = .scanning
        central.scanForPeripherals(withServices: [serviceUUID])
    }

    func selectWood(_ w: Wood) {
        wood = w
        guard let p = peripheral, let c = woodChar else { return }
        p.writeValue(Data([UInt8(w.rawValue)]), for: c, type: .withResponse)
    }

    /// Запускает замер на приборе (около 3 секунд, затем результат фиксируется)
    func startMeasurement() {
        guard let p = peripheral, let c = cmdChar else { return }
        isMeasuring = true // сразу показываем состояние; реальное придёт от прибора
        p.writeValue(Data([1]), for: c, type: .withResponse)
    }

    private func parse(_ data: Data) {
        guard let text = String(data: data, encoding: .utf8) else { return }
        let parts = text.split(separator: ",").map(String.init)
        guard parts.count >= 5,
              let m = Double(parts[0]), let t = Double(parts[1]),
              let w = Int(parts[2]), let s = Int(parts[3]), let r = Int(parts[4]) else { return }
        moisture = m
        temperature = t
        wood = Wood(rawValue: w) ?? .pine
        status = MoistureStatus(rawValue: s) ?? .idle
        hasResult = (r == 1)
        isMeasuring = parts.count >= 6 && parts[5] == "1"
    }
}

extension BLEManager: CBCentralManagerDelegate {
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        if central.state == .poweredOn { startScan() } else { connection = .bluetoothOff }
    }

    func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral,
                        advertisementData: [String: Any], rssi RSSI: NSNumber) {
        central.stopScan()
        self.peripheral = peripheral
        peripheral.delegate = self
        connection = .connecting
        central.connect(peripheral)
    }

    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        peripheral.discoverServices([serviceUUID])
    }

    func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        woodChar = nil
        cmdChar = nil
        supportsMeasure = false
        isMeasuring = false
        hasResult = false
        status = .idle
        self.peripheral = nil
        startScan()
    }

    func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Error?) {
        self.peripheral = nil
        startScan()
    }
}

extension BLEManager: CBPeripheralDelegate {
    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        guard let service = peripheral.services?.first(where: { $0.uuid == serviceUUID }) else { return }
        peripheral.discoverCharacteristics([dataUUID, woodUUID, cmdUUID], for: service)
    }

    func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        for c in service.characteristics ?? [] {
            if c.uuid == dataUUID { peripheral.setNotifyValue(true, for: c) }
            if c.uuid == woodUUID { woodChar = c }
            if c.uuid == cmdUUID { cmdChar = c; supportsMeasure = true }
        }
        connection = .connected
    }

    func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        if characteristic.uuid == dataUUID, let data = characteristic.value { parse(data) }
    }
}
