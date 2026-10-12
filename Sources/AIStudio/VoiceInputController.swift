import AVFoundation
import Combine
import Foundation
import Speech

@MainActor
final class VoiceInputController: ObservableObject {
    @Published private(set) var isRecording = false
    @Published private(set) var transcript = ""
    @Published var errorMessage: String?

    private let audioEngine = AVAudioEngine()
    private let speechRecognizer = SFSpeechRecognizer(locale: Locale.current) ?? SFSpeechRecognizer()
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private var tapInstalled = false

    func start() {
        guard !isRecording else { return }
        transcript = ""
        errorMessage = ""
        Task {
            let speechStatus = await withCheckedContinuation { continuation in
                SFSpeechRecognizer.requestAuthorization { status in
                    continuation.resume(returning: status)
                }
            }
            guard speechStatus == .authorized else {
                errorMessage = "Enable Speech Recognition for Supru App Builder in macOS Privacy & Security settings, then try again."
                return
            }

            let micGranted = await withCheckedContinuation { continuation in
                AVCaptureDevice.requestAccess(for: .audio) { granted in
                    continuation.resume(returning: granted)
                }
            }
            guard micGranted else {
                errorMessage = "Enable microphone access for Supru App Builder in macOS Privacy & Security settings, then try again."
                return
            }
            beginAudioRecognition()
        }
    }

    func stop() {
        guard isRecording else { return }
        isRecording = false
        if audioEngine.isRunning { audioEngine.stop() }
        if tapInstalled {
            audioEngine.inputNode.removeTap(onBus: 0)
            tapInstalled = false
        }
        recognitionRequest?.endAudio()
    }

    private func beginAudioRecognition() {
        guard let speechRecognizer, speechRecognizer.isAvailable else {
            errorMessage = "Speech recognition is currently unavailable. Check your connection and macOS speech settings."
            return
        }

        recognitionTask?.cancel()
        recognitionTask = nil
        let request = SFSpeechAudioBufferRecognitionRequest()
        request.shouldReportPartialResults = true
        recognitionRequest = request

        let inputNode = audioEngine.inputNode
        inputNode.removeTap(onBus: 0)
        let format = inputNode.outputFormat(forBus: 0)
        guard format.sampleRate > 0, format.channelCount > 0 else {
            errorMessage = "The selected microphone did not provide an audio format."
            return
        }

        inputNode.installTap(onBus: 0, bufferSize: 1024, format: format) { [weak request] buffer, _ in
            request?.append(buffer)
        }
        tapInstalled = true

        recognitionTask = speechRecognizer.recognitionTask(with: request) { [weak self] result, error in
            DispatchQueue.main.async {
                guard let self else { return }
                if let result {
                    self.transcript = result.bestTranscription.formattedString
                }
                if let error {
                    if self.isRecording {
                        self.errorMessage = "Voice input stopped: \(error.localizedDescription)"
                    }
                    self.isRecording = false
                    self.audioEngine.stop()
                    if self.tapInstalled {
                        self.audioEngine.inputNode.removeTap(onBus: 0)
                        self.tapInstalled = false
                    }
                    self.recognitionRequest = nil
                    self.recognitionTask = nil
                } else if result?.isFinal == true {
                    self.isRecording = false
                    self.audioEngine.stop()
                    if self.tapInstalled {
                        self.audioEngine.inputNode.removeTap(onBus: 0)
                        self.tapInstalled = false
                    }
                    self.recognitionRequest = nil
                    self.recognitionTask = nil
                }
            }
        }

        do {
            audioEngine.prepare()
            try audioEngine.start()
            isRecording = true
        } catch {
            if tapInstalled {
                inputNode.removeTap(onBus: 0)
                tapInstalled = false
            }
            recognitionRequest = nil
            recognitionTask?.cancel()
            recognitionTask = nil
            errorMessage = "Could not start voice input: \(error.localizedDescription)"
        }
    }
}
