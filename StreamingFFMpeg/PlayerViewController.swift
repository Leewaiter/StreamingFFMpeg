import UIKit
import KSPlayer
import Libavformat

// MARK: - PlayerViewController

class PlayerViewController: UIViewController {

    // MARK: - Constants
    private let historyKey = "FF_STREAM_HISTORY"
    private let maxHistory = 8

    // MediaMTX Control API
    private let mediaMTXBase = "http://27.105.113.156:9997"
    private let recordPathName = "cam_recv"
    private let liveRTSPURL = "rtsp://27.105.113.156:8555/cam_recv"

    // MARK: - Player & State
    private var player: MediaPlayerProtocol?
    private var connectionTimeoutTimer: Timer?
    private var controlsBottomConstraint: NSLayoutConstraint?
    private var isRecording = false
    private var isForwarding = false

    // 錄影計時器（用 Double 支援毫秒）
    private var recordingTimer: Timer?
    private var recordingElapsed: Double = 0.0

    // MARK: - UI
    private let videoContainerView: UIView = {
        let v = UIView()
        v.backgroundColor = .black
        v.translatesAutoresizingMaskIntoConstraints = false
        return v
    }()

    private let controlsPanel: UIView = {
        let v = UIView()
        v.backgroundColor = UIColor.black.withAlphaComponent(0.75)
        v.translatesAutoresizingMaskIntoConstraints = false
        return v
    }()

    private let recordingTimerLabel: UILabel = {
        let l = UILabel()
        l.text = "🔴 00:00.0"
        l.textColor = UIColor(red: 1.0, green: 0.3, blue: 0.3, alpha: 1.0)
        l.font = .monospacedDigitSystemFont(ofSize: 14, weight: .bold)
        l.backgroundColor = UIColor.black.withAlphaComponent(0.5)
        l.layer.cornerRadius = 6
        l.clipsToBounds = true
        l.textAlignment = .center
        l.isHidden = true
        l.translatesAutoresizingMaskIntoConstraints = false
        return l
    }()

    private let urlField: UITextField = {
        let tf = UITextField()
        tf.placeholder = "rtsp://..."
        tf.text = "rtsp://user:Wentai_12@192.168.2.196/stream2"
        tf.borderStyle = .roundedRect
        tf.backgroundColor = UIColor(white: 0.15, alpha: 1)
        tf.textColor = .white
        tf.font = UIFont.systemFont(ofSize: 14)
        tf.keyboardType = .default
        tf.autocapitalizationType = .none
        tf.autocorrectionType = .no
        tf.spellCheckingType = .no
        tf.smartQuotesType = .no
        tf.smartDashesType = .no
        tf.smartInsertDeleteType = .no
        tf.textContentType = .none
        tf.translatesAutoresizingMaskIntoConstraints = false
        return tf
    }()

    private let historyButton: UIButton = {
        let b = UIButton(type: .system)
        b.setImage(UIImage(systemName: "clock.arrow.circlepath"), for: .normal)
        b.tintColor = UIColor(red: 225/255.0, green: 200/255.0, blue: 170/255.0, alpha: 1.0)
        b.backgroundColor = UIColor(white: 0.2, alpha: 1)
        b.layer.cornerRadius = 8
        b.clipsToBounds = true
        b.translatesAutoresizingMaskIntoConstraints = false
        return b
    }()

    private let recordingButton: UIButton = {
        let b = UIButton(type: .system)
        b.setImage(UIImage(systemName: "play.rectangle"), for: .normal)
        b.tintColor = UIColor(red: 225/255.0, green: 200/255.0, blue: 170/255.0, alpha: 1.0)
        b.backgroundColor = UIColor(white: 0.2, alpha: 1)
        b.layer.cornerRadius = 8
        b.clipsToBounds = true
        b.translatesAutoresizingMaskIntoConstraints = false
        return b
    }()

