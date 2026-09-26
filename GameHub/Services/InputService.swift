import Foundation
import GameController
import Combine

struct InputDeviceState: Sendable {
    let connected: Bool
    let name: String?
    let isGamepad: Bool
    let isKeyboard: Bool
    let isMouse: Bool
}

enum InputAction: Sendable {
    case buttonPressed(button: VirtualButton)
    case analogChanged(axis: VirtualAxis, value: Double)
}

enum VirtualButton: String, Sendable {
    case faceButtonA
    case faceButtonB
    case faceButtonX
    case faceButtonY
    case leftShoulder
    case rightShoulder
    case dpadUp
    case dpadDown
    case dpadLeft
    case dpadRight
    case start
    case select
}

enum VirtualAxis: String, Sendable {
    case leftStickX
    case leftStickY
    case rightStickX
    case rightStickY
    case leftTrigger
    case rightTrigger
}

@MainActor
final class InputService: ObservableObject {
    @Published private(set) var connectedGamepads: [InputDeviceState] = []
    @Published private(set) var keyboardConnected = false
    @Published private(set) var mouseConnected = false

    var inputActionHandler: ((InputAction) -> Void)?
    var inputSwitchHappened: (() -> Void)?

    private var observedControllers: Set<ObjectIdentifier> = []
    private let sampleQueue = DispatchQueue(label: "gamehub.gamepad", qos: .userInteractive)

    init() {
        observeControllerConnections()
    }

    private func observeControllerConnections() {
        NotificationCenter.default.addObserver(
            forName: .GCControllerDidConnect,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            self?.handleControllerConnect(notification)
        }

        NotificationCenter.default.addObserver(
            forName: .GCControllerDidDisconnect,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            self?.handleControllerDisconnect(notification)
        }

        for controller in GCController.controllers() {
            handleControllerConnect(Notification(name: .GCControllerDidConnect, object: controller))
        }
    }

    private func handleControllerConnect(_ notification: Notification) {
        guard let controller = notification.object as? GCController else { return }
        observedControllers.insert(ObjectIdentifier(controller))
        connectedGamepads = GCController.controllers().map(makeDeviceState)
        configureExtendedGamepad(controller)
        publishXInputSnapshots()
        inputSwitchHappened?()
    }

    private func handleControllerDisconnect(_ notification: Notification) {
        guard let controller = notification.object as? GCController else { return }
        observedControllers.remove(ObjectIdentifier(controller))
        connectedGamepads = GCController.controllers().map(makeDeviceState)
        publishXInputSnapshots()
        inputSwitchHappened?()
    }

    private func makeDeviceState(_ controller: GCController) -> InputDeviceState {
        InputDeviceState(
            connected: true,
            name: controller.vendorName,
            isGamepad: controller.extendedGamepad != nil,
            isKeyboard: GCKeyboard.coalesced != nil,
            isMouse: GCMouse.current != nil
        )
    }

