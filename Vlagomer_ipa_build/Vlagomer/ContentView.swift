import SwiftUI

struct ContentView: View {
    @EnvironmentObject var ble: BLEManager

    private var statusColor: Color {
        guard ble.hasResult else { return .gray }
        switch ble.status {
        case .dry: return .green
        case .airDry: return .orange
        case .wet, .shortCircuit: return .red
        default: return .gray
        }
    }

    var body: some View {
        VStack(spacing: 24) {
            // Состояние подключения
            HStack(spacing: 8) {
                Circle()
                    .fill(ble.connection == .connected ? Color.green : Color.orange)
                    .frame(width: 10, height: 10)
                Text(ble.connection.title)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Spacer()
                if ble.connection != .connected {
                    Button("Повторить") { ble.startScan() }
                        .font(.subheadline)
                }
            }

            // Влажность
            VStack(spacing: 4) {
                Text("ВЛАЖНОСТЬ")
                    .font(.caption).tracking(2)
                    .foregroundStyle(.secondary)
                Text(ble.hasResult && ble.status != .searching
                     ? String(format: "%.1f", ble.moisture) : "--.-")
                    .font(.system(size: 88, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .minimumScaleFactor(0.5)
                Text("%").font(.title2).foregroundStyle(.secondary)

                ProgressView(value: min(max((ble.moisture - 7) / 28, 0), 1))
                    .tint(statusColor)
                    .opacity(ble.hasResult ? 1 : 0.2)
                    .padding(.top, 8)
            }
            .padding(20)
            .frame(maxWidth: .infinity)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 24))

            // Статус
            Text(ble.hasResult ? ble.status.title : MoistureStatus.idle.title)
                .font(.headline)
                .padding(.horizontal, 16).padding(.vertical, 8)
                .background(statusColor.opacity(0.18), in: Capsule())
                .foregroundStyle(statusColor)

            // Кнопка замера
            VStack(spacing: 6) {
                Button {
                    ble.startMeasurement()
                } label: {
                    HStack(spacing: 10) {
                        if ble.isMeasuring { ProgressView().tint(.white) }
                        Text(ble.isMeasuring ? "Идёт замер…" : "Замерить")
                    }
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                }
                .buttonStyle(.borderedProminent)
                .disabled(!ble.canMeasure)

                if ble.connection == .connected && !ble.supportsMeasure {
                    Text("Для кнопки замера обновите прошивку прибора")
                        .font(.caption).foregroundStyle(.secondary)
                }
            }

            // Температура
            HStack {
                Image(systemName: "thermometer.medium")
                    .font(.title2).foregroundStyle(.red)
                VStack(alignment: .leading) {
                    Text("Температура древесины")
                        .font(.caption).foregroundStyle(.secondary)
                    Text(ble.temperature < -100 ? "нет датчика" : String(format: "%.1f °C", ble.temperature))
                        .font(.title2.weight(.semibold)).monospacedDigit()
                }
                Spacer()
            }
            .padding(16)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 20))

            // Порода
            VStack(alignment: .leading, spacing: 8) {
                Text("Порода дерева")
                    .font(.caption).foregroundStyle(.secondary)
                Picker("Порода", selection: Binding(
                    get: { ble.wood },
                    set: { ble.selectWood($0) })) {
                    ForEach(Wood.allCases) { Text($0.title).tag($0) }
                }
                .pickerStyle(.segmented)
                .disabled(ble.connection != .connected)
            }

            Spacer()
        }
        .padding(20)
    }
}

#Preview {
    ContentView().environmentObject(BLEManager())
}
