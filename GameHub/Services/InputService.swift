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

struct InputSwitchPoint: Sendable {
    static let gamepadPolling: TimeInterval = 1.0 / 60.0
}

@MainActor
final class InputService: ObservableObject {
    @Published private(set) var connectedGamepads: [InputDeviceState] = []
    @Published private(set) var keyboardConnected = false
    @Published private(set) var mouseConnected = false

    var inputActionHandler: ((InputAction) -> Void)?
    var inputSwitchHappened: (() -> Void)?

    private var observedControllers: Set<ObjectIdentifier> = []

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
        inputSwitchHappened?()
    }

    private func handleControllerDisconnect(_ notification: Notification) {
        guard let controller = notification.object as? GCController else { return }
        observedControllers.remove(ObjectIdentifier(controller))
        connectedGamepads = GCController.controllers().map(makeDeviceState)
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

    func startRumble(strength: Double) {
        _ = strength
        _ = GCController.controllers()
    }

    func stopRumble() {
    }

    func refreshDeviceState() {
        connectedGamepads = GCController.controllers().map(makeDeviceState)
        keyboardConnected = connectedGamepads.contains(where: \.isKeyboard)
        mouseConnected = connectedGamepads.contains(where: \.isMouse)
    }
}