    private let playButton: UIButton = {
        let b = UIButton(type: .system)
        b.setTitle("▶ 本機播放", for: .normal)
        b.titleLabel?.font = .systemFont(ofSize: 14, weight: .semibold)
        b.setBackgroundImage(UIImage(named: "bg001"), for: .normal)
        b.setTitleColor(.white, for: .normal)
        b.layer.cornerRadius = 8
        b.clipsToBounds = true
        b.translatesAutoresizingMaskIntoConstraints = false
        return b
    }()

    private let localRecordButton: UIButton = {
        let b = UIButton(type: .system)
        b.backgroundColor = UIColor(red: 0.85, green: 0.1, blue: 0.1, alpha: 1)
        b.layer.cornerRadius = 21
        b.clipsToBounds = true
        b.translatesAutoresizingMaskIntoConstraints = false
        b.layer.borderWidth = 3
        b.layer.borderColor = UIColor.white.cgColor
        return b
    }()

    private let recordHintLabel: UILabel = {
        let l = UILabel()
        l.text = "請先啟動轉發再錄影"
        l.textColor = UIColor(white: 0.5, alpha: 1)
        l.font = .systemFont(ofSize: 10)
        l.textAlignment = .center
        l.translatesAutoresizingMaskIntoConstraints = false
        return l
    }()

    private let stopButton: UIButton = {
        let b = UIButton(type: .system)
        b.setTitle("■ 本機停止", for: .normal)
        b.titleLabel?.font = .systemFont(ofSize: 14, weight: .semibold)
        b.setBackgroundImage(UIImage(named: "bg001"), for: .normal)
        b.setTitleColor(.white, for: .normal)
        b.layer.cornerRadius = 8
        b.clipsToBounds = true
        b.translatesAutoresizingMaskIntoConstraints = false
        return b
    }()

    private let startForwardButton: UIButton = {
        let b = UIButton(type: .system)
        b.setTitle("↹ 啟動轉發", for: .normal)
        b.titleLabel?.font = .systemFont(ofSize: 14, weight: .bold)
        b.setBackgroundImage(UIImage(named: "bg001"), for: .normal)
        b.setTitleColor(.white, for: .normal)
        b.tintColor = .white
        b.layer.cornerRadius = 8
        b.clipsToBounds = true
        b.translatesAutoresizingMaskIntoConstraints = false
        return b
    }()

    private let stopForwardButton: UIButton = {
        let b = UIButton(type: .system)
        b.setTitle("⏏ 停止轉發", for: .normal)
        b.titleLabel?.font = .systemFont(ofSize: 14, weight: .bold)
        b.setBackgroundImage(UIImage(named: "bg001"), for: .normal)
        b.setTitleColor(.white, for: .normal)
        b.tintColor = .white
        b.layer.cornerRadius = 8
        b.clipsToBounds = true
        b.translatesAutoresizingMaskIntoConstraints = false
        return b
    }()

    private let statusLabel: UILabel = {
        let l = UILabel()
        l.text = "待機"
        l.textColor = .lightGray
        l.font = .systemFont(ofSize: 12)
        l.textAlignment = .center
        l.translatesAutoresizingMaskIntoConstraints = false
        return l
    }()