    private func configureExtendedGamepad(_ controller: GCController) {
        guard let gamepad = controller.extendedGamepad else { return }
        controller.handlerQueue = sampleQueue

        gamepad.valueChangedHandler = { [weak self] _, _ in
            self?.publishXInputSnapshots()
        }

        gamepad.buttonA.pressedChangedHandler = { [weak self] _, _, pressed in
            guard pressed else { return }
            self?.emit(.buttonPressed(button: .faceButtonA))
        }
        gamepad.buttonB.pressedChangedHandler = { [weak self] _, _, pressed in
            guard pressed else { return }
            self?.emit(.buttonPressed(button: .faceButtonB))
        }
        gamepad.buttonX.pressedChangedHandler = { [weak self] _, _, pressed in
            guard pressed else { return }
            self?.emit(.buttonPressed(button: .faceButtonX))
        }
        gamepad.buttonY.pressedChangedHandler = { [weak self] _, _, pressed in
            guard pressed else { return }
            self?.emit(.buttonPressed(button: .faceButtonY))
        }
        gamepad.leftShoulder.pressedChangedHandler = { [weak self] _, _, pressed in
            guard pressed else { return }
            self?.emit(.buttonPressed(button: .leftShoulder))
        }
        gamepad.rightShoulder.pressedChangedHandler = { [weak self] _, _, pressed in
            guard pressed else { return }
            self?.emit(.buttonPressed(button: .rightShoulder))
        }
        gamepad.dpad.up.pressedChangedHandler = { [weak self] _, _, pressed in
            guard pressed else { return }
            self?.emit(.buttonPressed(button: .dpadUp))
        }
        gamepad.dpad.down.pressedChangedHandler = { [weak self] _, _, pressed in
            guard pressed else { return }
            self?.emit(.buttonPressed(button: .dpadDown))
        }
        gamepad.dpad.left.pressedChangedHandler = { [weak self] _, _, pressed in
            guard pressed else { return }
            self?.emit(.buttonPressed(button: .dpadLeft))
        }
        gamepad.dpad.right.pressedChangedHandler = { [weak self] _, _, pressed in
            guard pressed else { return }
            self?.emit(.buttonPressed(button: .dpadRight))
        }

        gamepad.leftThumbstick.valueChangedHandler = { [weak self] _, x, y in
            self?.emit(.analogChanged(axis: .leftStickX, value: Double(x)))
            self?.emit(.analogChanged(axis: .leftStickY, value: Double(y)))
        }
        gamepad.rightThumbstick.valueChangedHandler = { [weak self] _, x, y in
            self?.emit(.analogChanged(axis: .rightStickX, value: Double(x)))
            self?.emit(.analogChanged(axis: .rightStickY, value: Double(y)))
        }
        gamepad.leftTrigger.valueChangedHandler = { [weak self] _, value, _ in
            self?.emit(.analogChanged(axis: .leftTrigger, value: Double(value)))
        }
        gamepad.rightTrigger.valueChangedHandler = { [weak self] _, value, _ in
            self?.emit(.analogChanged(axis: .rightTrigger, value: Double(value)))
        }
    }

    private func emit(_ action: InputAction) {
        inputActionHandler?(action)
    }

    /// Publish Madeira XInput snapshots so win32u can poll winios_gamepad_get_state.
    func publishXInputSnapshots() {
        let pads = GCController.controllers().compactMap { $0.extendedGamepad }
        sampleQueue.async {
            for i in 0..<Int(WINIOS_GAMEPAD_MAX) {
                if i < pads.count, let pad = Optional(pads[i]) {
                    var state = winios_gamepad()
                    state.connected = 1
                    let buttons: [(GCControllerButtonInput?, UInt16)] = [
                        (pad.dpad.up, 0x0001), (pad.dpad.down, 0x0002),
                        (pad.dpad.left, 0x0004), (pad.dpad.right, 0x0008),
                        (pad.buttonMenu, 0x0010), (pad.buttonOptions, 0x0020),
                        (pad.leftThumbstickButton, 0x0040), (pad.rightThumbstickButton, 0x0080),
                        (pad.leftShoulder, 0x0100), (pad.rightShoulder, 0x0200),
                        (pad.buttonHome, 0x0400), (pad.buttonA, 0x1000),
                        (pad.buttonB, 0x2000), (pad.buttonX, 0x4000), (pad.buttonY, 0x8000)
                    ]
                    for (button, mask) in buttons where button?.isPressed == true {
                        state.buttons |= mask
                    }
                    state.left_trigger = Self.trigger(pad.leftTrigger.value)
                    state.right_trigger = Self.trigger(pad.rightTrigger.value)
                    state.lx = Self.axis(pad.leftThumbstick.xAxis.value)
                    state.ly = Self.axis(pad.leftThumbstick.yAxis.value)
                    state.rx = Self.axis(pad.rightThumbstick.xAxis.value)
                    state.ry = Self.axis(pad.rightThumbstick.yAxis.value)
                    winios_gamepad_set_state(Int32(i), &state)
                } else {
                    winios_gamepad_set_state(Int32(i), nil)
                }
            }
        }
    }

    private static func axis(_ value: Float) -> Int16 {
        guard value.isFinite else { return 0 }
        let clamped = max(-1, min(1, value))
        return Int16((clamped * (clamped < 0 ? 32768 : 32767)).rounded())
    }

    private static func trigger(_ value: Float) -> UInt8 {
        guard value.isFinite else { return 0 }
        return UInt8((max(0, min(1, value)) * 255).rounded())
    }

    func startRumble(strength: Double) {
        _ = strength
        _ = GCController.controllers()
    }

    func stopRumble() {}

    func refreshDeviceState() {
        connectedGamepads = GCController.controllers().map(makeDeviceState)
        keyboardConnected = connectedGamepads.contains(where: \.isKeyboard)
        mouseConnected = connectedGamepads.contains(where: \.isMouse)
        publishXInputSnapshots()
    }
}
