import UIKit
import KSPlayer

class RecordingPlayerViewController: UIViewController {

    private let videoURL: URL
    private let videoTitle: String
    private let knownDuration: TimeInterval
    private var player: MediaPlayerProtocol?
    private var timeObserverTimer: Timer?
    private var isSeeking = false

    private let videoContainerView: UIView = {
        let v = UIView()
        v.backgroundColor = .black
        v.translatesAutoresizingMaskIntoConstraints = false
        return v
    }()

    private let controlsView: UIView = {
        let v = UIView()
        v.backgroundColor = UIColor.black.withAlphaComponent(0.7)
        v.translatesAutoresizingMaskIntoConstraints = false
        return v
    }()

    private let closeButton: UIButton = {
        let b = UIButton(type: .system)
        b.setImage(UIImage(systemName: "chevron.left"), for: .normal)
        b.tintColor = .white
        b.translatesAutoresizingMaskIntoConstraints = false
        return b
    }()

    private let playPauseButton: UIButton = {
        let b = UIButton(type: .system)
        b.setImage(UIImage(systemName: "pause.fill"), for: .normal)
        b.tintColor = .white
        b.translatesAutoresizingMaskIntoConstraints = false
        return b
    }()

    private let currentTimeLabel: UILabel = {
        let l = UILabel()
        l.text = "0:00"
        l.textColor = .white
        l.font = .monospacedDigitSystemFont(ofSize: 12, weight: .regular)
        l.setContentHuggingPriority(.required, for: .horizontal)
        l.translatesAutoresizingMaskIntoConstraints = false
        return l
    }()

    private let totalTimeLabel: UILabel = {
        let l = UILabel()
        l.text = "0:00"
        l.textColor = .lightGray
        l.font = .monospacedDigitSystemFont(ofSize: 12, weight: .regular)
        l.setContentHuggingPriority(.required, for: .horizontal)
        l.translatesAutoresizingMaskIntoConstraints = false
        return l
    }()

    private let progressSlider: UISlider = {
        let s = UISlider()
        s.minimumTrackTintColor = UIColor(red: 225/255.0, green: 200/255.0, blue: 170/255.0, alpha: 1.0)
        s.maximumTrackTintColor = UIColor(white: 0.4, alpha: 1)
        s.thumbTintColor = .white
        s.translatesAutoresizingMaskIntoConstraints = false
        return s
    }()

    init(url: URL, title: String, duration: TimeInterval) {
        self.videoURL = url
        self.videoTitle = title
        self.knownDuration = duration
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) { fatalError() }