    private let forwardLogView: UILabel = {
        let l = UILabel()
        l.text = ""
        l.textColor = UIColor(red: 0.2, green: 1.0, blue: 0.5, alpha: 1)
        l.font = .monospacedSystemFont(ofSize: 9, weight: .regular)
        l.numberOfLines = 5
        l.backgroundColor = UIColor.black.withAlphaComponent(0.75)
        l.layer.cornerRadius = 6
        l.clipsToBounds = true
        l.isHidden = true
        l.translatesAutoresizingMaskIntoConstraints = false
        return l
    }()

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black
        setupLayout()
        setupActions()
        updateRecordButtonState()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        let lightGold = UIColor(red: 225/255.0, green: 200/255.0, blue: 170/255.0, alpha: 1.0)
        let gradientColors = [lightGold, lightGold, lightGold]
        statusLabel.setGradientTextColor(colors: gradientColors)
        playButton.setGradientTitleColor(colors: gradientColors, for: .normal)
        stopButton.setGradientTitleColor(colors: gradientColors, for: .normal)
        startForwardButton.setGradientTitleColor(colors: gradientColors, for: .normal)
        stopForwardButton.setGradientTitleColor(colors: gradientColors, for: .normal)
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        navigationController?.setNavigationBarHidden(true, animated: animated)
    }

    // MARK: - Layout

    private func setupLayout() {
        view.addSubview(videoContainerView)
        view.addSubview(controlsPanel)
        view.addSubview(forwardLogView)
        view.addSubview(recordingTimerLabel)

        controlsPanel.addSubview(urlField)
        controlsPanel.addSubview(historyButton)
        controlsPanel.addSubview(recordingButton)
        controlsPanel.addSubview(playButton)
        controlsPanel.addSubview(localRecordButton)
        controlsPanel.addSubview(recordHintLabel)
        controlsPanel.addSubview(stopButton)
        controlsPanel.addSubview(startForwardButton)
        controlsPanel.addSubview(stopForwardButton)
        controlsPanel.addSubview(statusLabel)

        let bottomConst = controlsPanel.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        self.controlsBottomConstraint = bottomConst

        NSLayoutConstraint.activate([
            videoContainerView.topAnchor.constraint(equalTo: view.topAnchor),
            videoContainerView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            videoContainerView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            videoContainerView.bottomAnchor.constraint(equalTo: controlsPanel.topAnchor),

            controlsPanel.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            controlsPanel.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            bottomConst,
            controlsPanel.heightAnchor.constraint(equalToConstant: 235),

            urlField.topAnchor.constraint(equalTo: controlsPanel.topAnchor, constant: 12),
            urlField.leadingAnchor.constraint(equalTo: controlsPanel.leadingAnchor, constant: 16),
            urlField.trailingAnchor.constraint(equalTo: historyButton.leadingAnchor, constant: -6),
            urlField.heightAnchor.constraint(equalToConstant: 36),

            historyButton.centerYAnchor.constraint(equalTo: urlField.centerYAnchor),
            historyButton.trailingAnchor.constraint(equalTo: recordingButton.leadingAnchor, constant: -6),
            historyButton.widthAnchor.constraint(equalToConstant: 40),
            historyButton.heightAnchor.constraint(equalToConstant: 36),

            recordingButton.centerYAnchor.constraint(equalTo: urlField.centerYAnchor),
            recordingButton.trailingAnchor.constraint(equalTo: controlsPanel.trailingAnchor, constant: -16),
            recordingButton.widthAnchor.constraint(equalToConstant: 40),
            recordingButton.heightAnchor.constraint(equalToConstant: 36),

            playButton.topAnchor.constraint(equalTo: urlField.bottomAnchor, constant: 10),
            playButton.leadingAnchor.constraint(equalTo: controlsPanel.leadingAnchor, constant: 16),
            playButton.trailingAnchor.constraint(equalTo: localRecordButton.leadingAnchor, constant: -10),
            playButton.heightAnchor.constraint(equalToConstant: 42),

            localRecordButton.topAnchor.constraint(equalTo: urlField.bottomAnchor, constant: 10),
            localRecordButton.centerXAnchor.constraint(equalTo: controlsPanel.centerXAnchor),
            localRecordButton.widthAnchor.constraint(equalToConstant: 42),
            localRecordButton.heightAnchor.constraint(equalToConstant: 42),

            stopButton.topAnchor.constraint(equalTo: urlField.bottomAnchor, constant: 10),
            stopButton.leadingAnchor.constraint(equalTo: localRecordButton.trailingAnchor, constant: 10),
            stopButton.trailingAnchor.constraint(equalTo: controlsPanel.trailingAnchor, constant: -16),
            stopButton.heightAnchor.constraint(equalToConstant: 42),
            stopButton.widthAnchor.constraint(equalTo: playButton.widthAnchor),

            recordHintLabel.topAnchor.constraint(equalTo: localRecordButton.bottomAnchor, constant: 4),
            recordHintLabel.centerXAnchor.constraint(equalTo: localRecordButton.centerXAnchor),
            recordHintLabel.widthAnchor.constraint(equalToConstant: 120),

            startForwardButton.topAnchor.constraint(equalTo: localRecordButton.bottomAnchor, constant: 22),
            startForwardButton.leadingAnchor.constraint(equalTo: controlsPanel.leadingAnchor, constant: 16),
            startForwardButton.widthAnchor.constraint(equalTo: controlsPanel.widthAnchor, multiplier: 0.45, constant: -16),
            startForwardButton.heightAnchor.constraint(equalToConstant: 42),

            stopForwardButton.topAnchor.constraint(equalTo: startForwardButton.topAnchor),
            stopForwardButton.trailingAnchor.constraint(equalTo: controlsPanel.trailingAnchor, constant: -16),
            stopForwardButton.widthAnchor.constraint(equalTo: startForwardButton.widthAnchor),
            stopForwardButton.heightAnchor.constraint(equalToConstant: 42),

            statusLabel.topAnchor.constraint(equalTo: startForwardButton.bottomAnchor, constant: 8),
            statusLabel.leadingAnchor.constraint(equalTo: controlsPanel.leadingAnchor, constant: 16),
            statusLabel.trailingAnchor.constraint(equalTo: controlsPanel.trailingAnchor, constant: -16),

            forwardLogView.leadingAnchor.constraint(equalTo: videoContainerView.leadingAnchor, constant: 6),
            forwardLogView.bottomAnchor.constraint(equalTo: videoContainerView.bottomAnchor, constant: -6),
            forwardLogView.trailingAnchor.constraint(lessThanOrEqualTo: videoContainerView.trailingAnchor, constant: -6),

            recordingTimerLabel.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 12),
            recordingTimerLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 12),
            recordingTimerLabel.heightAnchor.constraint(equalToConstant: 28),
            recordingTimerLabel.widthAnchor.constraint(greaterThanOrEqualToConstant: 110),
        ])
    }

    // MARK: - Actions

    private func setupActions() {
        playButton.addTarget(self, action: #selector(onPlay), for: .touchUpInside)
        stopButton.addTarget(self, action: #selector(onStop), for: .touchUpInside)
        startForwardButton.addTarget(self, action: #selector(onStartForward), for: .touchUpInside)
        stopForwardButton.addTarget(self, action: #selector(onStopForward), for: .touchUpInside)
        historyButton.addTarget(self, action: #selector(onShowHistory), for: .touchUpInside)
        recordingButton.addTarget(self, action: #selector(onShowRecordings), for: .touchUpInside)
        localRecordButton.addTarget(self, action: #selector(onToggleRecord), for: .touchUpInside)

        let tap = UITapGestureRecognizer(target: self, action: #selector(dismissKeyboard))
        view.addGestureRecognizer(tap)

        NotificationCenter.default.addObserver(self, selector: #selector(keyboardWillShow),
                                               name: UIResponder.keyboardWillShowNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(keyboardWillHide),
                                               name: UIResponder.keyboardWillHideNotification, object: nil)
    }

    @objc private func onShowRecordings() {
        let vc = RecordingListViewController()
        navigationController?.pushViewController(vc, animated: true)
        vc.navigationController?.setNavigationBarHidden(false, animated: false)
    }

    @objc private func dismissKeyboard() { view.endEditing(true) }

    // MARK: - Keyboard

    @objc private func keyboardWillShow(notification: NSNotification) {
        if let frame = notification.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect {
            controlsBottomConstraint?.constant = -frame.height
            UIView.animate(withDuration: 0.3) { self.view.layoutIfNeeded() }
        }
    }

    @objc private func keyboardWillHide(notification: NSNotification) {
        controlsBottomConstraint?.constant = 0
        UIView.animate(withDuration: 0.3) { self.view.layoutIfNeeded() }
    }

    // MARK: - 歷史紀錄

    private func loadHistory() -> [String] {
        return UserDefaults.standard.stringArray(forKey: historyKey) ?? []
    }

    private func saveToHistory(_ urlString: String) {
        guard !urlString.isEmpty else { return }
        var history = loadHistory()
        history.removeAll { $0 == urlString }
        history.insert(urlString, at: 0)
        if history.count > maxHistory { history = Array(history.prefix(maxHistory)) }
        UserDefaults.standard.set(history, forKey: historyKey)
    }

    @objc private func onShowHistory() {
        let history = loadHistory()
        if history.isEmpty { showToast("尚無歷史紀錄"); return }
        let alert = UIAlertController(title: "歷史紀錄", message: "點選後填入輸入欄", preferredStyle: .actionSheet)
        for url in history {
            let displayText = url.count > 50 ? String(url.prefix(50)) + "…" : url
            alert.addAction(UIAlertAction(title: displayText, style: .default) { [weak self] _ in
                self?.urlField.text = url
            })
        }
        alert.addAction(UIAlertAction(title: "🗑 清除全部歷史", style: .destructive) { [weak self] _ in
            UserDefaults.standard.removeObject(forKey: self?.historyKey ?? "")
            self?.showToast("歷史紀錄已清除")
        })
        alert.addAction(UIAlertAction(title: "取消", style: .cancel))
        if let popover = alert.popoverPresentationController {
            popover.sourceView = historyButton
            popover.sourceRect = historyButton.bounds
        }
        present(alert, animated: true)
    }

    // MARK: - Play / Stop

    @objc private func onPlay() {
        let urlString = urlField.text?.trimmingCharacters(in: .whitespaces) ?? ""
        guard !urlString.isEmpty, let url = URL(string: urlString) else {
            setStatus("❌ 請輸入有效的 RTSP 網址"); return
        }
        saveToHistory(urlString)
        stopPlayer()
        setStatus("連線中...")
        startPlayer(url: url)
    }

    @objc private func onStop() {
        if isRecording { stopServerRecording() }
        stopPlayer()
        setStatus("△ 已停止")
    }

    // MARK: - 錄影按鈕狀態管理

    private func updateRecordButtonState() {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            if self.isForwarding {
                self.localRecordButton.isEnabled = true
                self.localRecordButton.alpha = 1.0
                self.recordHintLabel.isHidden = true
            } else {
                self.localRecordButton.isEnabled = false
                self.localRecordButton.alpha = 0.35
                self.recordHintLabel.isHidden = false
                self.recordHintLabel.text = "請先啟動轉發再錄影"
            }
        }
    }

    // MARK: - Server 端錄影控制

    @objc private func onToggleRecord() {
        if isRecording { stopServerRecording() } else { startServerRecording() }
    }

    private func startServerRecording() {
        guard let url = URL(string: "\(mediaMTXBase)/v3/config/paths/patch/\(recordPathName)") else { return }
        var request = URLRequest(url: url)
        request.httpMethod = "PATCH"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try? JSONSerialization.data(withJSONObject: ["record": true])

        setStatus("⏳ 啟動錄影中...")
        URLSession.shared.dataTask(with: request) { [weak self] _, response, error in
            DispatchQueue.main.async {
                guard let self = self else { return }
                let code = (response as? HTTPURLResponse)?.statusCode ?? 0
                if error == nil && (200...299).contains(code) {
                    self.isRecording = true
                    self.updateRecordButton()
                    self.setStatus("🔴 錄影中...")
                    self.showToast("錄影已開始")
                    self.startRecordingTimer()
                    self.startLivePlayback()
                } else {
                    self.setStatus("❌ 啟動錄影失敗")
                    self.showToast("啟動錄影失敗：\(error?.localizedDescription ?? "HTTP \(code)")")
                }
            }
        }.resume()
    }

    private func stopServerRecording() {
        guard let url = URL(string: "\(mediaMTXBase)/v3/config/paths/patch/\(recordPathName)") else { return }
        var request = URLRequest(url: url)
        request.httpMethod = "PATCH"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try? JSONSerialization.data(withJSONObject: ["record": false])

        URLSession.shared.dataTask(with: request) { [weak self] _, response, error in
            DispatchQueue.main.async {
                guard let self = self else { return }
                let code = (response as? HTTPURLResponse)?.statusCode ?? 0
                if error == nil && (200...299).contains(code) {
                    self.isRecording = false
                    self.updateRecordButton()
                    self.setStatus("⏹ Server 錄影已停止")
                    self.showToast("錄影已儲存在 Server")
                    self.stopRecordingTimer()
                    self.stopPlayer()
                } else {
                    self.setStatus("❌ 停止錄影失敗")
                    self.showToast("停止錄影失敗：\(error?.localizedDescription ?? "HTTP \(code)")")
                }
            }
        }.resume()
    }

    private func updateRecordButton() {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            if self.isRecording {
                UIView.animate(withDuration: 0.2) {
                    self.localRecordButton.transform = CGAffineTransform(scaleX: 0.7, y: 0.7)
                    self.localRecordButton.layer.cornerRadius = 6
                    self.localRecordButton.backgroundColor = UIColor(red: 0.85, green: 0.1, blue: 0.1, alpha: 1)
                }
                self.recordHintLabel.text = "錄影中，再按一次停止"
                self.recordHintLabel.isHidden = false
            } else {
                UIView.animate(withDuration: 0.2) {
                    self.localRecordButton.transform = .identity
                    self.localRecordButton.layer.cornerRadius = 21
                    self.localRecordButton.backgroundColor = UIColor(red: 0.85, green: 0.1, blue: 0.1, alpha: 1)
                }
                self.recordHintLabel.text = "請先啟動轉發再錄影"
                self.recordHintLabel.isHidden = self.isForwarding
            }
        }
    }

    // MARK: - 錄影計時器（顯示到 0.1 秒）

    private func startRecordingTimer() {
        recordingElapsed = 0.0
        recordingTimerLabel.isHidden = false
        updateRecordingTimerLabel()
        // ✅ 每 0.1 秒更新一次，顯示到毫秒
        recordingTimer = Timer.scheduledTimer(withTimeInterval: 0.01, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            self.recordingElapsed += 0.01
            self.updateRecordingTimerLabel()
        }
    }

    private func stopRecordingTimer() {
        recordingTimer?.invalidate()
        recordingTimer = nil
        recordingElapsed = 0.0
        recordingTimerLabel.isHidden = true
    }

    private func updateRecordingTimerLabel() {
        let total = recordingElapsed
        let h  = Int(total) / 3600
        let m  = (Int(total) % 3600) / 60
        let s  = Int(total) % 60
        let ds = Int(total * 100) % 100   // 0.01 秒精度（兩位小數）
        if h > 0 {
            recordingTimerLabel.text = String(format: " 🔴 %d:%02d:%02d.%02d ", h, m, s, ds)
        } else {
            recordingTimerLabel.text = String(format: " 🔴 %02d:%02d.%02d ", m, s, ds)
        }
    }

    // MARK: - 錄影時同時播放 cam_recv

    private func startLivePlayback() {
        guard let url = URL(string: liveRTSPURL) else { return }
        stopPlayer()
        startPlayer(url: url)
    }

    // MARK: - Player

    private func startPlayer(url: URL) {
        let options = KSOptions()
        options.formatContextOptions["rtsp_transport"]  = "tcp"
        options.formatContextOptions["stimeout"]        = "5000000"
        options.formatContextOptions["rw_timeout"]      = "5000000"
        options.formatContextOptions["analyzeduration"] = "2000000"
        options.formatContextOptions["probesize"]       = "2048000"
        options.decoderOptions["threads"]               = "auto"

        let p = KSMEPlayer(url: url, options: options)
        p.delegate = self
        player = p

        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            if let pView = p.view {
                pView.translatesAutoresizingMaskIntoConstraints = false
                self.videoContainerView.addSubview(pView)
                self.view.bringSubviewToFront(self.recordingTimerLabel)
                NSLayoutConstraint.activate([
                    pView.topAnchor.constraint(equalTo: self.videoContainerView.topAnchor),
                    pView.leadingAnchor.constraint(equalTo: self.videoContainerView.leadingAnchor),
                    pView.trailingAnchor.constraint(equalTo: self.videoContainerView.trailingAnchor),
                    pView.bottomAnchor.constraint(equalTo: self.videoContainerView.bottomAnchor),
                ])
            }
            p.prepareToPlay()
            p.play()
        }

        connectionTimeoutTimer?.invalidate()
        connectionTimeoutTimer = Timer.scheduledTimer(withTimeInterval: 15, repeats: false) { [weak self] _ in
            guard let self = self else { return }
            if self.player?.isPlaying == false {
                self.setStatus("⏱ 連線逾時")
                self.stopPlayer()
            }
        }
    }

    private func stopPlayer() {
        connectionTimeoutTimer?.invalidate()
        connectionTimeoutTimer = nil
        player?.pause()
        player?.view?.removeFromSuperview()
        player = nil
    }

    private func setStatus(_ text: String) {
        DispatchQueue.main.async { self.statusLabel.text = text }
    }

    // MARK: - Forward

    private func appendForwardLog(_ message: String) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.forwardLogView.isHidden = false
            let formatter = DateFormatter()
            formatter.dateFormat = "HH:mm:ss"
            let newLine = "[\(formatter.string(from: Date()))] \(message)"
            let current = self.forwardLogView.text ?? ""
            var lines = current.components(separatedBy: "\n").filter { !$0.isEmpty }
            lines.append(newLine)
            if lines.count > 5 { lines.removeFirst(lines.count - 5) }
            self.forwardLogView.text = lines.joined(separator: "\n")
        }
    }

    @objc private func onStartForward() {
        let urlString = urlField.text?.trimmingCharacters(in: .whitespaces) ?? ""
        guard !urlString.isEmpty else { showToast("請先輸入來源 RTSP 網址"); return }
        saveToHistory(urlString)
        appendForwardLog("傳送啟動指令至伺服器...")
        RTSPCommandSender.sendForwardCommand(sourceURL: urlString) { [weak self] success, message in
            DispatchQueue.main.async {
                self?.appendForwardLog(message)
                if success {
                    self?.isForwarding = true
                    self?.updateRecordButtonState()
                }
            }
        }
    }

    @objc private func onStopForward() {
        appendForwardLog("傳送停止指令至伺服器...")
        if isRecording { stopServerRecording() }
        RTSPCommandSender.sendStopCommand { [weak self] success, message in
            DispatchQueue.main.async {
                self?.appendForwardLog(message)
                if success {
                    self?.isForwarding = false
                    self?.updateRecordButtonState()
                }
            }
        }
    }

    // MARK: - Toast

    private func showToast(_ message: String) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            let toast = UILabel()
            toast.text = " \(message) "
            toast.textColor = .white
            toast.font = .systemFont(ofSize: 13)
            toast.backgroundColor = UIColor(red: 0.7, green: 0.1, blue: 0.1, alpha: 0.9)
            toast.textAlignment = .center
            toast.numberOfLines = 3
            toast.layer.cornerRadius = 8
            toast.clipsToBounds = true
            toast.alpha = 0
            toast.translatesAutoresizingMaskIntoConstraints = false
            self.view.addSubview(toast)
            NSLayoutConstraint.activate([
                toast.centerXAnchor.constraint(equalTo: self.view.centerXAnchor),
                toast.centerYAnchor.constraint(equalTo: self.view.centerYAnchor),
                toast.leadingAnchor.constraint(greaterThanOrEqualTo: self.view.leadingAnchor, constant: 24),
                toast.trailingAnchor.constraint(lessThanOrEqualTo: self.view.trailingAnchor, constant: -24),
            ])
            UIView.animate(withDuration: 0.3) { toast.alpha = 1 }
            DispatchQueue.main.asyncAfter(deadline: .now() + 3.5) {
                UIView.animate(withDuration: 0.3, animations: { toast.alpha = 0 }) { _ in toast.removeFromSuperview() }
            }
        }
    }
}

// MARK: - MediaPlayerDelegate

extension PlayerViewController: MediaPlayerDelegate {
    func readyToPlay(player: some MediaPlayerProtocol) {
        DispatchQueue.main.async { [weak self] in
            self?.connectionTimeoutTimer?.invalidate()
            self?.setStatus(self?.isRecording == true ? "🔴 錄影中..." : "等待播放")
        }
    }

    func changeLoadState(player: some MediaPlayerProtocol) {
        DispatchQueue.main.async { [weak self] in
            if case .playable = player.loadState {
                self?.setStatus(self?.isRecording == true ? "🔴 錄影中..." : "等待播放")
            }
        }
    }

    func changeBuffering(player: some MediaPlayerProtocol, progress: Int) {
        DispatchQueue.main.async { [weak self] in self?.setStatus("⏳ 緩衝中 \(progress)%") }
    }

    func playBack(player: some MediaPlayerProtocol, loopCount: Int) {}

    func finish(player: some MediaPlayerProtocol, error: Error?) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            if self.isRecording { self.stopServerRecording() }
            self.setStatus(error != nil ? "❌ 錯誤: \(error!.localizedDescription)" : "⏹ 播放結束")
        }
    }
}

// MARK: - UILabel 漸層文字

extension UILabel {
    func setGradientTextColor(colors: [UIColor]) {
        self.layoutIfNeeded()
        let layer = CAGradientLayer()
        layer.frame = self.bounds
        layer.colors = colors.map { $0.cgColor }
        layer.startPoint = CGPoint(x: 0.5, y: 0.0)
        layer.endPoint   = CGPoint(x: 0.5, y: 1.0)
        UIGraphicsBeginImageContextWithOptions(self.bounds.size, false, 0.0)
        if let ctx = UIGraphicsGetCurrentContext() {
            layer.render(in: ctx)
            if let image = UIGraphicsGetImageFromCurrentImageContext() {
                self.textColor = UIColor(patternImage: image)
            }
        }
        UIGraphicsEndImageContext()
    }
}

// MARK: - UIButton 漸層文字

extension UIButton {
    func setGradientTitleColor(colors: [UIColor], for state: UIControl.State) {
        self.layoutIfNeeded()
        guard let titleLabel = self.titleLabel, titleLabel.bounds.width > 0 else { return }
        let layer = CAGradientLayer()
        layer.frame = titleLabel.bounds
        layer.colors = colors.map { $0.cgColor }
        layer.startPoint = CGPoint(x: 0.5, y: 0.0)
        layer.endPoint   = CGPoint(x: 0.5, y: 1.0)
        UIGraphicsBeginImageContextWithOptions(titleLabel.bounds.size, false, 0.0)
        defer { UIGraphicsEndImageContext() }
        if let ctx = UIGraphicsGetCurrentContext() {
            layer.render(in: ctx)
            if let image = UIGraphicsGetImageFromCurrentImageContext() {
                self.setTitleColor(UIColor(patternImage: image), for: state)
            }
        }
    }
}