    override func viewDidLoad() {
        super.viewDidLoad()
//        self.navigationController?.setNavigationBarHidden(false, animated: false)
//        navigationController?.setNavigationBarHidden(true, animated: false)
        view.backgroundColor = .black
        setupLayout()
        setupActions()
        totalTimeLabel.text = formatTime(knownDuration)
    }
    
    
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        startPlayback()
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
//        navigationController?.setNavigationBarHidden(false, animated: false)
        timeObserverTimer?.invalidate()
        timeObserverTimer = nil
        player?.pause()
        player?.view?.removeFromSuperview()
        player = nil
    }
    
    private func setupLayout() {
        view.addSubview(videoContainerView)
//        view.addSubview(closeButton)
        view.addSubview(controlsView)
        controlsView.addSubview(playPauseButton)
        controlsView.addSubview(currentTimeLabel)
        controlsView.addSubview(progressSlider)
        controlsView.addSubview(totalTimeLabel)

        NSLayoutConstraint.activate([
//            closeButton.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 8),
//            closeButton.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
//            closeButton.widthAnchor.constraint(equalToConstant: 44),
//            closeButton.heightAnchor.constraint(equalToConstant: 44),

            videoContainerView.topAnchor.constraint(equalTo: view.topAnchor),
            videoContainerView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            videoContainerView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            videoContainerView.bottomAnchor.constraint(equalTo: controlsView.topAnchor),

            controlsView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            controlsView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            controlsView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor),
            controlsView.heightAnchor.constraint(equalToConstant: 80),

            playPauseButton.leadingAnchor.constraint(equalTo: controlsView.leadingAnchor, constant: 16),
            playPauseButton.centerYAnchor.constraint(equalTo: controlsView.centerYAnchor),
            playPauseButton.widthAnchor.constraint(equalToConstant: 36),
            playPauseButton.heightAnchor.constraint(equalToConstant: 36),

            currentTimeLabel.leadingAnchor.constraint(equalTo: playPauseButton.trailingAnchor, constant: 10),
            currentTimeLabel.centerYAnchor.constraint(equalTo: controlsView.centerYAnchor),

            totalTimeLabel.trailingAnchor.constraint(equalTo: controlsView.trailingAnchor, constant: -16),
            totalTimeLabel.centerYAnchor.constraint(equalTo: controlsView.centerYAnchor),

            progressSlider.leadingAnchor.constraint(equalTo: currentTimeLabel.trailingAnchor, constant: 8),
            progressSlider.trailingAnchor.constraint(equalTo: totalTimeLabel.leadingAnchor, constant: -8),
            progressSlider.centerYAnchor.constraint(equalTo: controlsView.centerYAnchor),
        ])
    }

    private func setupActions() {
//        closeButton.addTarget(self, action: #selector(onClose), for: .touchUpInside)
        playPauseButton.addTarget(self, action: #selector(onPlayPause), for: .touchUpInside)
        progressSlider.addTarget(self, action: #selector(onSliderTouchDown), for: .touchDown)
        progressSlider.addTarget(self, action: #selector(onSliderChanged), for: .valueChanged)
        progressSlider.addTarget(self, action: #selector(onSliderTouchUp), for: [.touchUpInside, .touchUpOutside])
    }

    @objc private func onClose() {
        navigationController?.popViewController(animated: true)
    }

    @objc private func onPlayPause() {
        guard let player = player else { return }
        if player.isPlaying {
            player.pause()
            playPauseButton.setImage(UIImage(systemName: "play.fill"), for: .normal)
        } else {
            player.play()
            playPauseButton.setImage(UIImage(systemName: "pause.fill"), for: .normal)
        }
    }

    @objc private func onSliderTouchDown() {
        isSeeking = true
        player?.pause()
    }

    @objc private func onSliderChanged() {
        currentTimeLabel.text = formatTime(TimeInterval(progressSlider.value) * knownDuration)
    }

    @objc private func onSliderTouchUp() {
        let time = TimeInterval(progressSlider.value) * knownDuration
        player?.seek(time: time, completion: { [weak self] _ in
            self?.player?.play()
            self?.isSeeking = false
            self?.playPauseButton.setImage(UIImage(systemName: "pause.fill"), for: .normal)
        })
    }

    private func startPlayback() {
        let options = KSOptions()
        options.isAccurateSeek = false
        let p = KSMEPlayer(url: videoURL, options: options)
        p.delegate = self
        player = p
        if let pView = p.view {
            pView.translatesAutoresizingMaskIntoConstraints = false
            videoContainerView.addSubview(pView)
//            view.bringSubviewToFront(closeButton)
            NSLayoutConstraint.activate([
                pView.topAnchor.constraint(equalTo: videoContainerView.topAnchor),
                pView.leadingAnchor.constraint(equalTo: videoContainerView.leadingAnchor),
                pView.trailingAnchor.constraint(equalTo: videoContainerView.trailingAnchor),
                pView.bottomAnchor.constraint(equalTo: videoContainerView.bottomAnchor),
            ])
        }
        p.prepareToPlay()
        p.play()
        timeObserverTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            self?.updateProgress()
        }
    }

    private func updateProgress() {
        guard let player = player, !isSeeking, knownDuration > 0 else { return }
        let current = player.currentPlaybackTime
        progressSlider.value = Float(current / knownDuration)
        currentTimeLabel.text = formatTime(current)
    }

    private func formatTime(_ time: TimeInterval) -> String {
        let t = Int(max(0, time))
        if t >= 3600 { return String(format: "%d:%02d:%02d", t / 3600, (t % 3600) / 60, t % 60) }
        return String(format: "%d:%02d", t / 60, t % 60)
    }

    override var supportedInterfaceOrientations: UIInterfaceOrientationMask { .all }
}

extension RecordingPlayerViewController: MediaPlayerDelegate {
    func readyToPlay(player: some MediaPlayerProtocol) {}
    func changeLoadState(player: some MediaPlayerProtocol) {}
    func changeBuffering(player: some MediaPlayerProtocol, progress: Int) {}
    func playBack(player: some MediaPlayerProtocol, loopCount: Int) {}
    func finish(player: some MediaPlayerProtocol, error: Error?) {
        DispatchQueue.main.async { [weak self] in
            self?.playPauseButton.setImage(UIImage(systemName: "play.fill"), for: .normal)
            if let error = error {
                let alert = UIAlertController(title: "播放錯誤", message: error.localizedDescription, preferredStyle: .alert)
                alert.addAction(UIAlertAction(title: "確定", style: .default))
                self?.present(alert, animated: true)
            }
        }
    }
}
